import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: center

    property var rootRef: null
    property var svc: null

    focus: svc ? svc.centerOpen : false

    readonly property int panelWidth: 400
    readonly property int pad: 12
    readonly property color panelColor: "#15161a"
    readonly property color panelBorder: rootRef ? Qt.color(rootRef.colorOf("outline_variant")) : "#ffffff33"
    readonly property color fg: "#ffffff"
    readonly property color muteFg: Qt.rgba(1, 1, 1, 0.55)
    readonly property color accent: rootRef ? Qt.color(rootRef.colorOf("primary")) : "#ff8fb2"
    readonly property string iconFont: rootRef ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string uiFont: rootRef ? rootRef.uiFont : "Inter"
    readonly property string fontFamily: rootRef ? rootRef.fontFamily : "Ndot 57"
    readonly property int fontSize: rootRef ? rootRef.fontSize : 13

    property real animProgress: svc && svc.centerOpen ? 1.0 : 0.0
    Behavior on animProgress {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    Keys.onEscapePressed: event => {
        if (svc) svc.closeCenter()
        event.accepted = true
    }
    Keys.onDownPressed: event => {
        if (centerList.count > 0) centerList.incrementCurrentIndex()
        event.accepted = true
    }
    Keys.onUpPressed: event => {
        if (centerList.count > 0) centerList.decrementCurrentIndex()
        event.accepted = true
    }
    Keys.onReturnPressed: event => {
        var current = centerList.currentItem
        if (current && typeof current.activate === "function") current.activate()
        event.accepted = true
    }

    // Clicking anywhere outside the panel dismisses the center.
    MouseArea {
        id: backdropArea
        anchors.fill: parent
        onClicked: { if (svc) svc.closeCenter() }
    }

    // Panel
    Rectangle {
        id: panel
        width: center.panelWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        anchors.rightMargin: 10
        color: center.panelColor
        radius: 22
        border.width: 1
        border.color: center.panelBorder
        clip: true

        // Panel is fully opaque; the backdrop below never tints this sheet.
        transform: Translate { x: (1.0 - center.animProgress) * (center.panelWidth + 48) }
        scale: 0.98 + 0.02 * center.animProgress
        transformOrigin: Item.Right

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: center.pad
            anchors.rightMargin: center.pad
            anchors.topMargin: center.pad
            anchors.bottomMargin: center.pad
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 8

                Text {
                    text: "󰁦"
                    color: center.fg
                    font.family: center.iconFont
                    font.pixelSize: center.fontSize + 3
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 30
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text: "Notifications"
                    color: center.fg
                    font.family: center.fontFamily
                    font.pixelSize: center.fontSize + 2
                    font.weight: Font.Black
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    visible: svc && svc.unreadCount > 0
                    Layout.preferredHeight: 20
                    implicitWidth: unreadLabel.implicitWidth + 12
                    radius: 10
                    color: center.accent

                    Text {
                        id: unreadLabel
                        anchors.centerIn: parent
                        text: svc ? String(svc.unreadCount) : ""
                        color: "#15161a"
                        font.family: center.fontFamily
                        font.pixelSize: center.fontSize - 2
                        font.weight: Font.Black
                    }
                }

                HeaderBtn {
                    glyph: svc && svc.dnd ? "󰼓" : "󰋲"
                    active: svc ? svc.dnd : false
                    onTapped: { if (svc) svc.dnd = !svc.dnd }
                }

                HeaderBtn {
                    glyph: "󰩈"
                    enabled_: svc && svc.history.count > 0
                    active: false
                    onTapped: { if (svc) svc.clearAll() }
                }
            }

            // History list
            ListView {
                id: centerList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: svc ? svc.history : []
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    width: 3
                    policy: ScrollBar.AsNeeded
                    background: Item {}
                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: 1.5
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }

                onCountChanged: {
                    if (centerList.count === 0) centerList.currentIndex = -1
                    else if (centerList.currentIndex >= centerList.count)
                        centerList.currentIndex = centerList.count - 1
                }

                Component.onCompleted: {
                    if (centerList.count > 0) centerList.currentIndex = 0
                }

                delegate: NotificationCard {
                    width: centerList.width
                    rootRef: center.rootRef
                    svc: center.svc
                    nData: model
                    context: "center"
                    selected: centerList.currentIndex === index
                    z: centerList.currentIndex === index ? 2 : 1
                    onCardSelected: centerList.currentIndex = index
                }
            }

            // Empty state
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: svc && svc.history.count === 0

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -24
                    text: "󰁦"
                    color: center.muteFg
                    font.family: center.iconFont
                    font.pixelSize: 34
                }
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 22
                    text: "No notifications"
                    color: center.muteFg
                    font.family: center.uiFont
                    font.pixelSize: center.fontSize - 1
                }
            }
        }
    }

    // Small header button
    component HeaderBtn: Item {
        id: btn
        property string glyph: ""
        property bool active: false
        property bool enabled_: true
        signal tapped()

        Layout.preferredWidth: 30
        Layout.preferredHeight: 30

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: !btn.enabled_
                ? Qt.rgba(1, 1, 1, 0.04)
                : btn.active
                    ? Qt.rgba(center.accent.r, center.accent.g, center.accent.b, 0.35)
                    : (hoverArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: !btn.enabled_ ? Qt.rgba(1, 1, 1, 0.25) : center.fg
            font.family: center.iconFont
            font.pixelSize: center.fontSize
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            enabled: btn.enabled_
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.tapped()
        }
    }
}