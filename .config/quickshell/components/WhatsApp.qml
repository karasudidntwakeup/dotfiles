import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Android-style WhatsApp client: phone sheet, list -> conversation.
// Android roles sourced from theme tokens (Matugen), fixed hex only as fallback.
// Name/avatar tiles stay square.
Item {
    id: wa

    property var rootRef: null
    property bool active: false
    property real animProgress: wa.active ? 1 : 0
    Behavior on animProgress { Anim { type: Anim.Bouncy; easing.overshoot: 3.2 } }

    signal requestClose()

    // ---- Android roles from theme tokens ----
    readonly property color bg: rootRef ? Qt.color(rootRef.colorOf("surface")) : "#0b141a"
    readonly property color header: rootRef ? Qt.color(rootRef.colorOf("surface_container")) : "#1f2c34"
    readonly property color bubbleIn: rootRef ? Qt.color(rootRef.colorOf("surface_container_high")) : "#1f2c34"
    readonly property color bubbleOut: rootRef ? Qt.color(rootRef.colorOf("primary_container")) : "#005c4b"
    readonly property color green: rootRef ? Qt.color(rootRef.colorOf("primary")) : "#00a884"
    readonly property color fg: rootRef ? Qt.color(rootRef.colorOf("on_surface")) : "#e9edef"
    readonly property color muted: rootRef ? Qt.color(rootRef.colorOf("on_surface_variant")) : "#8696a0"
    readonly property color divider: rootRef ? rootRef.withAlpha(Qt.color(rootRef.colorOf("outline_variant")), 0.5) : "#222d34"
    readonly property color field: rootRef ? Qt.color(rootRef.colorOf("surface_container_high")) : "#2a3942"
    readonly property color err: rootRef ? Qt.color(rootRef.colorOf("error")) : "#f15c6d"
    // Outgoing-ink follows the outgoing token for contrast on any theme.
    readonly property color outFg: rootRef ? rootRef.contrastColor(wa.bubbleOut) : "#06281f"
    readonly property color outTime: rootRef ? rootRef.withAlpha(wa.outFg, 0.7) : "#a8d5cc"

    readonly property string uiFont: rootRef && rootRef.uiFont ? rootRef.uiFont : "Geist"
    readonly property string arabicFont: "SF Arabic"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property bool noShadow: Quickshell.env("QS_NO_SHADOW") === "1"



    property var rawChats: []
    property var currentChat: null
    property string currentJid: ""
    property string activeTab: "chats"
    property bool chatsLoading: false
    property bool chatsFailed: false
    property bool msgsLoading: false
    property bool msgsFailed: false
    property string sendStatus: ""
    property bool sendFailed: false
    property string playingAudioSrc: ""
    readonly property bool sending: sendProc.running || sendFileProc.running
    readonly property bool inChat: wa.currentJid.length > 0
    property var drafts: ({})
    property string _sendFileErr: ""
    property string _msgSig: ""
    property bool atEnd: true
    // Set for explicit jumps (open chat / send); background polls never move the view.
    // Only your own scrolling disarms it — fresh loads landing late still jump.
    property bool jumpEnd: false
    property bool _progScroll: false

    opacity: wa.animProgress
    visible: opacity > 0.01
    transform: Translate { y: (1 - wa.animProgress) * 8 }

    onActiveChanged: {
        if (wa.active) {
            wa.sendFailed = false
            wa.sendStatus = ""
            wa.loadChats()
            if (wa.inChat) { wa.jumpEnd = true; wa.loadMessages() }
            focusTimer.restart()
        } else {
            wa.saveDraft()
            audioPlayer.running = false
        }
    }

    Shortcut { sequence: "Ctrl+F"; enabled: wa.active && !wa.inChat; onActivated: searchField.forceActiveFocus() }
    Shortcut {
        sequence: "Escape"; enabled: wa.active
        onActivated: {
            if (wa.inChat) wa.backToList()
            else wa.requestClose()
        }
    }

    ListModel { id: chatModel }
    ListModel { id: messageModel }

    // ---------- helpers ----------
    function shortName(chat) {
        var n = String((chat && chat.name) || "").trim()
        if (n.length > 0) return n
        var jid = String((chat && chat.jid) || "")
        var m = jid.match(/^(\d+)/)
        return m ? m[1] : jid
    }
    function initials(name) {
        var n = String(name || "").trim()
        if (!n.length) return "?"
        var p = n.split(/\s+/)
        if (p.length >= 2) return (p[0].charAt(0) + p[p.length - 1].charAt(0)).toUpperCase()
        return n.charAt(0).toUpperCase()
    }
    function avatarColor(jid) {
        var h = 0
        var s = String(jid || "")
        for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) & 0xffffff
        // Hue family follows the theme's primary token; fallback is WA green.
        var base = rootRef ? Qt.color(rootRef.colorOf("primary")).hslHue : 0.44
        return Qt.hsla((base + (h % 8) * 0.04) % 1.0, 0.45, 0.32, 1)
    }
    function escapeHtml(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }
    // Wrap http(s) URLs in anchors (trailing punctuation left outside).
    // Link ink is passed in so it contrasts on both bubble sides.
    function linkify(s, linkColor) {
        var ink = linkColor || wa.green
        return wa.escapeHtml(s).replace(/(https?:\/\/[^\s<>"']+)/g, function(url) {
            var trail = ""
            var m = url.match(/[.,!?;:)\]]+$/)
            if (m) { trail = m[0]; url = url.slice(0, -trail.length) }
            if (!url.length) return m ? m[0] : ""
            return '<a href="' + url + '"><font color="' + ink + '">' + url + '</font></a>' + trail
        })
    }
    function linkAtText(item, area, x, y) {
        var p = item.mapFromItem(area, x, y)
        return item.linkAt(p.x, p.y)
    }
    function copyLink(link) {
        if (!link) return
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "wa-copy", link])
    }
    function openLink(link) {
        if (!link) return
        Quickshell.execDetached(["xdg-open", link])
    }
    function safeJid(jid) { return String(jid).replace(/[^A-Za-z0-9]/g, "_") }
    function mediaPath(src) {
        var path = String(src || "")
        var prefix = wa.homeDir + "/.cache/quickshell/wa-media/"
        if (path.indexOf(prefix) !== 0 || path.indexOf("..") >= 0) return ""
        return path
    }
    function mediaUrl(src) {
        var p = wa.mediaPath(src)
        return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : ""
    }
    function parseDate(iso) { var t = Date.parse(iso); return isNaN(t) ? null : new Date(t) }
    function fmtTime(iso) {
        var t = wa.parseDate(iso)
        if (!t) return ""
        var h = t.getHours(), m = t.getMinutes()
        var hh = (h % 12 === 0 ? 12 : h % 12)
        return hh + ":" + (m < 10 ? "0" : "") + m + (h < 12 ? " AM" : " PM")
    }
    function dayKey(iso) {
        var t = wa.parseDate(iso)
        return t ? (t.getFullYear() * 10000 + (t.getMonth() + 1) * 100 + t.getDate()) : -1
    }
    function dayLabel(iso) {
        var t = wa.parseDate(iso)
        if (!t) return ""
        var now = new Date()
        var dk = d => d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate()
        if (dk(t) === dk(now)) return "Today"
        var y = new Date(now); y.setDate(now.getDate() - 1)
        if (dk(t) === dk(y)) return "Yesterday"
        return (t.getMonth() + 1) + "/" + t.getDate() + "/" + t.getFullYear()
    }
    function fmtListTime(iso) {
        var t = wa.parseDate(iso)
        if (!t) return ""
        var now = new Date()
        var dk = d => d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate()
        return dk(t) === dk(now) ? wa.fmtTime(iso) : (t.getMonth() + 1) + "/" + t.getDate() + "/" + String(t.getFullYear()).slice(2)
    }

    // ---------- data ----------
    function loadChats() {
        if (chatsFetchProc.running || !wa.active) return
        wa.chatsLoading = true
        chatsFetchProc.running = true
    }
    function loadMessages() {
        if (!wa.inChat || messagesProc.running) return
        wa.msgsLoading = true
        messagesProc.jid = wa.currentJid
        messagesProc.command = ["timeout", "--kill-after=5s", "60s", "bash",
            Quickshell.shellDir + "/scripts/wa-messages.sh", wa.currentJid]
        messagesProc.running = true
    }
    function onChatsData(obj) {
        wa.chatsLoading = false
        if (!obj || !Array.isArray(obj.chats)) { wa.chatsFailed = true; return }
        wa.chatsFailed = false
        // Skip rebuild when identical (poll churn -> scroll jumps otherwise).
        var sig = obj.chats.length + "|" + obj.chats.slice(0, 12).map(c => (c.jid || "") + ":" + (c.unread_count || 0)).join(",")
        if (sig === wa._chatsSig) return
        wa._chatsSig = sig
        wa.rawChats = obj.chats
        wa.applyChatFilter(searchField.text)
    }
    property string _chatsSig: ""

    function tabKind() { return wa.activeTab === "groups" ? "group" : wa.activeTab === "channels" ? "newsletter" : "dm" }

    function applyChatFilter(text) {
        var q = (text || "").toLowerCase()
        var want = wa.tabKind()
        var sel = chatList.currentIndex >= 0 && chatList.currentIndex < chatModel.count
            ? String(chatModel.get(chatList.currentIndex).jid) : wa.currentJid
        chatModel.clear()
        for (var i = 0; i < wa.rawChats.length; i++) {
            var c = wa.rawChats[i]
            if (!c || !c.jid) continue
            var kind = c.kind === "community" ? "group" : (c.kind || "dm")
            if (kind !== want) continue
            var nm = wa.shortName(c)
            if (q.length > 0 && nm.toLowerCase().indexOf(q) < 0) continue
            chatModel.append({
                jid: String(c.jid), name: nm, kind: kind,
                unread: c.unread === true, unreadCount: c.unread_count || 0,
                lastTs: c.last_message_ts || "",
                muted: (c.muted_until !== undefined && c.muted_until !== 0)
            })
        }
        var idx = -1
        for (var j = 0; j < chatModel.count; j++)
            if (String(chatModel.get(j).jid) === sel) { idx = j; break }
        chatList.currentIndex = idx
    }

    function selectChat(chat) {
        if (!chat || !chat.jid || String(chat.jid) === wa.currentJid) return
        wa.saveDraft()
        audioPlayer.running = false
        wa.currentChat = { jid: String(chat.jid), name: String(chat.name), kind: String(chat.kind) }
        wa.currentJid = String(chat.jid)
        sendField.text = wa.drafts[wa.currentJid] || ""
        wa.msgsFailed = false
        wa.atEnd = true
        wa.jumpEnd = true
        wa._msgSig = ""
        wa._progScroll = true
        messageModel.clear()
        wa._progScroll = false
        messagesFile.path = wa.homeDir + "/.cache/quickshell/wa-messages-" + wa.safeJid(wa.currentJid) + ".json"
        wa.loadMessages()
        messagesFile.reload()
        chatInputTimer.restart()
    }
    function backToList() {
        wa.saveDraft()
        audioPlayer.running = false
        wa.currentChat = null
        wa.currentJid = ""
        wa._msgSig = ""
        messageModel.clear()
        messagesFile.path = ""
    }
    function saveDraft() {
        if (wa.currentJid) wa.drafts[wa.currentJid] = sendField.text
    }

    function onMessagesData(obj) {
        if (!wa.inChat || !obj || String(obj.jid || "") !== wa.currentJid) return
        if (!Array.isArray(obj.messages)) { if (!wa.msgsLoading) wa.msgsFailed = true; return }
        wa.msgsFailed = false
        // Skip rebuild when nothing changed (ids, media, text lengths):
        // idle polls then can't disturb the view at all.
        var sig = obj.messages.length + "|" + obj.messages.map(m =>
            (m.MsgID || "") + ":" + (m.src || "") + ":"
            + String(m.DisplayText || m.Text || m.MediaCaption || "").length).join(",")
        if (sig === wa._msgSig) return
        wa._msgSig = sig
        var savedY = msgList.contentY - msgList.originY
        var wantEnd = wa.jumpEnd
        var jid = wa.currentJid
        wa._progScroll = true
        messageModel.clear()
        var lastDay = -1
        // wacli returns newest-first; iterate oldest-first for top-down view.
        for (var i = obj.messages.length - 1; i >= 0; i--) {
            var m = obj.messages[i]
            if (!m || !m.MsgID) continue
            var dk = wa.dayKey(m.Timestamp)
            if (dk !== lastDay && dk >= 0) {
                lastDay = dk
                messageModel.append({ isDay: true, label: wa.dayLabel(m.Timestamp),
                    fromMe: false, sender: "", text: "", mediaType: "", src: "", time: "" })
            }
            var body = String(m.MediaCaption || m.DisplayText || m.Text || "")
            // Skip empty system rows (join/leave noise shows as "(message)").
            if (!body && !m.MediaType) continue
            messageModel.append({
                isDay: false, label: "",
                fromMe: m.FromMe === true,
                sender: String(m.SenderName || (m.FromMe ? "You" : "")),
                text: body, mediaType: String(m.MediaType || ""),
                src: wa.mediaPath(m.src), time: wa.fmtTime(m.Timestamp)
            })
        }
        Qt.callLater(() => {
            if (wa.currentJid !== jid) { wa._progScroll = false; return }
            msgList.forceLayout()
            if (wantEnd) {
                wa.jumpEnd = false
                msgList.positionViewAtEnd()
            } else {
                // Poll refresh: restore exact position, never move the view.
                msgList.contentY = msgList.originY
                    + Math.max(0, Math.min(savedY, msgList.contentHeight - msgList.height))
            }
            wa._progScroll = false
        })
    }

    function sendMessage() {
        var text = sendField.text.trim()
        if (!text.length || wa.sending || !wa.inChat) return
        var jid = wa.currentJid
        sendProc.targetJid = jid
        sendProc.pendingText = sendField.text
        wa.drafts[jid] = ""
        wa.sendStatus = ""
        wa.sendFailed = false
        sendField.text = ""
        wa.atEnd = true
        wa.jumpEnd = true
        sendProc.command = ["timeout", "--kill-after=5s", "60s", "bash",
            Quickshell.shellDir + "/scripts/wa-send.sh", jid, text]
        sendProc.running = true
    }
    function sendPaste() {
        if (!wa.currentJid || wa.sending) return
        wa.sendStatus = "Sending photo…"; wa.sendFailed = false
        sendFileProc.command = ["timeout", "--kill-after=5s", "120s", "bash",
            Quickshell.shellDir + "/scripts/wa-send-clip.sh", wa.currentJid]
        sendFileProc.running = true
    }
    function openMedia(src) {
        if (!src) { wa.loadMessages(); return }
        // swayimg if present, else xdg-open. Never hard-fail.
        Quickshell.execDetached(["sh", "-c",
            'if command -v swayimg >/dev/null 2>&1; then swayimg "$1"; else xdg-open "$1"; fi',
            "wa-open", src])
    }
    function toggleAudio(src) {
        if (!src.length) return
        if (wa.playingAudioSrc === src) { audioPlayer.running = false; wa.playingAudioSrc = ""; return }
        audioPlayer.running = false
        audioPlayer.command = ["mpv", "--no-video", "--no-terminal", "--really-quiet", "--", src]
        wa.playingAudioSrc = src
        audioPlayer.running = true
    }

    // ---------- backend ----------
    FileView {
        id: chatsFile
        path: wa.homeDir + "/.cache/quickshell/wa-chats.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: chatsFile.reload()
        onLoaded: {
            try { wa.onChatsData(JSON.parse(String(chatsFile.text()))) }
            catch (e) { wa.chatsLoading = false; wa.chatsFailed = true }
        }
        onLoadFailed: { wa.chatsLoading = false; wa.chatsFailed = true }
    }
    FileView {
        id: messagesFile
        path: ""
        watchChanges: true
        blockLoading: true
        onFileChanged: messagesFile.reload()
        onLoaded: {
            if (!wa.inChat) return
            try { wa.onMessagesData(JSON.parse(String(messagesFile.text()))) }
            catch (e) { if (!wa.msgsLoading) wa.msgsFailed = true }
        }
        onLoadFailed: { if (wa.inChat && !wa.msgsLoading) wa.msgsFailed = true }
    }
    Process {
        id: chatsFetchProc
        command: ["timeout", "--kill-after=5s", "30s", "bash", Quickshell.shellDir + "/scripts/wa-contacts.sh"]
        onExited: code => {
            wa.chatsLoading = false
            if (code === 0) { wa.chatsFailed = false; chatsFile.reload() }
            else if (chatModel.count === 0) wa.chatsFailed = true
        }
    }
    Process {
        id: messagesProc
        property string jid: ""
        onExited: code => {
            // Switched chats mid-load: the new chat never started (guard
            // saw a running proc) — start it now instead of stalling.
            if (wa.currentJid !== messagesProc.jid) { wa.loadMessages(); return }
            wa.msgsLoading = false
            if (code === 0) { wa.msgsFailed = false; messagesFile.reload() }
            else wa.msgsFailed = true
        }
    }
    Process {
        id: sendProc
        property string targetJid: ""
        property string pendingText: ""
        onExited: code => {
            if (code === 0) {
                wa.sendFailed = false; wa.sendStatus = ""
                wa.loadChats()
                wa.kickRefresh()
            } else {
                wa.sendFailed = true
                wa.sendStatus = "Not sent — tap send to retry"
                if (wa.currentJid === targetJid && !sendField.text.length)
                    sendField.text = pendingText
                wa.drafts[targetJid] = pendingText
            }
            pendingText = ""
        }
    }
    Process {
        id: sendFileProc
        stdout: SplitParser {
            onRead: data => { if (data) wa._sendFileErr = data.trim().slice(0, 160) }
        }
        onExited: code => {
            if (code === 2) { wa.sendStatus = ""; wa.sendFailed = false } // user cancelled picker
            else if (code === 0) {
                wa.sendStatus = ""; wa.sendFailed = false
                wa.loadChats(); wa.kickRefresh()
            } else {
                wa.sendFailed = true
                wa.sendStatus = wa._sendFileErr || "File send failed"
            }
        }
    }
    Process { id: audioPlayer; onExited: wa.playingAudioSrc = "" }

    // Fast polls right after a send so the new message/photo shows up
    // quickly (sync + media fetch lag behind the upload). Self-stopping.
    Timer {
        id: sendRefresh
        interval: 2500
        repeat: true
        property int left: 0
        onTriggered: {
            if (wa.inChat) wa.loadMessages()
            left--
            if (left <= 0) sendRefresh.stop()
        }
    }
    function kickRefresh() { sendRefresh.left = 4; sendRefresh.restart() }
    Timer {
        id: chatPoll; interval: 10000; running: wa.active; repeat: true
        onTriggered: { wa.loadChats(); if (wa.inChat) wa.loadMessages() }
    }
    Timer { id: focusTimer; interval: 50; repeat: false; onTriggered: searchField.forceActiveFocus() }
    Timer { id: chatInputTimer; interval: 80; repeat: false; onTriggered: sendField.forceActiveFocus() }

    // ---------- sheet ----------
    MouseArea { anchors.fill: parent; onClicked: wa.requestClose() }

    Rectangle {
        id: card
        // Wide foldable (Pura X 16:10-ish): broad phone, docked at bottom.
        width: Math.min(620, parent.width - 32)
        height: Math.min(740, Math.max(520, parent.height - 96))
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.floor(parent.height - card.height - 24)
        radius: 0
        color: wa.bg
        border.width: 1
        border.color: wa.divider
        clip: true
        layer.enabled: !wa.noShadow
        layer.effect: MultiEffect {
            shadowEnabled: !wa.noShadow
            shadowBlur: 0.9
            blurMax: 28
            shadowHorizontalOffset: 5
            shadowVerticalOffset: 10
            shadowColor: Qt.rgba(0, 0, 0, 0.9)
            shadowOpacity: 0.95
        }
        // stacked pages: 0 = list, 1 = conversation (instant switch, no slop)
        readonly property int page: wa.inChat ? 1 : 0

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.4)
            z: 10
        }

        // ===== page 0: chat list =====
        Item {
            id: listPage
            anchors.fill: parent
            visible: card.page === 0
            enabled: card.page === 0

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle { // header with inline search
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: wa.header
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 8
                        spacing: 8
                        Image {
                            Layout.preferredWidth: 22; Layout.preferredHeight: 22
                            Layout.alignment: Qt.AlignVCenter
                            source: Qt.resolvedUrl("../assets/whatsapp.png")
                            sourceSize.width: 44; sourceSize.height: 44
                            asynchronous: true; smooth: true; mipmap: true
                        }
                        Text {
                            text: "WhatsApp"; color: wa.fg
                            font.family: wa.uiFont; font.pixelSize: wa.fontSize + 3; font.weight: Font.Bold
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle { // inline search
                            Layout.preferredWidth: 220
                            Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter
                            radius: 0; color: wa.field
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 6
                                spacing: 8
                                QIcon { source: Qt.resolvedUrl("../assets/icons/search.svg"); color: wa.muted; iconSize: 15 }
                                CharField {
                                    id: searchField
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    textColor: wa.fg; font.family: wa.uiFont; font.pixelSize: wa.fontSize
                                    placeholderText: "Search"; placeholderTextColor: wa.muted
                                    selectByMouse: true; verticalAlignment: Text.AlignVCenter
                                    onTextEdited: wa.applyChatFilter(searchField.text)
                                    Keys.onDownPressed: e => { if (chatModel.count > 0) chatList.incrementCurrentIndex(); e.accepted = true }
                                    Keys.onUpPressed: e => { chatList.decrementCurrentIndex(); e.accepted = true }
                                    Keys.onReturnPressed: e => {
                                        if (chatList.currentIndex >= 0 && chatList.currentIndex < chatModel.count)
                                            wa.selectChat(chatModel.get(chatList.currentIndex))
                                        e.accepted = true
                                    }
                                }
                                Item {
                                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                    visible: searchField.text.length > 0
                                    QIcon { anchors.centerIn: parent; source: Qt.resolvedUrl("../assets/icons/close.svg"); color: wa.muted; iconSize: 13 }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { searchField.text = ""; wa.applyChatFilter("") }
                                    }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        IconBtn { icon: "refresh"; tip: "Refresh"; onClicked: wa.loadChats() }

                    }
                }

                Row { // tabs (android underline style)
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    Repeater {
                        model: [{k: "chats", l: "Chats"}, {k: "groups", l: "Groups"}, {k: "channels", l: "Channels"}]
                        delegate: Item {
                            required property var modelData
                            width: card.width / 3; height: 40
                            Column {
                                anchors.fill: parent; spacing: 0
                                Item { width: parent.width; height: 36
                                    Text {
                                        anchors.centerIn: parent; text: modelData.l
                                        color: wa.activeTab === modelData.k ? wa.green : wa.muted
                                        font.family: wa.uiFont; font.pixelSize: wa.fontSize; font.weight: Font.Bold
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { wa.activeTab = modelData.k; wa.applyChatFilter(searchField.text) }
                                    }
                                }
                                Rectangle {
                                    width: parent.width; height: 3
                                    color: wa.activeTab === modelData.k ? wa.green : "transparent"
                                }
                            }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: wa.divider }

                ListView {
                    id: chatList
                    Layout.fillWidth: true; Layout.fillHeight: true
                    model: chatModel; clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Item {
                        required property int index
                        required property string jid
                        required property string name
                        required property bool unread
                        required property int unreadCount
                        required property string lastTs
                        required property bool muted
                        width: chatList.width; height: 68
                        Rectangle {
                            anchors.fill: parent
                            color: chatRowHover.containsMouse ? wa.field
                                : chatList.currentIndex === index ? wa.field : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12; anchors.rightMargin: 12
                                spacing: 12
                                Rectangle {
                                    Layout.preferredWidth: 46; Layout.preferredHeight: 46
                                    radius: 0; color: wa.avatarColor(jid)
                                    Text {
                                        anchors.centerIn: parent;                                         text: wa.initials(name)
                                        color: "#ffffff"; font.family: wa.uiFont
                                        font.pixelSize: wa.fontSize + 3; font.weight: Font.Bold
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 3
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        Text {
                                            Layout.fillWidth: true; text: name; textFormat: Text.PlainText
                                            elide: Text.ElideRight; maximumLineCount: 1
                                            color: wa.fg; font.family: wa.arabicFont; font.pixelSize: wa.fontSize
                                            font.weight: unread && unreadCount > 0 ? Font.Bold : Font.Medium
                                        }
                                        Text {
                                            text: wa.fmtListTime(lastTs); color: unread && unreadCount > 0 ? wa.green : wa.muted
                                            font.family: wa.uiFont; font.pixelSize: Math.max(10, wa.fontSize - 3)
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        Text {
                                            Layout.fillWidth: true
                                            text: unreadCount > 1 ? unreadCount + " new messages"
                                                : unreadCount === 1 ? "1 new message"
                                                : muted ? "Muted" : ""
                                            visible: text.length > 0
                                            elide: Text.ElideRight; maximumLineCount: 1
                                            color: wa.muted; font.family: wa.uiFont; font.pixelSize: Math.max(10, wa.fontSize - 2)
                                        }
                                        QIcon {
                                            visible: muted; source: Qt.resolvedUrl("../assets/icons/bell-off.svg")
                                            color: wa.muted; iconSize: 13
                                        }
                                        Rectangle { // unread badge
                                            visible: unreadCount > 0
                                            Layout.preferredWidth: Math.max(20, badgeText.implicitWidth + 12)
                                            Layout.preferredHeight: 20; radius: 0
                                            color: wa.green
                                            Text {
                                                id: badgeText; anchors.centerIn: parent
                                                text: unreadCount > 99 ? "99+" : String(unreadCount)
                                                color: wa.outFg; font.family: wa.uiFont
                                                font.pixelSize: Math.max(9, wa.fontSize - 3); font.weight: Font.Bold
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: chatRowHover
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { chatList.currentIndex = index; wa.selectChat(chatModel.get(index)) }
                        }
                    }
                }

                Item { // status footer
                    Layout.fillWidth: true; Layout.preferredHeight: 30
                    visible: wa.chatsLoading || wa.chatsFailed || chatModel.count === 0
                    Text {
                        anchors.centerIn: parent
                        text: wa.chatsLoading ? "Loading…" : wa.chatsFailed ? "Not authenticated — run: wacli auth" : "No chats"
                        color: wa.chatsFailed ? wa.err : wa.muted
                        font.family: wa.uiFont; font.pixelSize: Math.max(10, wa.fontSize - 2)
                    }
                }
            }
        }

        // ===== page 1: conversation =====
        Item {
            id: chatPage
            anchors.fill: parent
            visible: card.page === 1
            enabled: card.page === 1

            ColumnLayout {
                anchors.fill: parent; spacing: 0
                Rectangle { // convo header
                    Layout.fillWidth: true; Layout.preferredHeight: 60; color: wa.header
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4; anchors.rightMargin: 8; spacing: 4
                        IconBtn { icon: "back"; tip: "Back"; onClicked: wa.backToList() }
                        Rectangle {
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            radius: 0; color: wa.avatarColor(wa.currentJid)
                            Text {
                                anchors.centerIn: parent
                                text: wa.initials(wa.currentChat ? wa.currentChat.name : "")
                                color: "#fff"; font.family: wa.uiFont
                                font.pixelSize: wa.fontSize + 1; font.weight: Font.Bold
                            }
                        }
                        Text {
                            Layout.fillWidth: true; textFormat: Text.PlainText
                            text: wa.currentChat ? wa.shortName(wa.currentChat) : ""
                            elide: Text.ElideRight; maximumLineCount: 1
                            color: wa.fg; font.family: wa.arabicFont
                            font.pixelSize: wa.fontSize; font.weight: Font.Bold
                        }
                        Text {
                            visible: wa.msgsLoading || wa.sending
                            text: wa.sending ? "Sending…" : "Loading…"
                            color: wa.muted; font.family: wa.uiFont; font.pixelSize: Math.max(10, wa.fontSize - 2)
                        }

                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: wa.divider }

                Text { // send error strip
                    Layout.fillWidth: true; leftPadding: 12; rightPadding: 12; topPadding: 6; bottomPadding: 2
                    visible: wa.sendFailed; text: wa.sendStatus; textFormat: Text.PlainText
                    color: wa.err; font.family: wa.uiFont; font.pixelSize: Math.max(10, wa.fontSize - 2)
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: msgList
                    Layout.fillWidth: true; Layout.fillHeight: true
                    leftMargin: 10; rightMargin: 10; topMargin: 8; bottomMargin: 8
                    model: messageModel; clip: true; spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    onAtYEndChanged: wa.atEnd = atYEnd
                    onContentYChanged: {
                        wa.atEnd = atYEnd
                        // Your own scroll takes control; programmatic moves don't.
                        if (!wa._progScroll) wa.jumpEnd = false
                    }
                    delegate: Item {
                        required property int index
                        required property bool isDay
                        required property string label
                        required property bool fromMe
                        required property string sender
                        required property string text
                        required property string mediaType
                        required property string src
                        required property string time
                        readonly property bool isImage: mediaType === "image" && src !== ""
                        readonly property bool isSticker: mediaType === "sticker" && src !== ""
                        readonly property bool isAudio: mediaType === "audio" && src !== ""
                        readonly property string url: wa.mediaUrl(src)
                        readonly property string body: text
                        readonly property string stamp: time
                        readonly property string who: sender
                        width: msgList.width - 20
                        // Content-measured height: fixed estimates overflowed
                        // wrapped text/captions into neighboring rows.
                        height: isDay ? 30 : bubbleCol.implicitHeight + 8

                        Rectangle { // day divider chip
                            visible: isDay
                            anchors.centerIn: parent
                            width: dayText.implicitWidth + 24; height: 24; radius: 0
                            color: wa.header
                            Text {
                                id: dayText; anchors.centerIn: parent; text: label
                                color: wa.muted; font.family: wa.uiFont
                                font.pixelSize: Math.max(10, wa.fontSize - 2); font.weight: Font.Bold
                            }
                        }

                        Column {
                            id: bubbleCol
                            visible: !isDay
                            anchors.left: fromMe ? undefined : parent.left
                            anchors.right: fromMe ? parent.right : undefined
                            width: isSticker ? 160 : parent.width * 0.5
                            spacing: 2
                            Text { // group sender
                                visible: who.length > 0 && !fromMe && (wa.currentChat ? wa.currentChat.kind === "group" : false)
                                width: parent.width; textFormat: Text.PlainText; text: who
                                elide: Text.ElideRight; maximumLineCount: 1
                                color: wa.green; font.family: wa.uiFont
                                font.pixelSize: Math.max(10, wa.fontSize - 2); font.weight: Font.Bold
                            }
                            Rectangle { // image thumb
                                visible: isImage
                                width: parent.width; height: 184; radius: 0; clip: true; color: wa.header
                                Image {
                                    anchors.fill: parent; source: isImage ? url : ""
                                    fillMode: Image.PreserveAspectCrop
                                    // Cap decode size: a 12MP photo at 184px tall
                                    // needs no more than this in RAM.
                                    sourceSize.width: 480; sourceSize.height: 480
                                    asynchronous: true; smooth: true; mipmap: true
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wa.openMedia(src) }
                            }
                            Rectangle { // sticker
                                visible: isSticker
                                width: 160; height: 160; radius: 0; clip: true; color: "transparent"
                                AnimatedImage {
                                    id: stickerImg; anchors.fill: parent
                                    source: isSticker ? url : ""
                                    playing: wa.active && visible
                                    sourceSize.width: 320; sourceSize.height: 320
                                    fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                                }
                                Image {
                                    anchors.fill: parent; visible: stickerImg.status === Image.Error
                                    source: isSticker && visible ? url : ""
                                    sourceSize.width: 320; sourceSize.height: 320
                                    fillMode: Image.PreserveAspectFit; asynchronous: true
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wa.openMedia(src) }
                            }
                            Rectangle { // audio row
                                visible: isAudio
                                width: parent.width; height: 44; radius: 0
                                color: fromMe ? wa.bubbleOut : wa.bubbleIn
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 10; spacing: 8
                                    Rectangle {
                                        Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 0
                                        color: wa.green
                                        Text {
                                            anchors.centerIn: parent
                                            text: wa.playingAudioSrc === src ? "❚❚" : "▶"
                                            color: wa.outFg; font.pixelSize: 12; font.weight: Font.Bold
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true; text: "Voice message"
                                        elide: Text.ElideRight; maximumLineCount: 1; clip: true
                                        color: fromMe ? wa.outFg : wa.fg
                                        font.family: wa.uiFont; font.pixelSize: Math.max(10, wa.fontSize - 2)
                                    }
                                    Text {
                                        text: time
                                        color: fromMe ? wa.outTime : wa.muted
                                        font.family: wa.uiFont; font.pixelSize: 10
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wa.toggleAudio(src) }
                            }
                            Rectangle { // text bubble
                                id: bubble
                                visible: body.length > 0
                                width: parent.width
                                implicitHeight: bubbleRow.implicitHeight + 12
                                radius: 0
                                // iOS: uniformly rounded, no tail corner
                                topLeftRadius: 0
                                topRightRadius: 0
                                color: fromMe ? wa.bubbleOut : wa.bubbleIn
                                RowLayout {
                                    id: bubbleRow
                                    anchors.fill: parent
                                    anchors.leftMargin: 10; anchors.rightMargin: 8
                                    anchors.topMargin: 6; anchors.bottomMargin: 6
                                    spacing: 6
                                    Text {
                                        id: bubbleText
                                        Layout.fillWidth: true; textFormat: Text.RichText
                                        text: wa.linkify(body, fromMe ? wa.outFg : wa.green)
                                        color: fromMe ? wa.outFg : wa.fg
                                        font.family: wa.arabicFont; font.pixelSize: wa.fontSize
                                        wrapMode: Text.Wrap; lineHeight: 1.25
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignBottom; text: stamp
                                        color: fromMe ? wa.outTime : wa.muted
                                        font.family: wa.uiFont; font.pixelSize: 10
                                    }
                                }

                                // Single tap opens a link, double tap copies it.
                                // The delay keeps a double tap from opening first.
                                Timer {
                                    id: openTimer
                                    interval: 260
                                    repeat: false
                                    property string pendingLink: ""
                                    onTriggered: wa.openLink(pendingLink)
                                }
                                MouseArea {
                                    id: bubbleMouse
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    hoverEnabled: true
                                    cursorShape: Qt.ArrowCursor
                                    onClicked: e => {
                                        openTimer.pendingLink = wa.linkAtText(bubbleText, bubbleMouse, e.x, e.y)
                                        if (openTimer.pendingLink) openTimer.restart()
                                    }
                                    onDoubleClicked: e => {
                                        openTimer.stop()
                                        wa.copyLink(wa.linkAtText(bubbleText, bubbleMouse, e.x, e.y))
                                    }
                                    onPositionChanged: e => {
                                        bubbleMouse.cursorShape =
                                            wa.linkAtText(bubbleText, bubbleMouse, e.x, e.y)
                                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    visible: messageModel.count === 0
                    topPadding: 12; bottomPadding: 4
                    text: wa.msgsLoading ? "Loading messages…" : wa.msgsFailed ? "Couldn't load — pull to retry below" : "No messages yet"
                    color: wa.muted; font.family: wa.uiFont; font.pixelSize: Math.max(10, wa.fontSize - 2)
                }

                Rectangle { // input bar
                    Layout.fillWidth: true; Layout.preferredHeight: 62; color: "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 46; radius: 0; color: wa.field
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 6; spacing: 4
                                CharField {
                                    id: sendField
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    textColor: wa.fg; font.family: wa.arabicFont; font.pixelSize: wa.fontSize
                                    selectByMouse: true; verticalAlignment: Text.AlignVCenter
                                    placeholderText: "Message"; placeholderTextColor: wa.muted
                                    enabled: wa.inChat
                                    onAccepted: wa.sendMessage()
                                    Keys.onEscapePressed: e => { wa.backToList(); e.accepted = true }
                                }
                                IconBtn { icon: "photo"; tip: "Photo"; enabled: wa.inChat && !wa.sending; onClicked: wa.sendPaste() }
                            }
                        }
                        Rectangle { // round send FAB
                            Layout.preferredWidth: 46; Layout.preferredHeight: 46; radius: 0
                            color: sendField.text.length > 0 && wa.inChat ? wa.green : wa.field
                            opacity: (wa.inChat && !wa.sending && sendField.text.length > 0) ? 1 : 0.7
                            QIcon {
                                anchors.centerIn: parent
                                source: Qt.resolvedUrl("../assets/icons/send.svg")
                                color: sendField.text.length > 0 ? wa.outFg : wa.muted
                                iconSize: 18
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: wa.sendMessage()
                            }
                        }
                    }
                }
            }

            // Jump-to-latest: auto-hides while already at the end.
            Rectangle {
                id: jumpBtn
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 74
                width: 44; height: 44; radius: 0
                color: wa.field
                border.width: 1
                border.color: wa.divider
                opacity: (card.page === 1 && !wa.atEnd && messageModel.count > 0) ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                Text {
                    anchors.centerIn: parent
                    text: "↓"
                    color: wa.fg
                    font.family: wa.uiFont
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: jumpBtn.visible
                    onClicked: msgList.positionViewAtEnd()
                }
            }
        }

    }

    // ---------- small icon button ----------
    component IconBtn: Item {
        id: btn
        property string icon: ""
        property string tip: ""
        property bool enabled: true
        signal clicked()
        implicitWidth: 34; implicitHeight: 34
        opacity: btn.enabled ? 1 : 0.4
        QIcon {
            anchors.centerIn: parent
            source: btn.icon === "back" ? Qt.resolvedUrl("../assets/icons/chev-left.svg")
                : btn.icon === "refresh" ? Qt.resolvedUrl("../assets/icons/refresh.svg")
                : btn.icon === "clip" ? Qt.resolvedUrl("../assets/icons/clipboard.svg")
                : btn.icon === "photo" ? Qt.resolvedUrl("../assets/icons/photo.svg")
                : Qt.resolvedUrl("../assets/icons/close.svg")
            color: wa.fg; iconSize: 16
        }
        MouseArea {
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            enabled: btn.enabled
            onClicked: btn.clicked()
        }
    }
}
