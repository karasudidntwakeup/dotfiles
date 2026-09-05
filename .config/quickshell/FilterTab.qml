import QtQuick

// A single filter tab for the wallpaper picker: either a color circle or a
// labeled button (used for the "All" tab).
Item {
    id: tab
    property string label: ""
    property string colorCircle: ""
    property bool custom: false
    property string icon: ""
    property bool active: false
    property color fgColor: "#ffffff"
    property color borderColor: "#303136"
    property string uiFont: "Inter"
    property string iconFont: "Symbols Nerd Font"

    signal activate()

    width: 34
    height: 34
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: colorCircle !== "" ? colorCircle
             : active ? tabActiveBg : (tabHover.containsMouse ? tabHoverBg : tabInactiveBg)
        border.color: active ? tab.fgColor : tab.borderColor
        border.width: active ? 1.5 : 1
        scale: active ? 1.05 : (tabHover.containsMouse ? 1.03 : 1.0)
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        // Icon for the "All" tab.
        Text {
            visible: tab.custom
            anchors.centerIn: parent
            text: tab.icon
            color: tab.fgColor
            font.family: tab.iconFont
            font.pixelSize: 14
        }

        // Label for non-color, non-custom tabs.
        Text {
            visible: !tab.custom && tab.colorCircle === "" && tab.label !== ""
            anchors.centerIn: parent
            text: tab.label
            color: tab.fgColor
            font.family: tab.uiFont
            font.pixelSize: 12
            font.weight: tab.active ? Font.Bold : Font.Normal
        }
    }

    readonly property color tabActiveBg: "#d0d0d0"
    readonly property color tabInactiveBg: "#333333"
    readonly property color tabHoverBg: "#4a4a4a"

    MouseArea {
        id: tabHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tab.activate()
    }
}
