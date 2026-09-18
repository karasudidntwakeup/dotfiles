// Caelestia color motion: same effects curves as Anim, for colors.
import QtQuick

ColorAnimation {
    enum Type {
        FastEffects = 0,
        DefaultEffects,
        SlowEffects
    }

    property int type: CAnim.DefaultEffects

    duration: {
        switch (type) {
        case CAnim.FastEffects: return 150
        case CAnim.SlowEffects: return 300
        default: return 200
        }
    }

    easing.type: Easing.Bezier
    easing.bezierCurve: {
        switch (type) {
        case CAnim.FastEffects:
            return [0.31, 0.94, 0.34, 1.0]
        case CAnim.SlowEffects:
            return [0.34, 0.88, 0.34, 1.0]
        default:
            return [0.34, 0.8, 0.34, 1.0]
        }
    }
}
