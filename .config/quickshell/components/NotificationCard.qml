import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell

Item {
    id: card

    property var rootRef: null
    property var svc: null
    property var nData: null
    property string context: "popup"

    signal cardSelected()

    readonly property int uid: nData && nData.uid !== undefined ? nData.uid : -1
    property var realNotif: (function() {
        if (svc && svc.liveNotifs && card.uid >= 0 && svc.liveNotifs[card.uid])
            return svc.liveNotifs[card.uid]
        return null
    })()
    property var actionArray: (function() {
        try {
            if (nData && nData.actionsJson) return JSON.parse(nData.actionsJson)
        } catch (e) {}
        return []
    })()

    readonly property color cardColor: rootRef
        ? rootRef.pillColor("surface_container_highest")
        : "#f3dfd1"
    // Same hairline as the panel's own cards (weather, storage rows): a light
    // wash of the card's own text colour rather than a themed border token.
    readonly property color borderColor: rootRef
        ? rootRef.withAlpha(card.fg, 0.09)
        : "#00000000"
    readonly property color fg: rootRef
        ? rootRef.contrastColor(card.cardColor)
        : "#000000"
    readonly property color mute: rootRef ? rootRef.withAlpha(card.fg, 0.72) : "#666666"
    readonly property string iconFont: rootRef ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string uiFont: rootRef && rootRef.uiFont ? rootRef.uiFont : "Geist"
    readonly property int fontSize: rootRef ? rootRef.fontSize : 13

    readonly property bool isPopup: context === "popup"
    readonly property int pad: 12
    // A card is drawn the same in a popup and in the center, so a toast and
    // the entry it leaves behind are identical. isPopup now only drives
    // behaviour: auto-dismiss, and the close button appearing on hover.
    readonly property int badgeSize: 30
    readonly property string name: nData ? (nData.appName || "System") : ""
    // OpenCode / herdr notifications get a Y2K star badge instead of the generic app icon.
    readonly property bool isOpenCode: {
        var n = card.name.toLowerCase()
        return n.indexOf("opencode") !== -1 || n.indexOf("herdr") !== -1
    }

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

    readonly property int timeoutMs: (function() {
        // No special-casing: critical notifications auto-dismiss like any
        // other instead of sticking on screen with a red border.
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
    readonly property bool hovering: cardHover.hovered || cardArea.pressed

    HoverHandler { id: cardHover }

    Timer {
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
        if (i.indexOf("reply") !== -1 || t.indexOf("reply") !== -1) return "󰑚"
        if (i.indexOf("open") !== -1 || t.indexOf("open") !== -1) return "󰏌"
        if (i.indexOf("close") !== -1 || t.indexOf("close") !== -1 ||
            i.indexOf("dismiss") !== -1 || t.indexOf("dismiss") !== -1) return "󰅖"
        if (i.indexOf("default") !== -1) return "󰗡"
        if (i.indexOf("accept") !== -1 || t.indexOf("accept") !== -1 ||
            i.indexOf("join") !== -1 || t.indexOf("join") !== -1) return "󰄬"
        if (i.indexOf("decline") !== -1 || t.indexOf("decline") !== -1) return "󰅖"
        return "󰅂"
    }

    property real dragX: 0
    property bool dragging: false

    function dismissFlyOut() {
        flyOut.from = card.dragX
        flyOut.to = (card.dragX < 0 ? -1 : 1) * card.width
        flyOut.duration = 140
        flyOut.start()
    }

    Anim {
        id: flyOut
        target: card
        property: "dragX"
        type: Anim.BouncyFast
        onFinished: {
            if (card.svc && card.uid >= 0) card.svc.dismissNotif(card.uid)
        }
    }
    Anim {
        id: dragReset
        target: card
        property: "dragX"
        to: 0
        type: Anim.BouncyFast
    }

    implicitHeight: cardBody.height

    Item {
        anchors.fill: parent
        transform: Translate { x: card.dragX }
        opacity: Math.max(0.0, 1.0 - Math.abs(card.dragX) / Math.max(1, card.width * 0.7))
        // Shadow lives here (unclipped wrapper) rather than on cardBody:
        // cardBody needs clip:true for its rounded corners, which would cut
        // the shadow off on the same item. Popups only — a toast floats over
        // the wallpaper and needs the separation, while a card inside the
        // center sits on the panel and renders flat.
        layer.enabled: card.isPopup
        layer.effect: MultiEffect {
            shadowEnabled: card.isPopup && Quickshell.env("QS_NO_SHADOW") !== "1"
            shadowBlur: 0.8
            blurMax: 20
            shadowHorizontalOffset: 4
            shadowVerticalOffset: 8
            shadowColor: Qt.rgba(0, 0, 0, 0.9)
            shadowOpacity: 0.9
        }

        Rectangle {
            id: cardBody
            anchors.left: parent.left
            anchors.right: parent.right
            height: cardContent.implicitHeight + card.pad * 2 + (card.imageOk ? card.imageBoxHeight + card.pad : 0)
            radius: 8
            color: card.cardColor
            border.width: 1
            border.color: card.borderColor
            clip: true


        Rectangle {
            anchors.fill: parent
            radius: cardBody.radius
            visible: cardArea.containsMouse && !cardArea.pressed && !card.dragging
            color: {
                if (!rootRef) return "transparent"
                return rootRef.withAlpha(card.fg, 0.045)
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
                Layout.rightMargin: 30
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: card.badgeSize
                    Layout.preferredHeight: card.badgeSize
                    Layout.alignment: Qt.AlignTop
                    radius: 8
                    color: rootRef ? rootRef.withAlpha(card.fg, 0.08) : "#dfdf00"
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 5
                        source: card.iconSrc
                        visible: card.iconSrc.length > 0 && !card.iconFailed
                        fillMode: Image.PreserveAspectFit
                        onStatusChanged: {
                            if (status === Image.Error) card.iconFailed = true
                        }
                    }

                    QIcon {
                        anchors.centerIn: parent
                        visible: card.iconSrc.length === 0 || card.iconFailed
                        source: card.isOpenCode
                            ? Qt.resolvedUrl("../assets/icons/y2k-star-4.svg")
                            : Qt.resolvedUrl("../assets/icons/app.svg")
                        color: card.fg
                        iconSize: card.fontSize + 1
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 3

                    // App name and headline share one line, the way the
                    // weather card puts its reading and its label together.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.maximumWidth: 120
                            text: card.name
                            color: card.mute
                            font.family: card.uiFont
                            font.pixelSize: card.fontSize - 2
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: nData ? (nData.summary || "") : ""
                            color: card.fg
                            font.family: card.uiFont
                            font.pixelSize: card.fontSize
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        // Coerced: a bare && chain yields undefined, not false,
                        // when nData is still unset, which warns on a bool.
                        visible: !!(nData && nData.body && nData.body.length > 0)
                        text: nData ? (nData.body || "") : ""
                        color: card.mute
                        font.family: card.uiFont
                        font.pixelSize: card.fontSize - 3
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
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
                        Layout.preferredHeight: 24
                        implicitWidth: actionRow.implicitWidth + 20
                        radius: 8
                        color: actHover.containsMouse || actHover.pressed
                            ? rootRef.withAlpha(card.fg, 0.1)
                            : Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.02)
                        border.width: 1
                        border.color: actHover.containsMouse || actHover.pressed
                            ? rootRef.withAlpha(card.fg, 0.28)
                            : rootRef.withAlpha(card.fg, 0.16)
                        Behavior on color { CAnim { type: CAnim.FastEffects } }

                        Row {
                            id: actionRow
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
                                text: modelData.text.toUpperCase()
                                color: card.fg
                                font.family: card.uiFont
                                font.pixelSize: card.fontSize - 2
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.5
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
    }

    readonly property int imageBoxHeight: 180
    property bool imageOk: false

    MouseArea {
        id: cardArea
        anchors.fill: parent
        z: -1
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
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        z: 3
        width: 20
        height: 20
        radius: 8
        visible: card.isPopup ? (card.hovering || card.dragging) : true
        color: closeHover.containsMouse
            ? rootRef.withAlpha(card.fg, 0.22)
            : rootRef.withAlpha(card.fg, 0.06)
        Behavior on color { CAnim { type: CAnim.FastEffects } }

        QIcon {
            anchors.centerIn: parent
            source: Qt.resolvedUrl("../assets/icons/close.svg")
            color: card.fg
            iconSize: card.fontSize
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
