import QtQuick

Canvas {
    id: root

    property color color: "#00000000"
    property real radius: 8
    property real inset: 0
    property real darkFactor: 0.82

    anchors.fill: parent
    anchors.margins: inset

    function _paintPath(ctx) {
        var r = Math.max(0, Math.min(root.radius, Math.min(width / 2, height / 2)))
        ctx.beginPath()
        ctx.moveTo(r, 0)
        ctx.lineTo(width - r, 0)
        ctx.quadraticCurveTo(width, 0, width, r)
        ctx.lineTo(width, height - r)
        ctx.quadraticCurveTo(width, height, width - r, height)
        ctx.lineTo(r, height)
        ctx.quadraticCurveTo(0, height, 0, height - r)
        ctx.lineTo(0, r)
        ctx.quadraticCurveTo(0, 0, r, 0)
        ctx.closePath()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.save()
        _paintPath(ctx)
        ctx.clip()

        var c = root.color
        var left = Qt.rgba(c.r * root.darkFactor, c.g * root.darkFactor, c.b * root.darkFactor, c.a)

        var grad = ctx.createLinearGradient(0, 0, width, 0)
        grad.addColorStop(0, Qt.rgba(left.r, left.g, left.b, left.a).toString())
        grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, c.a).toString())
        ctx.fillStyle = grad
        ctx.fillRect(0, 0, width, height)
        ctx.restore()
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColorChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onInsetChanged: requestPaint()
    onDarkFactorChanged: requestPaint()
}
