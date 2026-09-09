import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// WhatsApp chat panel backed by wacli CLI. Everything is fetched on demand:
// the chat list loads when the overlay opens, and messages load when a chat
// is selected. No background process is kept alive.

Item {
    id: wa

    property var rootRef: null
    property bool active: false

    signal requestClose()

    readonly property int cardWidth: 940
    readonly property int leftWidth: 300
    readonly property int chatRowHeight: 58
    readonly property int maxChatRows: 8
    readonly property int headerHeight: 40
    readonly property int sendHeight: 40
    readonly property int searchHeight: 40
    readonly property int pad: 14
    readonly property int cornerRadius: 20
    readonly property int msgPad: 12
    readonly property real bubbleMaxW: 380
    property string activeTab: "chats"

    readonly property string cardTile: "whatsapp_card"
    readonly property color cardColor: rootRef
        ? (rootRef.qsLight ? rootRef.pillColor(cardTile) : rootRef.colorOf(cardTile))
        : "#f3dfd1"
    readonly property color cardBorder: rootRef
        ? rootRef.withAlpha(rootRef.colorOf("widget_border"), rootRef.qsLight ? 0.5 : 0.35)
        : "#00000000"
    readonly property color fg: rootRef
        ? (rootRef.qsLight ? rootRef.qsPillFg : rootRef.textColor)
        : "#000000"
    readonly property color accent: fg
    readonly property color accentText: rootRef && rootRef.qsLight ? "#000000" : "#ffffff"
    readonly property color selectedFg: accentText
    readonly property color errorColor: rootRef ? Qt.color(rootRef.colorOf("widget_error")) : "#e30000"
    readonly property string iconFont: rootRef ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string fontFamily: rootRef ? rootRef.fontFamily : "Ndot 57"
    readonly property string uiFont: rootRef ? rootRef.uiFont : "Inter"
    readonly property string arabicFont: "SF Arabic"
    readonly property int fontSize: rootRef ? rootRef.fontSize : 13
    readonly property string homeDir: Quickshell.env("HOME")

    function alpha(c: color, a: double): color {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    property real animProgress: wa.active ? 1.0 : 0.0
    Behavior on animProgress {
        NumberAnimation {
            duration: wa.active ? 320 : 220
            easing.type: Easing.OutCubic
        }
    }

    readonly property int bottomMargin: 24
    readonly property real slideOffset: (1.0 - wa.animProgress) * (wa.bottomMargin * 2 + card.height)
    opacity: wa.animProgress

    // ---- state ----
    property var rawChats: []
    property var currentChat: null
    property string currentJid: ""
    property bool chatsLoading: false
    property bool chatsFailed: false
    property bool msgsLoading: false
    property bool msgsFailed: false
    property bool sending: false

    function safeJid(jid: string): string {
        return String(jid).replace(/[^A-Za-z0-9]/g, "_")
    }

    function initials(name: string): string {
        var n = String(name || "").trim()
        if (n.length === 0) return "?"
        var parts = n.split(/\s+/)
        if (parts.length >= 2)
            return parts[0].charAt(0) + parts[parts.length - 1].charAt(0)
        return n.charAt(0)
    }

    function shortName(chat): string {
        var n = String(chat.name || "").trim()
        if (n.length > 0) return n
        var jid = String(chat.jid || "")
        var m = jid.match(/^(\d+)/)
        return m ? m[1] : jid
    }

    function fmtTime(iso: string): string {
        var d = Date.parse(iso)
        if (isNaN(d)) return ""
        var t = new Date(d)
        var h = t.getHours(), m = t.getMinutes()
        var hh = (h % 12 === 0 ? 12 : h % 12)
        return hh + ":" + (m < 10 ? "0" : "") + m + (h < 12 ? " AM" : " PM")
    }

    function fmtDate(iso: string): string {
        var d = Date.parse(iso)
        if (isNaN(d)) return ""
        var t = new Date(d)
        var now = new Date()
        var sameDay = t.toDateString() === now.toDateString()
        return sameDay ? wa.fmtTime(iso)
            : (t.getMonth() + 1) + "/" + (t.getDate() < 10 ? "0" : "") + t.getDate() + " " + wa.fmtTime(iso)
    }

    // ---- loading ----
    onActiveChanged: {
        if (wa.active) {
            wa.currentChat = null
            wa.currentJid = ""
            messageModel.clear()
            searchField.text = ""
            wa.chatsFailed = false
            wa.activeTab = "chats"
            wa.loadChats()
            wa.applyChatFilter("")
            focusRequest.restart()
        }
    }

    function loadChats() {
        wa.chatsLoading = true
        Quickshell.execDetached(["bash", Quickshell.shellDir + "/scripts/wa-contacts.sh"])
    }

    function onChatsData(obj) {
        wa.chatsLoading = false
        wa.chatsFailed = false
        if (!obj || !Array.isArray(obj.chats)) {
            wa.chatsFailed = true
            return
        }
        wa.rawChats = obj.chats
        wa.applyChatFilter(searchField.text)
    }

    function applyChatFilter(text) {
        var q = (text || "").toLowerCase()
        var tab = wa.activeTab
        chatModel.clear()
        for (var i = 0; i < wa.rawChats.length; i++) {
            var c = wa.rawChats[i]
            if (!c || !c.jid) continue
            var kind = c.kind || "dm"
            if (tab === "groups" ? kind !== "group" : kind === "group") continue
            var n = wa.shortName(c).toLowerCase()
            if (q.length > 0 && n.indexOf(q) < 0) continue
            chatModel.append({
                jid: c.jid,
                name: wa.shortName(c),
                kind: kind,
                unread: c.unread === true,
                unreadCount: c.unread_count || 0,
                lastTs: c.last_message_ts || ""
            })
        }
        chatList.currentIndex = 0
    }

    // ---- chat selection ----
    function selectChat(chat) {
        if (!chat || !chat.jid) return
        wa.currentChat = chat
        wa.currentJid = chat.jid
        wa.msgsFailed = false
        messageModel.clear()
        wa.msgsLoading = true
        messagesFile.path = wa.homeDir + "/.cache/quickshell/wa-messages-" + wa.safeJid(chat.jid) + ".json"
        Quickshell.execDetached(["bash", Quickshell.shellDir + "/scripts/wa-messages.sh", chat.jid])
        messagesFile.reload()
        inputFocus.restart()
    }

    function onMessagesData(obj) {
        if (!wa.currentJid) return
        wa.msgsLoading = false
        if (!obj || !Array.isArray(obj.messages)) {
            wa.msgsFailed = true
            return
        }
        wa.msgsFailed = false
        messageModel.clear()
        for (var i = obj.messages.length - 1; i >= 0; i--) {
            var m = obj.messages[i]
            if (!m || !m.MsgID) continue
            var body = String(m.DisplayText || m.Text || "")
            messageModel.append({
                fromMe: m.FromMe === true,
                sender: String(m.SenderName || (m.FromMe ? "You" : "")),
                text: body,
                time: wa.fmtDate(m.Timestamp)
            })
        }
        Qt.callLater(msgList.positionViewAtEnd)
    }

    // ---- send ----
    function sendMessage() {
        var text = sendField.text.trim()
        if (text.length === 0 || !wa.currentJid) return
        wa.sending = true
        sendProc.command = ["bash", Quickshell.shellDir + "/scripts/wa-send.sh", wa.currentJid, text]
        sendProc.running = true
        messageModel.append({
            fromMe: true,
            sender: "You",
            text: text,
            time: wa.fmtTime(new Date().toISOString())
        })
        sendField.text = ""
        Qt.callLater(msgList.positionViewAtEnd)
        refreshTimer.restart()
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
                wa.onChatsData(JSON.parse(String(chatsFile.text())))
            } catch (err) {
                console.log("[wa] chats parse error:", err)
                wa.chatsLoading = false
                wa.chatsFailed = true
            }
        }
        onLoadFailed: (error) => {
            console.log("[wa] chats load failed:", error)
            wa.chatsLoading = false
            wa.chatsFailed = true
        }
    }

    FileView {
        id: messagesFile
        path: wa.homeDir + "/.cache/quickshell/wa-messages-none.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: messagesFile.reload()
        onLoaded: {
            if (!wa.currentJid) return
            try {
                wa.onMessagesData(JSON.parse(String(messagesFile.text())))
            } catch (err) {
                console.log("[wa] messages parse error:", err)
                wa.msgsLoading = false
                wa.msgsFailed = true
            }
        }
        onLoadFailed: (error) => {
            console.log("[wa] messages load failed:", error)
            wa.msgsLoading = false
            wa.msgsFailed = true
        }
    }

    Process {
        id: sendProc
        onExited: () => {
            wa.sending = false
        }
    }

    Timer {
        id: refreshTimer
        interval: 1600
        repeat: false
        onTriggered: {
            if (wa.currentJid)
                Quickshell.execDetached(["bash", Quickshell.shellDir + "/scripts/wa-messages.sh", wa.currentJid])
        }
    }

    Timer {
        id: pollTimer
        interval: 6000
        repeat: true
        running: wa.active
        onTriggered: {
            Quickshell.execDetached(["bash", Quickshell.shellDir + "/scripts/wa-contacts.sh"])
            if (wa.currentJid)
                Quickshell.execDetached(["bash", Quickshell.shellDir + "/scripts/wa-messages.sh", wa.currentJid])
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

    // ---- body height ----
    function countKind(kind): int {
        var n = 0
        for (var i = 0; i < wa.rawChats.length; i++) {
            if ((wa.rawChats[i].kind || "dm") === kind) n++
        }
        return n
    }

    function bodyHeight(): int {
        var rows = Math.min(wa.maxChatRows, Math.max(1, chatModel.count))
        return wa.chatRowHeight * rows + 2 * (rows - 1) + 20
    }

    // ---- background click to dismiss ----
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
        width: wa.cardWidth
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.floor(parent.height - card.height - wa.bottomMargin) + wa.slideOffset
        height: contentColumn.implicitHeight + wa.pad * 2
        radius: wa.cornerRadius
        color: wa.cardColor
        border.width: 1
        border.color: wa.cardBorder
        clip: true

        SurfaceGradient {
            anchors.fill: parent
            inset: 1
            color: wa.cardColor
            radius: wa.cornerRadius
        }

        Column {
            id: contentColumn
            x: wa.pad
            y: wa.pad
            width: wa.cardWidth - wa.pad * 2
            spacing: 10

            // -------- header --------
            RowLayout {
                width: parent.width
                spacing: 6

                Text {
                    text: "󰈯"
                    color: wa.fg
                    font.family: wa.iconFont
                    font.pixelSize: wa.fontSize + 2
                    Layout.preferredWidth: 24
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "WhatsApp"
                    color: wa.fg
                    font.family: wa.fontFamily
                    font.pixelSize: wa.fontSize + 1
                    font.weight: Font.Black
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text: wa.currentChat ? wa.shortName(wa.currentChat) : ""
                    visible: wa.currentChat !== null
                    elide: Text.ElideRight
                    color: wa.alpha(wa.fg, 0.5)
                    font.family: wa.uiFont
                    font.pixelSize: wa.fontSize - 2
                    verticalAlignment: Text.AlignVCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: wa.chatsLoading ? "Loading\u2026" : (wa.chatsFailed ? "Not authenticated" : "")
                    color: wa.chatsFailed ? wa.errorColor : wa.alpha(wa.fg, 0.5)
                    font.family: wa.uiFont
                    font.pixelSize: Math.max(10, wa.fontSize - 2)
                    font.weight: Font.Medium
                    visible: wa.chatsLoading || wa.chatsFailed
                }

                Rectangle {
                    Layout.preferredWidth: refreshText.implicitWidth + 20
                    Layout.preferredHeight: 24
                    radius: 7
                    color: refreshHover.containsMouse ? wa.alpha(wa.fg, 0.2) : wa.alpha(wa.fg, 0.08)
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        id: refreshText
                        anchors.centerIn: parent
                        text: "󰑐 Refresh"
                        color: wa.fg
                        font.family: wa.uiFont
                        font.pixelSize: wa.fontSize - 1
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: refreshHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wa.loadChats()
                            if (wa.currentJid) {
                                wa.msgsLoading = true
                                Quickshell.execDetached(["bash", Quickshell.shellDir + "/scripts/wa-messages.sh", wa.currentJid])
                            }
                        }
                    }
                }
            }

            // -------- search box --------
            Rectangle {
                id: searchBox
                width: parent.width
                height: wa.searchHeight
                radius: wa.searchHeight / 2
                color: wa.alpha(wa.fg, 0.08)
                border.width: 1
                border.color: searchField.activeFocus ? wa.alpha(wa.fg, 0.4) : wa.alpha(wa.fg, 0.12)
                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 6
                    spacing: 8

                    Text {
                        text: "󰭎"
                        color: wa.alpha(wa.fg, 0.55)
                        font.family: wa.iconFont
                        font.pixelSize: wa.fontSize + 1
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: wa.fg
                        font.family: wa.uiFont
                        font.pixelSize: wa.fontSize + 1
                        font.weight: Font.Medium
                        placeholderText: "Search chats\u2026"
                        placeholderTextColor: wa.alpha(wa.fg, 0.4)
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter
                        onTextEdited: wa.applyChatFilter(searchField.text)
                        Keys.onDownPressed: (event) => {
                            if (chatModel.count > 0)
                                chatList.incrementCurrentIndex()
                            event.accepted = true
                        }
                        Keys.onUpPressed: (event) => {
                            chatList.decrementCurrentIndex()
                            event.accepted = true
                        }
                        Keys.onReturnPressed: (event) => {
                            if (chatModel.count > 0)
                                wa.selectChat(chatModel.get(chatList.currentIndex))
                            event.accepted = true
                        }
                        Keys.onTabPressed: (event) => {
                            if (wa.currentJid) sendField.forceActiveFocus()
                            event.accepted = true
                        }
                        Keys.onEscapePressed: (event) => {
                            wa.requestClose()
                            event.accepted = true
                        }
                        background: Item {
                        }
                    }

                    Rectangle {
                        visible: searchField.text.length > 0
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 11
                        color: clearHover.containsMouse ? wa.alpha(wa.fg, 0.25) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: wa.fg
                            font.family: wa.iconFont
                            font.pixelSize: wa.fontSize
                        }
                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = ""
                                wa.applyChatFilter("")
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // -------- section tabs --------
            Rectangle {
                width: 216
                height: 30
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 15
                color: wa.alpha(wa.fg, 0.06)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: wa.activeTab === "chats" ? wa.accentText : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }
                            }
                        }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "Chats"
                                color: wa.activeTab === "chats"
                                    ? wa.accent
                                    : wa.alpha(wa.fg, 0.6)
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
                                wa.activeTab = "chats"
                                wa.applyChatFilter(searchField.text)
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: wa.activeTab === "groups" ? wa.accentText : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }
                            }
                        }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "Groups"
                                color: wa.activeTab === "groups"
                                    ? wa.accent
                                    : wa.alpha(wa.fg, 0.6)
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
                                wa.activeTab = "groups"
                                wa.applyChatFilter(searchField.text)
                            }
                        }
                    }
                }
            }

            // -------- body: chat list + conversation --------
            Row {
                width: parent.width
                spacing: 10

                // left: chat list
                Item {
                    width: wa.leftWidth
                    height: wa.bodyHeight()

                    Rectangle {
                        id: chatBox
                        anchors.fill: parent
                        radius: 12
                        color: wa.alpha(wa.fg, 0.05)
                        clip: true

                        ListView {
                            id: chatList
                            anchors.fill: parent
                            anchors.margins: 4
                            model: chatModel
                            spacing: 2
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            keyNavigationWraps: true

                            Rectangle {
                                id: chatMorph
                                parent: chatList.contentItem
                                z: 0
                                visible: chatModel.count > 0 && chatList.currentIndex >= 0 && chatList.currentItem !== null
                                width: chatList.width
                                height: wa.chatRowHeight
                                radius: 9
                                color: wa.accent
                                readonly property real targetY: (chatList.currentIndex >= 0 && chatList.currentItem !== null)
                                    ? chatList.currentItem.y : 0
                                y: targetY
                                Behavior on y {
                                    NumberAnimation {
                                        duration: 240
                                        easing.type: Easing.OutQuint
                                    }
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
                                            radius: 20
                                            color: isSelected
                                                ? wa.alpha(wa.accentText, 0.16)
                                                : wa.alpha(wa.fg, 0.10)
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 150
                                                }
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: wa.initials(name)
                                                color: isSelected ? wa.selectedFg : wa.fg
                                                font.family: wa.arabicFont
                                                font.pixelSize: wa.fontSize + 2
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        Text {
                                            width: parent.width
                                            text: name
                                            elide: Text.ElideRight
                                            color: isSelected ? wa.selectedFg : wa.fg
                                            font.family: wa.arabicFont
                                            font.pixelSize: wa.fontSize + (isSelected ? 1 : 0)
                                            font.weight: isSelected ? Font.Black : Font.Medium
                                            maximumLineCount: 1
                                        }

                                        Text {
                                            width: parent.width
                                            visible: unreadCount > 0
                                            text: (unreadCount === 1 ? "1 unread" : unreadCount + " unread")
                                            elide: Text.ElideRight
                                            color: isSelected ? wa.alpha(wa.selectedFg, 0.8) : wa.alpha(wa.fg, 0.55)
                                            font.family: wa.uiFont
                                            font.pixelSize: Math.max(9, wa.fontSize - 3)
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 20
                                        Layout.preferredHeight: 20
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 10
                                        visible: unread && unreadCount === 0
                                        color: isSelected ? wa.accentText : wa.accent
                                        Text {
                                            anchors.centerIn: parent
                                            text: "●"
                                            font.pixelSize: 8
                                            color: isSelected ? wa.accent : wa.accentText
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 54
                                        Layout.alignment: Qt.AlignVCenter
                                        text: wa.fmtTime(lastTs)
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                        color: isSelected ? wa.alpha(wa.selectedFg, 0.7) : wa.alpha(wa.fg, 0.45)
                                        font.family: wa.uiFont
                                        font.pixelSize: Math.max(9, wa.fontSize - 3)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        chatList.currentIndex = index
                                        wa.selectChat(chatModel.get(index))
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: chatModel.count === 0 && !wa.chatsLoading && !wa.chatsFailed
                            text: "No chats"
                            color: wa.alpha(wa.fg, 0.5)
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

                // right: conversation
                Item {
                    width: wa.cardWidth - wa.pad * 2 - wa.leftWidth - 10
                    height: wa.bodyHeight()

                    Rectangle {
                        id: msgBox
                        anchors.fill: parent
                        radius: 12
                        color: wa.alpha(wa.fg, 0.05)
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                width: parent.width
                                height: wa.headerHeight
                                radius: 9
                                color: wa.alpha(wa.fg, 0.06)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12

                                    Text {
                                        text: "󰈯"
                                        color: wa.alpha(wa.fg, 0.6)
                                        font.family: wa.iconFont
                                        font.pixelSize: wa.fontSize
                                    }

                                    Text {
                                        text: wa.currentJid ? wa.shortName(wa.currentChat || {}) : "Select a chat"
                                        elide: Text.ElideRight
                                        color: wa.currentJid ? wa.fg : wa.alpha(wa.fg, 0.4)
                                        font.family: wa.arabicFont
                                        font.pixelSize: wa.fontSize
                                        font.weight: Font.Black
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: wa.msgsLoading || wa.sending
                                        text: wa.msgsLoading ? "Loading\u2026" : "Sending\u2026"
                                        color: wa.alpha(wa.fg, 0.5)
                                        font.family: wa.uiFont
                                        font.pixelSize: Math.max(10, wa.fontSize - 2)
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 20
                                        Layout.preferredHeight: 20
                                        radius: 10
                                        visible: wa.currentJid
                                        color: backHover.containsMouse ? wa.alpha(wa.fg, 0.25) : wa.alpha(wa.fg, 0.1)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅖"
                                            color: wa.fg
                                            font.family: wa.iconFont
                                            font.pixelSize: Math.max(9, wa.fontSize - 3)
                                        }
                                        MouseArea {
                                            id: backHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                wa.currentChat = null
                                                wa.currentJid = ""
                                                messageModel.clear()
                                                searchField.forceActiveFocus()
                                            }
                                        }
                                    }
                                }
                            }

                            // messages list
                            Item {
                                width: parent.width
                                height: wa.bodyHeight() - 16 - wa.headerHeight - 8 - wa.sendHeight
                                clip: true

                                ListView {
                                    id: msgList
                                    anchors.fill: parent
                                    model: messageModel
                                    spacing: 4
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: true

                                    delegate: Item {
                                        id: msgItem
                                        required property int index
                                        required property bool fromMe
                                        required property string sender
                                        required property string text
                                        required property string time

                                        width: msgList.width
                                        height: bubbleCol.implicitHeight + 8

                                        // bubble aligned left (received) or right (sent)
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
                                            spacing: 2

                                            Rectangle {
                                                width: Math.min(
                                                    Math.min(bubbleText.implicitWidth, wa.bubbleMaxW) + timeText.implicitWidth + 6 + wa.msgPad * 2,
                                                    bubbleCol.width > 0 ? bubbleCol.width : 9999)
                                                height: Math.max(bubbleText.implicitHeight, timeText.implicitHeight) + 6
                                                radius: 10
                                                color: fromMe ? wa.accent : wa.alpha(wa.fg, 0.10)
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 120
                                                    }
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: wa.msgPad
                                                    anchors.rightMargin: wa.msgPad
                                                    anchors.topMargin: 3
                                                    anchors.bottomMargin: 3
                                                    spacing: 6

                                                    Text {
                                                        id: bubbleText
                                                        Layout.alignment: Qt.AlignVCenter
                                                        Layout.maximumWidth: wa.bubbleMaxW
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
                                                        color: fromMe ? wa.alpha(wa.accentText, 0.7) : wa.alpha(wa.fg, 0.5)
                                                        font.family: wa.uiFont
                                                        font.pixelSize: Math.max(8, wa.fontSize - 3)
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: msgItem.sender.length > 0 && !msgItem.fromMe
                                                text: msgItem.sender
                                                color: wa.alpha(wa.fg, 0.45)
                                                font.family: wa.uiFont
                                                font.pixelSize: Math.max(9, wa.fontSize - 3)
                                            }
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: messageModel.count === 0
                                    text: wa.msgsLoading ? "Loading messages\u2026"
                                        : wa.msgsFailed ? "Failed to load messages"
                                        : wa.currentJid ? "No messages yet" : ""
                                    color: wa.alpha(wa.fg, 0.5)
                                    font.family: wa.uiFont
                                    font.pixelSize: wa.fontSize - 1
                                }
                            }

                            // send row
                            Rectangle {
                                id: sendBox
                                width: parent.width
                                height: wa.sendHeight
                                radius: wa.sendHeight / 2
                                color: wa.alpha(wa.fg, 0.06)
                                border.width: 1
                                border.color: sendField.activeFocus ? wa.alpha(wa.fg, 0.35) : wa.alpha(wa.fg, 0.1)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 6
                                    spacing: 8

                                    TextField {
                                        id: sendField
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: wa.fg
                                        font.family: wa.arabicFont
                                        font.pixelSize: wa.fontSize
                                        selectByMouse: true
                                        verticalAlignment: Text.AlignVCenter
                                        placeholderText: wa.currentJid ? "Type a message\u2026" : "Select a chat first"
                                        placeholderTextColor: wa.alpha(wa.fg, 0.35)
                                        readOnly: !wa.currentJid
                                        enabled: wa.currentJid !== null
                                        onAccepted: wa.sendMessage()
                                        Keys.onEscapePressed: (event) => {
                                            searchField.forceActiveFocus()
                                            event.accepted = true
                                        }
                                        background: Item {
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 15
                                        color: sendHover.containsMouse || sendField.text.length > 0
                                            ? wa.accent : wa.alpha(wa.fg, 0.15)
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰇰"
                                            color: sendField.text.length > 0 ? wa.accentText : wa.alpha(wa.fg, 0.5)
                                            font.family: wa.iconFont
                                            font.pixelSize: wa.fontSize + 1
                                        }
                                        MouseArea {
                                            id: sendHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wa.sendMessage()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -------- hints --------
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Type to filter chats  ·  Enter: open chat  ·  Tab: message box  ·  Enter: send  ·  Esc: close"
                font.family: wa.uiFont
                font.pixelSize: Math.max(10, wa.fontSize - 2)
                color: wa.alpha(wa.fg, 0.4)
            }
        }
    }
}