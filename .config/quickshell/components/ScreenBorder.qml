import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: ring
    required property var screen
    property color color: "#7393b3"
    property int thickness: 4
    property int radius: 24

    PanelWindow {
        screen: ring.screen
        color: "transparent"
        WlrLayershell.namespace: "ring-left"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.left: true
        anchors.top: true
        anchors.bottom: true
        margins.top: ring.radius
        margins.bottom: ring.radius
        implicitWidth: ring.thickness

        Rectangle {
            anchors.fill: parent
            color: ring.color
        }
    }

    PanelWindow {
        screen: ring.screen
        color: "transparent"
        WlrLayershell.namespace: "ring-right"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.right: true
        anchors.top: true
        anchors.bottom: true
        margins.top: ring.radius
        margins.bottom: ring.radius
        implicitWidth: ring.thickness

        Rectangle {
            anchors.fill: parent
            color: ring.color
        }
    }

    PanelWindow {
        screen: ring.screen
        color: "transparent"
        WlrLayershell.namespace: "ring-top"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        anchors.left: true
        anchors.right: true
        margins.left: ring.radius
        margins.right: ring.radius
        implicitHeight: ring.thickness

        Rectangle {
            anchors.fill: parent
            color: ring.color
        }
    }

    PanelWindow {
        screen: ring.screen
        color: "transparent"
        WlrLayershell.namespace: "ring-bottom"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        margins.left: ring.radius
        margins.right: ring.radius
        implicitHeight: ring.thickness

        Rectangle {
            anchors.fill: parent
            color: ring.color
        }
    }

    PanelWindow {
        screen: ring.screen
        color: "transparent"
        WlrLayershell.namespace: "ring-tl"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        anchors.left: true
        implicitWidth: ring.radius + ring.thickness + 2
        implicitHeight: ring.radius + ring.thickness + 2

        ArcDots {
            x: 0
            y: 0
            centerX: ring.radius
            centerY: ring.radius
            radius: ring.radius - ring.thickness / 2
            thickness: ring.thickness
            startAngle: 90
            color: ring.color
        }
    }

    PanelWindow {
        screen: ring.screen
        color: "transparent"
        WlrLayershell.namespace: "ring-tr"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        anchors.right: true
        implicitWidth: ring.radius + ring.thickness + 2
        implicitHeight: ring.radius + ring.thickness + 2

        ArcDots {
            x: 0
            y: 0
            centerX: ring.thickness + 2
            centerY: ring.radius
            radius: ring.radius - ring.thickness / 2
            thickness: ring.thickness
            startAngle: 0
            color: ring.color
        }
    }

    PanelWindow {
        screen: ring.screen
        color: "transparent"
        WlrLayershell.namespace: "ring-bl"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.bottom: true
        anchors.left: true
        implicitWidth: ring.radius + ring.thickness + 2
        implicitHeight: ring.radius + ring.thickness + 2

        ArcDots {
            x: 0
            y: 0
            centerX: ring.radius
            centerY: ring.thickness + 2
            radius: ring.radius - ring.thickness / 2
            thickness: ring.thickness
            startAngle: 180
            color: ring.color
        }
    }

    PanelWindow {
        screen: ring.screen
        color: "transparent"
        WlrLayershell.namespace: "ring-br"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.bottom: true
        anchors.right: true
        implicitWidth: ring.radius + ring.thickness + 2
        implicitHeight: ring.radius + ring.thickness + 2

        ArcDots {
            x: 0
            y: 0
            centerX: ring.thickness + 2
            centerY: ring.thickness + 2
            radius: ring.radius - ring.thickness / 2
            thickness: ring.thickness
            startAngle: 270
            color: ring.color
        }
    }
}