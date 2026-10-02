import QtQuick
import Quickshell

// Square icon button shared by the phone sheets (WhatsApp, YouTube).
// Icon names map to assets/icons/*.svg; unknown names fall back to close.
Item {
    id: btn
    property string icon: ""
    property color tint: "#ffffff"
    property int iconSize: 16
    property bool enabled: true
    signal clicked()

    implicitWidth: 34
    implicitHeight: 34
    opacity: btn.enabled ? 1 : 0.4

    QIcon {
        anchors.centerIn: parent
        source: btn.icon === "back" ? Qt.resolvedUrl("../assets/icons/chev-left.svg")
            : btn.icon === "refresh" ? Qt.resolvedUrl("../assets/icons/refresh.svg")
            : btn.icon === "clip" ? Qt.resolvedUrl("../assets/icons/clipboard.svg")
            : btn.icon === "photo" ? Qt.resolvedUrl("../assets/icons/photo.svg")
            : Qt.resolvedUrl("../assets/icons/close.svg")
        color: btn.tint
        iconSize: btn.iconSize
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: btn.enabled
        onClicked: btn.clicked()
    }
}