import QtQuick

Item {
    id: arc
    property real centerX: 0
    property real centerY: 0
    property real radius: 24
    property int thickness: 3
    property int count: 16
    property real startAngle: 0
    property color color: "#7393b3"

    Repeater {
        model: arc.count
        delegate: Rectangle {
            readonly property real a: (arc.startAngle + index * 90 / Math.max(1, arc.count - 1)) * Math.PI / 180
            x: arc.centerX + (arc.radius - arc.thickness / 2) * Math.cos(a) - arc.thickness / 2
            y: arc.centerY - (arc.radius - arc.thickness / 2) * Math.sin(a) - arc.thickness / 2
            width: arc.thickness
            height: arc.thickness
            color: arc.color
        }
    }
}