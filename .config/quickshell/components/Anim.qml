// Caelestia motion system (Material 3 Expressive).
// Mirrors caelestia-dots/shell `Anim`: spatial animations move things
// (position, size, scale), effects animate fades/alpha. Type picks both
// the duration and the easing curve so callers stay consistent.
import QtQuick

NumberAnimation {
    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects,
        Bouncy,
        BouncyFast
    }

    property int type: Anim.DefaultSpatial

    duration: {
        switch (type) {
        case Anim.StandardSmall: return 200
        case Anim.Standard: return 300
        case Anim.StandardLarge: return 400
        case Anim.StandardExtraLarge: return 500
        case Anim.EmphasizedSmall: return 200
        case Anim.Emphasized: return 400
        case Anim.EmphasizedLarge: return 500
        case Anim.EmphasizedExtraLarge: return 600
        case Anim.FastSpatial: return 350
        case Anim.DefaultSpatial: return 500
        case Anim.SlowSpatial: return 650
        case Anim.FastEffects: return 150
        case Anim.DefaultEffects: return 200
        case Anim.SlowEffects: return 300
        case Anim.Bouncy: return 550
        case Anim.BouncyFast: return 320
        default: return 300
        }
    }

    // Bouncy types overshoot (OutBack); everything else uses M3 beziers.
    easing.type: (type === Anim.Bouncy || type === Anim.BouncyFast) ? Easing.OutBack : Easing.Bezier
    easing.overshoot: type === Anim.BouncyFast ? 2.6 : 2.4
    easing.bezierCurve: {
        switch (type) {
        case Anim.EmphasizedSmall:
        case Anim.Emphasized:
        case Anim.EmphasizedLarge:
        case Anim.EmphasizedExtraLarge:
            return [0.05, 0.7, 0.1, 1.0]
        case Anim.FastSpatial:
            return [0.42, 1.67, 0.21, 0.9]
        case Anim.DefaultSpatial:
            return [0.38, 1.21, 0.22, 1.0]
        case Anim.SlowSpatial:
            return [0.39, 1.29, 0.35, 0.98]
        case Anim.FastEffects:
            return [0.31, 0.94, 0.34, 1.0]
        case Anim.DefaultEffects:
            return [0.34, 0.8, 0.34, 1.0]
        case Anim.SlowEffects:
            return [0.34, 0.88, 0.34, 1.0]
        default:
            return [0.2, 0.0, 0.0, 1.0]
        }
    }
}
