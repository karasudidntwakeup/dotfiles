import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: wa

    property var rootRef: null
    property bool active: false
    readonly property int cardWidth: 700
    readonly property int leftWidth: Math.min(300, Math.max(0, (card.width - wa.pad * 2 - 10) * 0.34))
    readonly property int chatRowHeight: 40
    readonly property int maxChatRows: 7
    readonly property int headerHeight: 36
    readonly property int sendHeight: 36
    readonly property int searchHeight: 36
    readonly property int pad: 12
    readonly property int cornerRadius: 0
    readonly property int msgPad: 12
    readonly property real bubbleMaxW: 300
    readonly property int imgMaxW: 240
    readonly property int imgMaxH: 190
    property string activeTab: "chats"
    property string playingAudioSrc: ""
    readonly property string cardTile: "whatsapp_card"
    // Muted green: whatsapp token mixed toward neutral surface so the
    // background carries less color — text/borders follow via contrastColor.
    readonly property color cardColor: {
        var base = rootRef ? (rootRef.qsLight ? rootRef.pillColor(cardTile) : rootRef.colorOf(cardTile)) : "#f3dfd1"
        if (rootRef && rootRef.mixColor && rootRef.colorOf)
            base = rootRef.mixColor(base, rootRef.colorOf("surface_container_highest"), 0.2)
        return Qt.darker(base, 1.2)
    }
    readonly property color cardBorder: rootRef ? rootRef.withAlpha(rootRef.colorOf("widget_border"), rootRef.qsLight ? 0.7 : 0.5) : "#00000000"
    readonly property color fg: rootRef ? rootRef.contrastColor(wa.cardColor) : "#000000"
    readonly property color accent: rootRef ? Qt.color(rootRef.colorOf("widget_accent")) : "#73737a"
    readonly property color accentText: rootRef ? rootRef.contrastColor(wa.accent) : "#000000"
    readonly property color selectedFg: accentText
    readonly property color errorColor: rootRef ? Qt.color(rootRef.colorOf("widget_error")) : "#e30000"
    readonly property string fontFamily: uiFont
    readonly property string uiFont: "Geist"
    readonly property string arabicFont: "SF Arabic"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13
    readonly property string homeDir: Quickshell.env("HOME")
    property real animProgress: wa.active ? 1 : 0
    readonly property int bottomMargin: 24
    property var rawChats: []
    property var currentChat: null
    property string currentJid: ""
    property bool chatsLoading: false
    property bool chatsFailed: false
    property bool msgsLoading: false
    property bool msgsFailed: false
    readonly property bool sending: sendProc.running || sendFileProc.running
    property var drafts: ({
    })
    property var scrollPositions: ({
    })
    property string sendStatus: ""
    property bool sendFailed: false
    property bool restoreScroll: false
    property var pendingScroll: null
    readonly property int stableBodyHeight: wa.chatRowHeight * wa.maxChatRows + 6 * (wa.maxChatRows - 1) + 20

    signal requestClose()

    // Text/alpha helpers live on root (contrastColor/withAlpha).

    function copyChat(chat) {
        return chat ? {
            "jid": String(chat.jid),
            "name": String(chat.name),
            "kind": String(chat.kind)
        } : null;
    }

    function mediaPath(src) : string {
        var path = String(src || "");
        var prefix = wa.homeDir + "/.cache/quickshell/wa-media/";
        if (path.indexOf(prefix) !== 0 || /[\\\\\x00-\x1f\x7f]/.test(path))
            return "";

        var parts = path.slice(prefix.length).split("/");
        if (parts.length < 2 || parts.some(function(part) {
            return !part || part === "." || part === "..";
        }))
            return "";

        return path;
    }

    function mediaUrl(src) : string {
        var path = wa.mediaPath(src);
        return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
    }

    function saveChatState() {
        if (!wa.currentJid)
            return ;

        wa.drafts[wa.currentJid] = sendField.text;
        if (!wa.restoreScroll && !wa.pendingScroll) {
            wa.scrollPositions[wa.currentJid] = {
                "y": msgList.contentY - msgList.originY,
                "end": msgList.atYEnd
            };
        }
    }

    function clearChat() {
        wa.saveChatState();
        wa.currentChat = null;
        wa.currentJid = "";
        wa.pendingScroll = null;
        wa.msgsLoading = false;
        messageModel.clear();
        sendField.text = "";
        audioPlayer.running = false;
    }

    function safeJid(jid: string) : string {
        return String(jid).replace(/[^A-Za-z0-9]/g, "_");
    }

    function initials(name: string) : string {
        var n = String(name || "").trim();
        if (n.length === 0)
            return "?";

        var parts = n.split(/\s+/);
        if (parts.length >= 2)
            return parts[0].charAt(0) + parts[parts.length - 1].charAt(0);

        return n.charAt(0);
    }

    function shortName(chat) : string {
        var n = String(chat.name || "").trim();
        if (n.length > 0)
            return n;

        var jid = String(chat.jid || "");
        var m = jid.match(/^(\d+)/);
        return m ? m[1] : jid;
    }

    function fmtTime(iso: string) : string {
        var d = Date.parse(iso);
        if (isNaN(d))
            return "";

        var t = new Date(d);
        var h = t.getHours(), m = t.getMinutes();
        var hh = (h % 12 === 0 ? 12 : h % 12);
        return hh + ":" + (m < 10 ? "0" : "") + m + (h < 12 ? " AM" : " PM");
    }

    function fmtDate(iso: string) : string {
        var d = Date.parse(iso);
        if (isNaN(d))
            return "";

        var t = new Date(d);
        var now = new Date();
        var sameDay = t.toDateString() === now.toDateString();
        return sameDay ? wa.fmtTime(iso) : (t.getMonth() + 1) + "/" + (t.getDate() < 10 ? "0" : "") + t.getDate() + " " + wa.fmtTime(iso);
    }

    function loadChats() {
        if (chatsFetchProc.running)
            return ;

        wa.chatsLoading = true;
        chatsFetchProc.running = true;
    }

    function loadMessages() {
        if (!wa.currentJid || messagesProc.running)
            return ;

        wa.msgsLoading = true;
        messagesProc.jid = wa.currentJid;
        messagesProc.command = ["timeout", "--kill-after=5s", "420s", "bash", Quickshell.shellDir + "/scripts/wa-messages.sh", wa.currentJid];
        messagesProc.running = true;
    }

    function onChatsData(obj) {
        wa.chatsLoading = chatsFetchProc.running;
        wa.chatsFailed = false;
        if (!obj || !Array.isArray(obj.chats)) {
            wa.chatsFailed = true;
            return ;
        }
        wa.rawChats = obj.chats;
        wa.applyChatFilter(searchField.text);
    }

    function applyChatFilter(text) {
        var q = (text || "").toLowerCase();
        var tab = wa.activeTab;
        var previousIndex = chatList.currentIndex;
        var selectedJid = previousIndex >= 0 && previousIndex < chatModel.count ? String(chatModel.get(previousIndex).jid) : wa.currentJid;
        var oldY = chatList.contentY;
        wa.currentChat = wa.copyChat(wa.currentChat);
        chatModel.clear();
        for (var i = 0; i < wa.rawChats.length; i++) {
            var c = wa.rawChats[i];
            if (!c || !c.jid)
                continue;

            var kind = c.kind === "community" ? "group" : (c.kind || "dm");
            var expectedKind = tab === "groups" ? "group" : tab === "channels" ? "newsletter" : "dm";
            if (kind !== expectedKind)
                continue;

            var n = wa.shortName(c).toLowerCase();
            if (q.length > 0 && n.indexOf(q) < 0)
                continue;

            chatModel.append({
                "jid": c.jid,
                "name": wa.shortName(c),
                "kind": kind,
                "unread": c.unread === true,
                "unreadCount": c.unread_count || 0,
                "lastTs": c.last_message_ts || "",
                "muted": c.muted_until !== undefined ? c.muted_until : 0
            });
        }
        var selectedIndex = -1;
        for (var j = 0; j < chatModel.count; j++) {
            var item = chatModel.get(j);
            if (item.jid === selectedJid)
                selectedIndex = j;

            if (item.jid === wa.currentJid)
                wa.currentChat = wa.copyChat(item);

        }
        chatList.currentIndex = selectedIndex >= 0 ? selectedIndex : Math.min(Math.max(0, previousIndex), chatModel.count - 1);
        chatList.contentY = Math.max(chatList.originY, Math.min(oldY, chatList.originY + Math.max(0, chatList.contentHeight - chatList.height)));
    }

    function selectChat(chat) {
        if (!chat || !chat.jid)
            return ;

        if (chat.jid === wa.currentJid) {
            inputFocus.restart();
            return ;
        }
        wa.saveChatState();
        audioPlayer.running = false;
        wa.currentChat = wa.copyChat(chat);
        wa.currentJid = String(chat.jid);
        wa.pendingScroll = null;
        sendField.text = wa.drafts[wa.currentJid] || "";
        wa.msgsFailed = false;
        wa.restoreScroll = true;
        messageModel.clear();
        wa.msgsLoading = true;
        messagesFile.path = wa.homeDir + "/.cache/quickshell/wa-messages-" + wa.safeJid(wa.currentJid) + ".json";
        wa.loadMessages();
        messagesFile.reload();
        inputFocus.restart();
    }

    function onMessagesData(obj) {
        if (!wa.currentJid)
            return ;

        if (!obj || String(obj.jid || "") !== wa.currentJid)
            return ;

        if (!Array.isArray(obj.messages)) {
            if (!wa.msgsLoading) wa.msgsFailed = true;
            return ;
        }
        wa.msgsFailed = false;
        var jid = wa.currentJid;
        var oldScroll = wa.pendingScroll ? wa.pendingScroll.position
            : wa.restoreScroll ? (wa.scrollPositions[jid] || { y: 0, end: true })
            : { y: msgList.contentY - msgList.originY, end: msgList.atYEnd };
        var update = { jid: jid, position: oldScroll };
        wa.scrollPositions[jid] = oldScroll;
        wa.pendingScroll = update;
        wa.restoreScroll = false;
        messageModel.clear();
        for (var i = obj.messages.length - 1; i >= 0; i--) {
            var m = obj.messages[i];
            if (!m || !m.MsgID)
                continue;

            var body = String(m.MediaCaption || m.DisplayText || m.Text || "");
            messageModel.append({
                "fromMe": m.FromMe === true,
                "sender": String(m.SenderName || (m.FromMe ? "You" : "")),
                "text": body,
                "mediaType": String(m.MediaType || ""),
                "src": wa.mediaPath(m.src),
                "time": wa.fmtDate(m.Timestamp)
            });
        }
        Qt.callLater(function() {
            if (wa.currentJid !== jid || wa.pendingScroll !== update) return;
            msgList.forceLayout();
            if (oldScroll.end) {
                msgList.positionViewAtEnd();
            } else {
                msgList.contentY = msgList.originY + Math.max(0, Math.min(oldScroll.y, msgList.contentHeight - msgList.height));
            }
            wa.pendingScroll = null;
        });
    }

    function sendMessage() {
        var text = sendField.text.trim();
        if (text.length === 0 || wa.sending || !wa.currentJid)
            return ;

        var jid = wa.currentJid;
        sendProc.targetJid = jid;
        sendProc.targetName = wa.shortName(wa.currentChat || { jid: jid });
        sendProc.pendingText = sendField.text;
        wa.drafts[jid] = "";
        wa.sendStatus = "";
        wa.sendFailed = false;
        sendField.text = "";
        sendProc.command = ["timeout", "--kill-after=5s", "90s", "bash", Quickshell.shellDir + "/scripts/wa-send.sh", jid, text];
        sendProc.running = true;
    }

    function sendFile() {
        if (!wa.currentJid || wa.sending)
            return ;

        wa.sendStatus = "";
        wa.sendFailed = false;
        sendFileProc.command = ["bash", Quickshell.shellDir + "/scripts/wa-send-file.sh", wa.currentJid];
        sendFileProc.running = true;
    }

    function sendPaste() {
        if (!wa.currentJid)
            return ;

        sendFileProc.command = ["bash", Quickshell.shellDir + "/scripts/wa-send-clip.sh", wa.currentJid];
        sendFileProc.running = true;
    }

    function toggleAudio(src: string) {
        if (src.length === 0)
            return ;

        if (wa.playingAudioSrc === src) {
            audioPlayer.running = false;
            wa.playingAudioSrc = "";
            return ;
        }
        audioPlayer.command = ["mpv", "--no-video", "--no-terminal", "--really-quiet", "--", src];
        wa.playingAudioSrc = src;
        audioPlayer.running = true;
    }

    function bodyHeight() : int {
        return Math.max(0, Math.min(wa.stableBodyHeight, wa.height - 180));
    }

    opacity: wa.animProgress
    onActiveChanged: {
        if (wa.active) {
            wa.loadChats();
            if (wa.currentJid.length > 0)
                wa.loadMessages();

            wa.applyChatFilter(searchField.text);
            focusRequest.restart();
        } else {
            wa.saveChatState();
            audioPlayer.running = false;
        }
    }

    Shortcut {
        sequence: "Ctrl+F"
        enabled: wa.active
        onActivated: searchField.forceActiveFocus()
    }

    Shortcut {
        sequence: "Escape"
        enabled: wa.active
        onActivated: wa.requestClose()
    }

    ListModel {
        id: chatModel
    }

    ListModel {
        id: messageModel
    }

    FileView {
        id: chatsFile

        path: wa.homeDir + "/.cache/quickshell/wa-chats.json"
        watchChanges: true
        blockLoading: false
        onFileChanged: chatsFile.reload()
        onLoaded: {
            try {
                wa.onChatsData(JSON.parse(String(chatsFile.text())));
            } catch (err) {
                console.log("[wa] chats parse error:", err);
                wa.chatsLoading = false;
                wa.chatsFailed = true;
            }
        }
        onLoadFailed: (error) => {
            console.log("[wa] chats load failed:", error);
            wa.chatsLoading = false;
            wa.chatsFailed = true;
        }
    }

    FileView {
        id: messagesFile

        path: ""
        watchChanges: true
        blockLoading: true
        onFileChanged: messagesFile.reload()
        onLoaded: {
            if (!wa.currentJid)
                return ;

            try {
                wa.onMessagesData(JSON.parse(String(messagesFile.text())));
            } catch (err) {
                if (!wa.msgsLoading) wa.msgsFailed = true;
            }
        }
        onLoadFailed: (error) => {
            if (!wa.currentJid)
                return ;

            if (!wa.msgsLoading) wa.msgsFailed = true;
        }
    }

    Process {
        id: sendProc

        property string targetJid: ""
        property string targetName: ""
        property string pendingText: ""

        onExited: (code) => {
            if (code === 0) {
                wa.loadChats();
                refreshTimer.restart();
            } else {
                wa.sendFailed = true;
                wa.sendStatus = "Failed to send to " + targetName + " (" + targetJid + ")";
                var draft = wa.currentJid === targetJid ? sendField.text : (wa.drafts[targetJid] || "");
                if (draft.length === 0) {
                    wa.drafts[targetJid] = pendingText;
                    if (wa.currentJid === targetJid) sendField.text = pendingText;
                }
            }
            pendingText = "";
        }
    }

    Process {
        id: sendFileProc

        onExited: (code) => {
            if (code !== 2) {
                if (code === 0) {
                    wa.sendStatus = "";
                    wa.sendFailed = false;
                    wa.loadChats();
                    if (wa.currentJid)
                        wa.loadMessages();

                } else {
                    wa.sendFailed = true;
                    wa.sendStatus = "File send failed";
                }
            } else {
                wa.sendStatus = "";
                wa.sendFailed = false;
            }
            refreshTimer.restart();
        }
    }

    Process {
        id: chatsFetchProc

        command: ["timeout", "--kill-after=5s", "60s", "bash", Quickshell.shellDir + "/scripts/wa-contacts.sh"]
        onExited: (code) => {
            wa.chatsLoading = false;
            wa.chatsFailed = code !== 0;
            if (code === 0) chatsFile.reload();
        }
    }

    Process {
        id: messagesProc

        property string jid: ""

        onExited: code => {
            if (wa.currentJid !== messagesProc.jid) {
                wa.loadMessages();
                return;
            }
            wa.msgsLoading = false;
            wa.msgsFailed = code !== 0;
            if (code === 0) messagesFile.reload();
        }
    }

    Process {
        id: audioPlayer

        onExited: () => {
            wa.playingAudioSrc = "";
        }
    }

    Timer {
        id: refreshTimer

        interval: 1600
        repeat: false
        onTriggered: wa.loadMessages()
    }

    Timer {
        id: pollTimer

        interval: 6000
        repeat: true
        running: wa.active
        onTriggered: {
            wa.loadChats();
            if (wa.currentJid)
                wa.loadMessages();

        }
    }

    Timer {
        id: focusRequest

        interval: 40
        repeat: false
        onTriggered: searchField.forceActiveFocus()
    }

    Timer {
        id: inputFocus

        interval: 60
        repeat: false
        onTriggered: sendField.forceActiveFocus()
    }

    Rectangle {
        z: 0
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: wa.requestClose()
        }

    }

    Rectangle {
        id: card

        z: 1
        width: Math.max(0, Math.min(wa.cardWidth, parent.width - 28))
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.floor(parent.height - card.height - wa.bottomMargin)
        height: contentColumn.implicitHeight + wa.pad * 2
        radius: wa.cornerRadius
        color: wa.cardColor
        border.width: 1
        border.color: wa.cardBorder
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: Quickshell.env("QS_NO_SHADOW") !== "1"
            shadowBlur: 0.9
            blurMax: 28
            shadowHorizontalOffset: 5
            shadowVerticalOffset: 10
            shadowColor: Qt.rgba(0, 0, 0, 0.9)
            shadowOpacity: 0.95
        }

        Column {
            id: contentColumn

            x: wa.pad
            y: wa.pad
            width: card.width - wa.pad * 2
            spacing: 10

            RowLayout {
                width: parent.width
                spacing: 6

                Image {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    source: Qt.resolvedUrl("../assets/whatsapp.png")
                }

                Text {
                    textFormat: Text.PlainText
                    text: "WhatsApp"
                    color: wa.fg
                    font.family: wa.fontFamily
                    font.pixelSize: wa.fontSize + 1
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                Text {
                    visible: wa.currentJid.length > 0 && (wa.msgsLoading || wa.sending)
                    text: wa.msgsLoading ? "Loading\u2026" : "Sending\u2026"
                    color: rootRef.withAlpha(wa.fg, 0.7)
                    font.family: wa.uiFont
                    font.pixelSize: Math.max(10, wa.fontSize - 2)
                }

                Text {
                    visible: wa.sendFailed
                    text: wa.sendStatus
                    textFormat: Text.PlainText
                    color: wa.errorColor
                    font.family: wa.uiFont
                    font.pixelSize: Math.max(10, wa.fontSize - 2)
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.preferredWidth: refreshText.implicitWidth + 20
                    Layout.preferredHeight: 24
                    radius: 0
                    color: refreshHover.containsMouse ? rootRef.withAlpha(wa.fg, 0.2) : rootRef.withAlpha(wa.fg, 0.08)

                    Row {
                        id: refreshText
                    
                        anchors.centerIn: parent
                        spacing: 5
                    
                        QIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: Qt.resolvedUrl("../assets/icons/refresh.svg")
                            color: wa.fg
                            iconSize: Math.max(10, wa.fontSize)
                        }
                    
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Refresh"
                            color: wa.fg
                            font.family: wa.uiFont
                            font.pixelSize: wa.fontSize - 1
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: refreshHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wa.loadChats();
                            if (wa.currentJid)
                                wa.loadMessages();

                        }
                    }

                    Behavior on color {
                        CAnim { type: CAnim.FastEffects }

                    }

                }

            }

            Rectangle {
                id: searchBox

                width: parent.width
                height: wa.searchHeight
                radius: 0
                color: rootRef.withAlpha(wa.fg, 0.08)
                border.width: 1
                border.color: searchField.inputFocus ? rootRef.withAlpha(wa.fg, 0.78) : rootRef.withAlpha(wa.fg, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 6
                    spacing: 8

                    Image {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        source: "data:image/svg+xml;utf8," + encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + wa.fg.toString() + "' stroke-width='2' stroke-linecap='round'><circle cx='10.5' cy='10.5' r='6.5'/><path d='m16 16 5 5'/></svg>")
                        opacity: 0.55
                        smooth: true
                    }

                    CharField {
                        id: searchField

                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.min(360, searchBox.width - 96)
                        Layout.fillHeight: true
                        textColor: wa.fg
                        font.family: wa.uiFont
                        font.pixelSize: wa.fontSize + 1
                        font.weight: Font.Medium
                        placeholderText: "Search chats\u2026"
                        placeholderTextColor: rootRef.withAlpha(wa.fg, 0.78)
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter
                        onTextEdited: wa.applyChatFilter(searchField.text)
                        Keys.onDownPressed: (event) => {
                            if (chatModel.count > 0)
                                chatList.incrementCurrentIndex();

                            event.accepted = true;
                        }
                        Keys.onUpPressed: (event) => {
                            chatList.decrementCurrentIndex();
                            event.accepted = true;
                        }
                        Keys.onReturnPressed: (event) => {
                            if (chatModel.count > 0)
                                wa.selectChat(chatModel.get(chatList.currentIndex));

                            event.accepted = true;
                        }
                        Keys.onTabPressed: (event) => {
                            if (wa.currentJid)
                                sendField.forceActiveFocus();

                            event.accepted = true;
                        }
                        Keys.onEscapePressed: (event) => {
                            wa.requestClose();
                            event.accepted = true;
                        }

                    }

                    Rectangle {
                        visible: searchField.text.length > 0
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignVCenter
                        radius: 0
                        color: clearHover.containsMouse ? rootRef.withAlpha(wa.fg, 0.25) : "transparent"

                        QIcon {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../assets/icons/close.svg")
                            color: wa.fg
                            iconSize: wa.fontSize + 2
                        }

                        MouseArea {
                            id: clearHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = "";
                                wa.applyChatFilter("");
                                searchField.forceActiveFocus();
                            }
                        }

                    }

                }

                Behavior on border.color {
                    CAnim { type: CAnim.FastEffects }

                }

            }

            Rectangle {
                width: Math.min(330, parent.width)
                height: 30
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 0
                color: rootRef.withAlpha(wa.fg, 0.06)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    Item {
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 0
                            color: wa.activeTab === "chats" ? wa.accent : "transparent"

                            Behavior on color {
                                CAnim { type: CAnim.FastEffects }

                            }

                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "Chats"
                                color: wa.activeTab === "chats" ? wa.accentText : rootRef.withAlpha(wa.fg, 0.78)
                                font.family: wa.uiFont
                                font.pixelSize: wa.fontSize
                                font.weight: Font.Bold
                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wa.activeTab = "chats";
                                wa.applyChatFilter(searchField.text);
                            }
                        }

                    }

                    Item {
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 0
                            color: wa.activeTab === "groups" ? wa.accent : "transparent"

                            Behavior on color {
                                CAnim { type: CAnim.FastEffects }

                            }

                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "Groups"
                                color: wa.activeTab === "groups" ? wa.accentText : rootRef.withAlpha(wa.fg, 0.78)
                                font.family: wa.uiFont
                                font.pixelSize: wa.fontSize
                                font.weight: Font.Bold
                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wa.activeTab = "groups";
                                wa.applyChatFilter(searchField.text);
                            }
                        }

                    }

                    Repeater {
                        model: [{key: "channels", label: "Channels"}]

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            Layout.minimumWidth: 0
                            radius: 0
                            color: wa.activeTab === modelData.key ? wa.accent : "transparent"

                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                color: wa.activeTab === modelData.key ? wa.accentText : rootRef.withAlpha(wa.fg, 0.78)
                                font.family: wa.uiFont
                                font.pixelSize: wa.fontSize
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    wa.activeTab = modelData.key;
                                    wa.applyChatFilter(searchField.text);
                                }
                            }
                        }
                    }

                }

            }

            Row {
                width: parent.width
                spacing: 10

                Item {
                    width: wa.leftWidth
                    height: wa.bodyHeight()

                    Rectangle {
                        id: chatBox

                        anchors.fill: parent
                        radius: 0
                        color: rootRef.withAlpha(wa.fg, 0.05)
                        clip: true

                        ListView {
                            id: chatList

                            anchors.fill: parent
                            anchors.margins: 4
                            model: chatModel
                            spacing: 6
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            keyNavigationWraps: true

                            // Springy chat list motion.
                            move: Transition {
                                Anim { property: "y"; type: Anim.BouncyFast }
                                Anim { property: "opacity"; to: 1; type: Anim.DefaultEffects }
                            }
                            displaced: Transition {
                                Anim { property: "y"; type: Anim.BouncyFast }
                            }
                            add: Transition {
                                Anim { property: "opacity"; from: 0; to: 1; type: Anim.DefaultEffects }
                            }

                            Rectangle {
                                id: chatMorph

                                readonly property real targetY: (chatList.currentIndex >= 0 && chatList.currentItem !== null) ? chatList.currentItem.y : 0

                                parent: chatList.contentItem
                                z: 0
                                visible: chatModel.count > 0 && chatList.currentIndex >= 0 && chatList.currentItem !== null
                                width: chatList.width
                                height: wa.chatRowHeight
                                radius: 0
                                color: wa.accent
                                y: targetY

                                Behavior on y {
                                    Anim { type: Anim.BouncyFast }
                                }

                            }

                            delegate: Item {
                                required property int index
                                required property string jid
                                required property string name
                                required property string kind
                                required property bool unread
                                required property int unreadCount
                                required property string lastTs
                                required property int muted
                                readonly property bool isMuted: kind === "group" && muted !== 0
                                readonly property bool isSelected: chatList.currentIndex === index

                                width: chatList.width
                                height: wa.chatRowHeight
                                z: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Item {
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        Layout.alignment: Qt.AlignVCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 0
                                            color: isSelected ? rootRef.withAlpha(wa.accent, 0.28) : rootRef.withAlpha(wa.fg, 0.1)

                                            Text {
                                                anchors.centerIn: parent
                                                text: wa.initials(name)
                                                color: isSelected ? wa.selectedFg : wa.fg
                                                font.family: wa.arabicFont
                                                font.pixelSize: wa.fontSize + 2
                                                font.weight: Font.Bold
                                            }

                                            Behavior on color {
                                                CAnim { type: CAnim.FastEffects }

                                            }

                                        }

                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        Text {
                                            width: parent.width
                                            textFormat: Text.PlainText
                                            text: name
                                            elide: Text.ElideRight
                                            color: isSelected ? wa.selectedFg : wa.fg
                                            font.family: wa.arabicFont
                                            font.pixelSize: wa.fontSize
                                            font.weight: Font.Medium
                                            maximumLineCount: 1
                                        }

                                        Text {
                                            width: parent.width
                                            visible: unreadCount > 0
                                            text: (unreadCount === 1 ? "1 unread" : unreadCount + " unread")
                                            elide: Text.ElideRight
                                            color: isSelected ? rootRef.withAlpha(wa.selectedFg, 0.8) : rootRef.withAlpha(wa.fg, 0.75)
                                            font.family: wa.uiFont
                                            font.pixelSize: Math.max(9, wa.fontSize - 3)
                                        }

                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 20
                                        Layout.preferredHeight: 20
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 0
                                        visible: unread && unreadCount === 0
                                        color: isSelected ? wa.accentText : wa.accent
                                    }

                                    QIcon {
                                        Layout.alignment: Qt.AlignVCenter
                                        visible: isMuted
                                        source: Qt.resolvedUrl("../assets/icons/bell-off.svg")
                                        color: isSelected ? rootRef.withAlpha(wa.selectedFg, 0.7) : rootRef.withAlpha(wa.fg, 0.75)
                                        iconSize: Math.max(12, wa.fontSize + 1)
                                    }

                                    Text {
                                        Layout.preferredWidth: 54
                                        Layout.alignment: Qt.AlignVCenter
                                        text: wa.fmtTime(lastTs)
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                        color: isSelected ? rootRef.withAlpha(wa.selectedFg, 0.7) : rootRef.withAlpha(wa.fg, 0.65)
                                        font.family: wa.uiFont
                                        font.pixelSize: Math.max(9, wa.fontSize - 3)
                                    }

                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        chatList.currentIndex = index;
                                        wa.selectChat(chatModel.get(index));
                                    }
                                }

                            }

                        }

                        Text {
                            anchors.centerIn: parent
                            visible: chatModel.count === 0 && !wa.chatsLoading && !wa.chatsFailed
                            text: "No chats"
                            color: rootRef.withAlpha(wa.fg, 0.7)
                            font.family: wa.uiFont
                            font.pixelSize: wa.fontSize - 1
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: wa.chatsFailed
                            text: "Not authenticated.\nOpen a terminal and run:\n  wacli auth"
                            horizontalAlignment: Text.AlignHCenter
                            color: wa.errorColor
                            font.family: wa.uiFont
                            font.pixelSize: wa.fontSize - 1
                            lineHeight: 1.4
                        }

                    }

                }

                Item {
                    width: card.width - wa.pad * 2 - wa.leftWidth - 10
                    height: wa.bodyHeight()

                    Rectangle {
                        id: msgBox

                        anchors.fill: parent
                        radius: 0
                        color: rootRef.withAlpha(wa.fg, 0.05)
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                width: parent.width
                                height: wa.headerHeight
                                radius: 0
                                color: rootRef.withAlpha(wa.fg, 0.06)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12

                                    Text {
                                        textFormat: Text.PlainText
                                        text: wa.currentJid ? wa.shortName(wa.currentChat || {
                                        }) : "Select a chat"
                                        elide: Text.ElideRight
                                        color: wa.currentJid ? wa.fg : rootRef.withAlpha(wa.fg, 0.78)
                                        font.family: wa.arabicFont
                                        font.pixelSize: wa.fontSize
                                        font.weight: Font.DemiBold
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: wa.currentJid.length > 0 && (wa.msgsLoading || wa.sending)
                                        text: wa.msgsLoading ? "Loading\u2026" : "Sending\u2026"
                                        color: rootRef.withAlpha(wa.fg, 0.7)
                                        font.family: wa.uiFont
                                        font.pixelSize: Math.max(10, wa.fontSize - 2)
                                    }

                                    Text {
                                        visible: wa.currentJid.length > 0 && wa.sendFailed
                                        text: wa.sendStatus
                                        textFormat: Text.PlainText
                                        color: wa.errorColor
                                        font.family: wa.uiFont
                                        font.pixelSize: Math.max(10, wa.fontSize - 2)
                                        font.weight: Font.Medium
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 20
                                        Layout.preferredHeight: 20
                                        radius: 0
                                        visible: wa.currentJid
                                        color: backHover.containsMouse ? rootRef.withAlpha(wa.fg, 0.25) : rootRef.withAlpha(wa.fg, 0.1)

                                        QIcon {
                                            anchors.centerIn: parent
                                            source: Qt.resolvedUrl("../assets/icons/close.svg")
                                            color: wa.fg
                                            iconSize: Math.max(11, wa.fontSize - 1)
                                        }

                                        MouseArea {
                                            id: backHover

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                wa.clearChat();
                                                searchField.forceActiveFocus();
                                            }
                                        }

                                    }

                                }

                            }

                            Item {
                                width: parent.width
                                height: Math.max(0, wa.bodyHeight() - 16 - wa.headerHeight - 16 - wa.sendHeight)
                                clip: true

                                ListView {
                                    id: msgList

                                    anchors.fill: parent
                                    model: messageModel
                                    spacing: 4
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: true

                                    // Incoming messages spring in.
                                    add: Transition {
                                        Anim { property: "opacity"; from: 0; to: 1; type: Anim.DefaultEffects }
                                        Anim { property: "y"; from: 14; type: Anim.BouncyFast }
                                    }
                                    displaced: Transition {
                                        Anim { property: "y"; type: Anim.BouncyFast }
                                    }

                                    delegate: Item {
                                        id: msgItem

required property int index
                                        required property bool fromMe
                                        required property string sender
                                        required property string text
                                        required property string time
                                        required property string mediaType
                                        required property string src
                                        readonly property bool isImage: mediaType === "image" && src !== ""
                                        readonly property bool isSticker: mediaType === "sticker" && src !== ""
                                        readonly property bool isAudio: mediaType === "audio" && src !== ""
                                        readonly property bool isAnimated: /\.(webp|gif)$/i.test(src)
                                        readonly property string mediaSource: wa.mediaUrl(src)

                                        width: msgList.width
                                        height: bubbleCol.implicitHeight + 8

                                        Column {
                                            id: bubbleCol

                                            anchors.top: parent.top
                                            anchors.topMargin: 4
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 4
                                            anchors.left: fromMe ? undefined : parent.left
                                            anchors.right: fromMe ? parent.right : undefined
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            width: msgList.width - 8
                                            spacing: 2

                                            Rectangle {
                                                id: imageBubble

                                                visible: msgItem.isImage
                                                width: Math.min(wa.imgMaxW, Math.max(60, bubbleCol.width - 8))
                                                height: wa.imgMaxH
                                                radius: 0
                                                clip: true
                                                color: rootRef.withAlpha(wa.fg, 0.08)

                                                AnimatedImage {
                                                    id: imageItem

                                                    anchors.fill: parent
                                                    visible: msgItem.isAnimated && status !== Image.Error
                                                    playing: wa.active && visible
                                                    source: msgItem.isImage && msgItem.isAnimated ? msgItem.mediaSource : ""
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    smooth: true
                                                }

                                                Image {
                                                    id: staticImage

                                                    anchors.fill: imageItem.parent
                                                    visible: !msgItem.isAnimated || imageItem.status === Image.Error
                                                    source: visible ? msgItem.mediaSource : ""
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    smooth: true
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (msgItem.src.length === 0) {
                                                            wa.loadMessages();
                                                            return ;
                                                        }
                                                        Quickshell.execDetached(["swayimg", msgItem.src]);
                                                    }
                                                }

                                                Text {
                                                    visible: msgItem.text.length === 0
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    anchors.margins: 6
                                                    text: msgItem.time
                                                    color: "#dddddd"
                                                    font.family: wa.uiFont
                                                    font.pixelSize: Math.max(8, wa.fontSize - 3)
                                                }

                                            }

                                            Rectangle {
                                                id: stickerBubble

                                                visible: msgItem.isSticker
                                                width: 160
                                                height: 160
                                                radius: 0
                                                clip: true
                                                color: "transparent"

                                                AnimatedImage {
                                                    id: stickerImage

                                                    anchors.fill: parent
                                                    visible: status !== Image.Error
                                                    playing: wa.active && stickerBubble.visible && visible
                                                    source: msgItem.isSticker ? msgItem.mediaSource : ""
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    smooth: true
                                                }

                                                Image {
                                                    anchors.fill: parent
                                                    visible: stickerImage.status === Image.Error
                                                    source: msgItem.isSticker && visible ? msgItem.mediaSource : ""
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    smooth: true
                                                }

                                                Text {
                                                    visible: msgItem.text.length === 0
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    anchors.margins: 6
                                                    text: msgItem.time
                                                    color: wa.fg
                                                    font.family: wa.uiFont
                                                    font.pixelSize: Math.max(8, wa.fontSize - 3)
                                                }

                                            }

                                            Rectangle {
                                                id: audioBubble

                                                visible: msgItem.isAudio
                                                width: Math.min(230, bubbleCol.width - 8)
                                                height: 40
                                                radius: 0
                                                color: fromMe ? wa.accent : rootRef.withAlpha(wa.fg, 0.1)

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: wa.toggleAudio(msgItem.src)
                                                }

                                                Item {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 10

                                                    Rectangle {
                                                        id: playBtn

                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 26
                                                        height: 26
                                                        radius: 0
                                                        color: rootRef.withAlpha("#ffffff", 0.25)

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: wa.playingAudioSrc === msgItem.src ? "II" : "▶"
                                                            color: wa.accentText
                                                            font.pixelSize: Math.max(9, wa.fontSize - 1)
                                                        }

                                                    }

                                                    Text {
                                                        id: audioTimeText

                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: msgItem.time
                                                        color: rootRef.withAlpha(wa.accentText, 0.7)
                                                        font.family: wa.uiFont
                                                        font.pixelSize: Math.max(8, wa.fontSize - 3)
                                                    }

                                                }

                                                Behavior on color {
                                                    CAnim { type: CAnim.FastEffects }

                                                }

                                            }

                                            Rectangle {
                                                id: textBubble

                                                readonly property real textWidth: Math.min(bubbleText.implicitWidth, wa.bubbleMaxW)
                                                readonly property real availableWidth: bubbleCol.width > 0 ? bubbleCol.width : 9999

                                                visible: msgItem.text.length > 0
                                                width: Math.min(textBubble.textWidth + timeText.implicitWidth + 6 + wa.msgPad * 2, textBubble.availableWidth)
                                                height: Math.max(bubbleText.implicitHeight, timeText.implicitHeight) + 6
                                                radius: 0
                                                color: fromMe ? wa.accent : rootRef.withAlpha(wa.fg, 0.1)

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: wa.msgPad
                                                    anchors.rightMargin: wa.msgPad
                                                    anchors.topMargin: 3
                                                    anchors.bottomMargin: 3
                                                    spacing: 6

                                                    Text {
                                                        id: bubbleText

                                                        textFormat: Text.PlainText
                                                        Layout.preferredWidth: Math.min(bubbleText.implicitWidth, wa.bubbleMaxW)
                                                        Layout.alignment: Qt.AlignVCenter
                                                        text: msgItem.text
                                                        color: fromMe ? wa.accentText : wa.fg
                                                        font.family: wa.arabicFont
                                                        font.pixelSize: wa.fontSize
                                                        wrapMode: Text.Wrap
                                                        lineHeight: 1.25
                                                    }

                                                    Text {
                                                        id: timeText

                                                        Layout.alignment: Qt.AlignBottom
                                                        text: msgItem.time
                                                        color: fromMe ? rootRef.withAlpha(wa.accentText, 0.7) : rootRef.withAlpha(wa.fg, 0.7)
                                                        font.family: wa.uiFont
                                                        font.pixelSize: Math.max(8, wa.fontSize - 3)
                                                    }

                                                }

                                                Behavior on color {
                                                    CAnim { type: CAnim.FastEffects }

                                                }

                                            }

                                            Text {
                                                textFormat: Text.PlainText
                                                visible: msgItem.sender.length > 0 && !msgItem.fromMe
                                                text: msgItem.sender
                                                color: rootRef.withAlpha(wa.fg, 0.65)
                                                font.family: wa.uiFont
                                                font.pixelSize: Math.max(9, wa.fontSize - 3)
                                            }

                                        }

                                    }

                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: messageModel.count === 0
                                    text: wa.msgsLoading ? "Loading messages\u2026" : wa.msgsFailed ? "Failed to load messages" : wa.currentJid ? "No messages yet" : ""
                                    color: rootRef.withAlpha(wa.fg, 0.7)
                                    font.family: wa.uiFont
                                    font.pixelSize: wa.fontSize - 1
                                }

                            }

                            Rectangle {
                                id: sendBox

                                width: parent.width
                                height: wa.sendHeight
                                radius: 0
                                color: rootRef.withAlpha(wa.fg, 0.06)
                                border.width: 1
                                border.color: sendField.inputFocus ? rootRef.withAlpha(wa.fg, 0.35) : rootRef.withAlpha(wa.fg, 0.1)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 6
                                    spacing: 8

                                    CharField {
                                        id: sendField

                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        textColor: wa.fg
                                        font.family: wa.arabicFont
                                        font.pixelSize: wa.fontSize
                                        selectByMouse: true
                                        verticalAlignment: Text.AlignVCenter
                                        placeholderText: wa.currentJid ? "Type a message\u2026" : "Select a chat first"
                                        placeholderTextColor: rootRef.withAlpha(wa.fg, 0.35)
                                        readOnly: wa.currentJid.length === 0
                                        enabled: wa.currentJid.length > 0
                                        onAccepted: wa.sendMessage()
                                        Keys.onEscapePressed: (event) => {
                                            searchField.forceActiveFocus();
                                            event.accepted = true;
                                        }

                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 0
                                        color: pasteHover.containsMouse ? rootRef.withAlpha(wa.fg, 0.14) : rootRef.withAlpha(wa.fg, 0.06)
                                        enabled: wa.currentJid.length > 0 && !wa.sending
                                        opacity: enabled ? 1 : 0.4

                                        Image {
                                            anchors.centerIn: parent
                                            width: 15
                                            height: 15
                                            source: "data:image/svg+xml;utf8," + encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='" + wa.accent.toString() + "'><path d='M19,2h-4.18C14.4,0.84 13.3,0 12,0S9.6,0.84 9.18,2H5C3.9,2 3,2.9 3,4v16c0,1.1 0.9,2 2,2h14c1.1,0 2,-0.9 2,-2V4C21,2.9 20.1,2 19,2zM12,2c0.55,0 1,0.45 1,1s-0.45,1 -1,1 -1,-0.45 -1,-1 0.45,-1 1,-1zM19,20H5V4h2v3h10V4h2V20z'/></svg>")
                                        }

                                        MouseArea {
                                            id: pasteHover

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wa.sendPaste()
                                        }

                                        Behavior on color {
                                            CAnim { type: CAnim.FastEffects }

                                        }

                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 0
                                        color: photoHover.containsMouse ? rootRef.withAlpha(wa.fg, 0.14) : rootRef.withAlpha(wa.fg, 0.06)
                                        enabled: wa.currentJid.length > 0 && !wa.sending
                                        opacity: enabled ? 1 : 0.4

                                        Image {
                                            anchors.centerIn: parent
                                            width: 15
                                            height: 15
                                            source: "data:image/svg+xml;utf8," + encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='" + rootRef.withAlpha(wa.fg, 0.7).toString() + "'><path d='M21,19V5c0,-1.1 -0.9,-2 -2,-2H5C3.9,3 3,3.9 3,5v14c0,1.1 0.9,2 2,2h14c1.1,0 2,-0.9 2,-2zM8.5,13.5l2.5,3.01L14.5,12l4.5,6H5l3.5,-4.5z'/></svg>")
                                        }

                                        MouseArea {
                                            id: photoHover

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wa.sendFile()
                                        }

                                        Behavior on color {
                                            CAnim { type: CAnim.FastEffects }

                                        }

                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 0
                                        color: sendHover.containsMouse || sendField.text.length > 0 ? wa.accent : rootRef.withAlpha(wa.fg, 0.15)
                                        enabled: wa.currentJid.length > 0 && !wa.sending && sendField.text.length > 0
                                        opacity: enabled ? 1 : 0.4

                                        QIcon {
                                            anchors.centerIn: parent
                                            source: Qt.resolvedUrl("../assets/icons/send.svg")
                                            color: sendField.text.length > 0 ? wa.accentText : rootRef.withAlpha(wa.fg, 0.7)
                                            iconSize: wa.fontSize + 3
                                        }

                                        MouseArea {
                                            id: sendHover

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wa.sendMessage()
                                        }

                                        Behavior on color {
                                            CAnim { type: CAnim.FastEffects }

                                        }

                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

        transform: Translate {
            y: (1 - wa.animProgress) * 8
        }

    }

    Behavior on animProgress {
        Anim { type: Anim.Bouncy }
    }

}
