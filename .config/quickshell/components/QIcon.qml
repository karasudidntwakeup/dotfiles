import QtQuick
import Qt5Compat.GraphicalEffects

// Tinted SVG icon. SVGs in assets/icons/ are white; color tints them to
// whatever foreground the context needs.
Item {
    id: root

    property url source
    property color color: "#ffffff"
    property real iconSize: 16

    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: parent
        source: img
        color: root.color
        antialiasing: true
    }
}
