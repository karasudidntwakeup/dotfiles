import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: card

    property var rootRef: null
    property var svc: null
    property var nData: null
    property string context: "popup"
    property bool selected: false

    signal cardSelected()

    readonly property int uid: nData && nData.uid !== undefined ? nData.uid : -1
    readonly property int urgency: nData && nData.urgency !== undefined ? nData.urgency : 1
    property var realNotif: (function() {
        if (svc && svc.liveNotifs && card.uid >= 0 && svc.liveNotifs[card.uid])
            return svc.liveNotifs[card.uid]
        return nData ? nData.notif : null
    })()
    property var actionArray: (function() {
        try {
            if (nData && nData.actionsJson) return JSON.parse(nData.actionsJson)
        } catch (e) {}
        return []
    })()

    readonly property bool isLight: rootRef ? rootRef.qsLight : false
    readonly property color cardColor: rootRef
        ? (isLight ? rootRef.pillColor("inverse_primary") : rootRef.colorOf("inverse_primary"))
        : "#f3dfd1"
    readonly property color borderColor: rootRef
        ? rootRef.withAlpha(rootRef.colorOf("widget_border"), isLight ? 0.5 : 0.35)
        : "#00000000"
    readonly property color errorColor: rootRef ? Qt.color(rootRef.colorOf("inverse_primary")) : "#dc4446"
    readonly property color fg: rootRef
        ? card.contrastColor(card.cardColor)
        : "#000000"
    readonly property color mute: rootRef ? rootRef.withAlpha(card.fg, 0.58) : "#666666"
    readonly property string iconFont: rootRef ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string uiFont: rootRef ? rootRef.uiFont : "Inter"
    readonly property string fontFamily: rootRef ? rootRef.fontFamily : "Ndot 57"
    readonly property int fontSize: rootRef ? rootRef.fontSize : 13

    readonly property bool isPopup: context === "popup"
    readonly property int pad: 14
    readonly property int badgeSize: isPopup ? 40 : 42
    readonly property string name: nData ? (nData.appName || "System") : ""

    readonly property string imgSrc: nData ? (nData.image || "") : ""
    readonly property string iconSrc: (function() {
        var name_ = nData ? (nData.iconName || "") : ""
        void card.iconTick
        if (name_.length === 0) return ""
        if (svc && svc.iconPathFor) return svc.iconPathFor(name_)
        if (name_.indexOf("://") !== -1 || name_.charAt(0) === "/") return name_
        return ""
    })()
    property int iconTick: 0
    property bool iconFailed: false
    onNDataChanged: { card.iconFailed = false; card.imageOk = false }
    Connections {
        target: card.svc
        function onIconPathsUpdated() { card.iconTick++ }
    }

    readonly property int ts: nData && nData.timestamp !== undefined ? nData.timestamp : Date.now()
    property string timeText: ""
    function fmtTime(t) {
        if (!t) return ""
        var now = new Date()
        var d = new Date(t)
        var sec = Math.floor((now.getTime() - d.getTime()) / 1000)
        var min = Math.floor(sec / 60)
        if (min < 1) return "now"
        if (min < 60) return min + "m ago"
        var sameDay = now.getFullYear() === d.getFullYear() &&
            now.getMonth() === d.getMonth() && now.getDate() === d.getDate()
        var hhmm = Qt.formatDateTime(d, "HH:mm")
        if (sameDay) return hhmm
        var yest = new Date(now)
        yest.setDate(now.getDate() - 1)
        if (yest.getFullYear() === d.getFullYear() &&
            yest.getMonth() === d.getMonth() && yest.getDate() === d.getDate())
            return "Yesterday " + hhmm
        if (min < 7 * 24 * 60) return Qt.formatDateTime(d, "dddd") + " " + hhmm
        return Qt.formatDateTime(d, "yyyy-MM-dd HH:mm")
    }
    function _lin(v: double): double {
        if (v <= 0.03928) return v / 12.92
        return Math.pow((v + 0.055) / 1.055, 2.4)
    }
    function relLum(c: color): double {
        return 0.2126 * card._lin(c.r) + 0.7152 * card._lin(c.g) + 0.0722 * card._lin(c.b)
    }
    function contrastColor(c: color): color {
        var l = card.relLum(c)
        var white = (1.05) / (l + 0.05)
        var black = (l + 0.05) / (0.05)
        return white >= black ? "#ffffff" : "#000000"
    }
    function refreshTime() { card.timeText = card.fmtTime(card.ts) }
    onTsChanged: card.refreshTime()

    Timer {
        interval: 15000
        repeat: true
        running: card.visible
        onTriggered: card.refreshTime()
    }

    readonly property int timeoutMs: (function() {
        if (card.urgency === 2) return 0
        var n = card.realNotif
        if (n) {
            var t = n.expireTimeout
            if (typeof t === "number") {
                if (t > 0) return t
                if (t === 0) return 0
            }
        }
        return 6000
    })()
    property bool hovering: false

    Timer {
        id: popTimer
        interval: card.timeoutMs
        running: card.isPopup && card.timeoutMs > 0 && card.visible &&
            !card.hovering && card.uid >= 0
        repeat: false
        onTriggered: {
            if (card.svc) card.svc.hidePopup(card.uid)
        }
    }

    function invokeAction(actionId) {
        var n = card.realNotif
        if (!n || !n.actions) return
        for (var i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier === actionId) {
                n.actions[i].invoke()
                break
            }
        }
    }

    function activate() {
        card.clickAction()
    }

    function clickAction() {
        var n = card.realNotif
        if (n && n.actions && n.actions.length > 0) {
            var target = null
            for (var i = 0; i < n.actions.length; i++)
                if (n.actions[i].identifier === "default") { target = n.actions[i]; break }
            if (!target) target = n.actions[0]
            if (target && typeof target.invoke === "function") {
                target.invoke()
                if (card.svc) card.svc.dismissNotif(card.uid)
            }
            return
        }
        if (card.svc) {
            card.svc.markRead(card.uid)
            if (card.isPopup) card.svc.hidePopup(card.uid)
        }
    }

    function actionGlyph(actionId, actionText) {
        var i = (actionId || "").toLowerCase()
        var t = (actionText || "").toLowerCase()
        if (i.indexOf("reply") !== -1 || t.indexOf("reply") !== -1) return "󱉁"
        if (i.indexOf("open") !== -1 || t.indexOf("open") !== -1) return "󰨞"
        if (i.indexOf("close") !== -1 || t.indexOf("close") !== -1 ||
            i.indexOf("dismiss") !== -1 || t.indexOf("dismiss") !== -1) return "󰅖"
        if (i.indexOf("default") !== -1) return "󰏚"
        if (i.indexOf("accept") !== -1 || t.indexOf("accept") !== -1 ||
            i.indexOf("join") !== -1 || t.indexOf("join") !== -1) return "󰄬"
        if (i.indexOf("decline") !== -1 || t.indexOf("decline") !== -1) return "󰅖"
        return "󰅂"
    }

    property real dragX: 0
    property bool dragging: false

    function dismissFlyOut() {
        flyOut.from = card.dragX
        flyOut.duration = 200
        flyOut.start()
    }

    NumberAnimation {
        id: flyOut
        target: card
        property: "dragX"
        easing.type: Easing.OutQuad
        onFinished: {
            if (card.svc && card.uid >= 0) card.svc.dismissNotif(card.uid)
        }
    }
    NumberAnimation {
        id: dragReset
        target: card
        property: "dragX"
        to: 0
        duration: 200
        easing.type: Easing.OutCubic
    }

    implicitHeight: cardBody.height

    scale: card.isPopup ? (card.hovering || card.dragging ? 1.01 : 1.0) : 1.0
    Behavior on scale {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    MultiEffect {
        id: cardBodyShadow
        visible: card.isPopup
        anchors.fill: cardBody
        source: cardBody
        transform: Translate { x: card.dragX }
        opacity: Math.max(0.0, 1.0 - Math.abs(card.dragX) / Math.max(1, card.width * 0.7))
        shadowEnabled: true
        shadowBlur: 0.75
        blurMax: 20
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 6
        shadowColor: Qt.rgba(0, 0, 0, 0.6)
        shadowOpacity: 0.4
    }

    Rectangle {
        id: cardBody
        width: parent.width
        height: cardContent.implicitHeight + card.pad * 2 + (card.imageOk ? card.imageBoxHeight + card.pad : 0)
        radius: 20
        color: card.cardColor
        border.width: card.urgency === 2 ? 1.5 : 1
        border.color: card.urgency === 2 ? card.errorColor : card.borderColor
        clip: true

        SurfaceGradient {
            anchors.fill: parent
            inset: card.urgency === 2 ? 1.5 : 1
            color: card.cardColor
            radius: 20
        }

        transform: Translate { x: card.dragX }
        opacity: Math.max(0.0, 1.0 - Math.abs(card.dragX) / Math.max(1, card.width * 0.7))

        Rectangle {
            anchors.fill: parent
            radius: card.urgency === 2 ? 18.5 : 19
            visible: cardArea.containsMouse && !cardArea.pressed && !card.dragging
            color: {
                if (!rootRef) return "transparent"
                return rootRef.withAlpha(card.fg, 0.045)
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: -1
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.5
            radius: card.urgency === 2 ? 18.5 : 0
            visible: card.urgency === 2
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(card.errorColor.r, card.errorColor.g, card.errorColor.b, 0.12) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Image {
            anchors.top: cardContent.bottom
            anchors.topMargin: card.pad
            anchors.left: parent.left
            anchors.right: parent.right
            height: card.imageBoxHeight
            visible: card.imageOk
            source: card.imgSrc
            fillMode: Image.PreserveAspectCrop
            clip: true
            onStatusChanged: {
                if (status === Image.Ready) card.imageOk = true
            }
        }

        ColumnLayout {
            id: cardContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: card.pad
            anchors.rightMargin: card.pad
            anchors.topMargin: card.pad
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 22
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: card.badgeSize
                    Layout.preferredHeight: card.badgeSize
                    Layout.alignment: Qt.AlignTop
                    radius: 12
                    color: rootRef ? rootRef.withAlpha(card.fg, 0.08) : "#dfdf00"
                    clip: true

                    Image {
                        id: iconImg
                        anchors.fill: parent
                        anchors.margins: 7
                        source: card.iconSrc
                        visible: card.iconSrc.length > 0 && !card.iconFailed
                        fillMode: Image.PreserveAspectFit
                        onStatusChanged: {
                            if (status === Image.Error) card.iconFailed = true
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: card.iconSrc.length === 0 || card.iconFailed
                        text: "󰁦"
                        color: card.fg
                        font.family: card.iconFont
                        font.pixelSize: card.fontSize + 3
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: card.name
                            color: card.mute
                            font.family: card.uiFont
                            font.pixelSize: card.fontSize - 2
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: nData ? (nData.summary || "") : ""
                        color: card.fg
                        font.family: card.fontFamily
                        font.pixelSize: card.fontSize + (card.isPopup ? 1 : 0)
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: nData && nData.body && nData.body.length > 0
                        text: nData ? (nData.body || "") : ""
                        color: card.mute
                        font.family: card.uiFont
                        font.pixelSize: card.fontSize - 1
                        wrapMode: Text.Wrap
                        maximumLineCount: card.isPopup ? 2 : 3
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                visible: card.actionArray.length > 0
                spacing: 6

                Item { Layout.fillWidth: true }

                Repeater {
                    model: card.actionArray

                    delegate: Rectangle {
                        required property var modelData
                        Layout.preferredHeight: 26
                        implicitWidth: actionLabel.implicitWidth + 18
                        radius: 7
                        color: actHover.containsMouse || actHover.pressed
                            ? rootRef.withAlpha(card.fg, 0.22)
                            : rootRef.withAlpha(card.fg, 0.1)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: modelData.text.length > 0
                                text: card.actionGlyph(modelData.id, modelData.text)
                                color: card.fg
                                font.family: card.iconFont
                                font.pixelSize: card.fontSize - 2
                            }

                            Text {
                                id: actionLabel
                                text: modelData.text
                                color: card.fg
                                font.family: card.uiFont
                                font.pixelSize: card.fontSize - 1
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: actHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (card.svc) card.svc.markRead(card.uid)
                                card.invokeAction(modelData.id)
                                if (card.svc) card.svc.dismissNotif(card.uid)
                            }
                        }
                    }
                }
            }
        }
    }

    readonly property int imageBoxHeight: card.isPopup ? 150 : 180
    property bool imageOk: false

    Rectangle {
        anchors.fill: parent
        radius: 20
        visible: card.selected
        color: "transparent"
        border.width: 2
        border.color: rootRef ? Qt.color(rootRef.colorOf("widget_accent")) : "#888888"
    }

    MouseArea {
        id: cardArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        property real pressX: 0

        onPressed: mouse => {
            cardArea.pressX = mouse.x
            card.dragging = false
            flyOut.stop()
            dragReset.stop()
        }
        onPositionChanged: mouse => {
            if (!pressed) return
            var dx = mouse.x - cardArea.pressX
            if (!card.dragging && Math.abs(dx) > 10) card.dragging = true
            if (card.dragging) card.dragX = dx
        }
        onReleased: {
            var wasDrag = card.dragging
            card.dragging = false
            if (wasDrag) {
                if (Math.abs(card.dragX) > card.width * 0.22) {
                    card.dismissFlyOut()
                } else {
                    dragReset.start()
                }
            } else {
                card.clickAction()
                card.cardSelected()
            }
        }
        onCanceled: {
            card.dragging = false
            dragReset.start()
        }
        onContainsMouseChanged: card.hovering = containsMouse
        onPressedChanged: card.hovering = containsMouse || pressed
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        z: 3
        width: 22
        height: 22
        radius: 11
        visible: card.isPopup ? (card.hovering || card.dragging) : true
        color: closeHover.containsMouse
            ? rootRef.withAlpha(card.fg, 0.22)
            : rootRef.withAlpha(card.fg, 0.06)
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "󰰩"
            color: card.fg
            font.family: card.iconFont
            font.pixelSize: card.fontSize - 2
        }

        MouseArea {
            id: closeHover
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (card.svc && card.uid >= 0) card.svc.dismissNotif(card.uid)
            }
        }
    }
}
