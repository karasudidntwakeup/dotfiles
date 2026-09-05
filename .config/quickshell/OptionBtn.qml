import QtQuick

// A toggle button used in the wallpaper apply dialog (mode + scheme rows).
Item {
    id: btn
    property string label: ""
    property bool active: false
    property color fgColor: "#ffffff"
    property color borderColor: "#303136"
    property color accentColor: "#96c8f6"

    signal activate()

    width: 96
    height: 34

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: btn.active ? btn.accentColor
              : (hover.containsMouse ? Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.12) : "transparent")
        border.color: btn.active ? btn.accentColor : btn.borderColor
        border.width: 1
        scale: btn.active ? 1.0 : (hover.containsMouse ? 1.03 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btn.active ? "#000000" : btn.fgColor
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: btn.active ? Font.Bold : Font.Normal
            elide: Text.ElideRight
            width: parent.width - 12
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.activate()
    }
}
