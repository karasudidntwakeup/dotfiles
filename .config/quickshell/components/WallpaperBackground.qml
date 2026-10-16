import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// QS-native wallpaper background, one instance per screen (via Variants).
// Reads current.txt + transition.txt from the wallpaper cache dir and
// crossfades/slides/scales the new image in.
//
// transition.txt names mirror WallpaperPicker.transitionModel.
// Durations mirror wallpaper_apply.sh so the picker labels stay truthful.
// Wave/ripple sine displacement is approximated as a directional reveal +
// fade (a true GPU wave would need a ShaderEffect pass).
PanelWindow {
    id: bg
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "qs-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "black"

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell/wallpaper"

    // Displayed image (file:// URL). Front/back pair enables crossfade.
    property string shown: ""
    property string backSrc: ""
    property string frontSrc: ""
    property bool firstLoad: true
    // Transition state for the incoming front image.
    property string fx: "fade"
    property int fxDur: 600
    property real frontOp: 0
    property real frontX: 0
    property real frontY: 0
    property real frontScale: 1

    function isGif(p) {
        return String(p || "").toLowerCase().endsWith(".gif")
    }

    // Duration table mirrors wallpaper_apply.sh TRANSITION_PRESET map.
    function durFor(name) {
        switch (name) {
        case "none": return 0
        case "simple": return 300
        case "fade-fast": return 400
        case "fade-slow": return 1500
        case "fade": return 600
        case "wipe": return 700
        case "wipe-h": return 700
        case "wipe-v": return 700
        case "wipe-diag": return 700
        case "wave": return 800
        case "wave-big": return 900
        case "wave-steep": return 800
        case "slide-left": return 600
        case "slide-right": return 600
        case "slide-up": return 600
        case "slide-down": return 600
        case "grow": return 800
        case "grow-corner": return 800
        case "grow-top": return 800
        case "iris": return 800
        case "any": return 800
        case "implode": return 800
        case "ripple": return 900
        default: return 600
        }
    }

    function showWallpaper(path, transition) {
        var p = String(path || "").trim()
        if (p.length === 0) return
        var url = (p.indexOf("file://") === 0) ? p : "file://" + p
        if (url === bg.shown && !bg.firstLoad) return
        var t = String(transition || bg.fx || "fade").trim().split(/\s+/)[0] || "fade"
        if (bg.firstLoad) {
            // Instant on session start: no flash of black, no anim.
            bg.fx = t
            bg.backSrc = url
            bg.frontSrc = ""
            bg.shown = url
            bg.firstLoad = false
            return
        }
        bg.fx = t
        bg.fxDur = durFor(t)
        if (bg.fxDur <= 0) {
            bg.backSrc = url
            bg.frontSrc = ""
            bg.shown = url
            return
        }
        bg.backSrc = bg.shown
        bg.frontSrc = url
        setupFront()
        // Restart from the next tick so source/binding propagation settles
        // before the animation runs (same pattern as the pickers).
        anim.running = false
        Qt.callLater(function () { anim.running = true })
    }

    function setupFront() {
        var W = bg.width
        var H = bg.height
        // Defaults: centered crossfade.
        bg.frontOp = 0
        bg.frontX = 0
        bg.frontY = 0
        bg.frontScale = 1
        frontItem.transformOrigin = Item.Center
        switch (bg.fx) {
        case "simple":
        case "fade":
        case "fade-fast":
        case "fade-slow":
            break
        case "slide-left": // new slides in from the left
            bg.frontX = -W
            break
        case "slide-right": // new slides in from the right
            bg.frontX = W
            break
        case "slide-up": // hint: "slide from top"
            bg.frontY = -H
            break
        case "slide-down": // hint: "slide from bottom"
            bg.frontY = H
            break
        case "wipe-h":
            bg.frontX = W
            break
        case "wipe-v":
            bg.frontY = H
            break
        case "wipe":
            bg.frontX = -W * 0.5
            bg.frontY = -H * 0.5
            break
        case "wipe-diag":
            bg.frontX = W * 0.5
            bg.frontY = -H * 0.5
            break
        case "wave":
        case "wave-big":
        case "wave-steep":
            // APPROX: sine-wave pixel displacement would need a
            // ShaderEffect; this is a diagonal reveal + fade.
            // Same duration, same direction family.
            bg.frontX = -W * 0.4
            bg.frontY = -H * 0.25
            break
        case "grow":
            bg.frontScale = 0.3
            break
        case "grow-corner":
            bg.frontScale = 0.3
            frontItem.transformOrigin = Item.BottomRight
            break
        case "grow-top":
            bg.frontScale = 0.3
            frontItem.transformOrigin = Item.Top
            break
        case "iris":
        case "center":
            bg.frontScale = 0.2
            break
        case "any":
            bg.frontScale = 0.2
            // Deterministic pseudo-random origin from path length so the
            // "anywhere" preset varies without extra state.
            var origins = [Item.TopLeft, Item.TopRight, Item.BottomLeft, Item.BottomRight, Item.Center]
            frontItem.transformOrigin = origins[bg.frontSrc.length % origins.length]
            break
        case "implode":
        case "outer":
            bg.frontScale = 1.4
            break
        case "ripple":
            // Anchored at bottom-left (matches the picker preset map).
            bg.frontScale = 1.4
            frontItem.transformOrigin = Item.BottomLeft
            break
        case "left":
            bg.frontX = -W
            break
        case "right":
            bg.frontX = W
            break
        case "top":
            bg.frontY = -H
            break
        case "bottom":
            bg.frontY = H
            break
        default:
            break
        }
    }

    // Back (old) image, static.
    Image {
        id: backImg
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        source: bg.backSrc
        visible: bg.backSrc !== ""
    }
    // Animated back for gifs.
    AnimatedImage {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        source: bg.isGif(bg.backSrc) ? bg.backSrc : ""
        visible: bg.isGif(bg.backSrc)
        playing: visible
    }

    // Front (incoming) container: position/scale/opacity animated.
    Item {
        id: frontItem
        anchors.fill: parent
        opacity: bg.frontOp
        // Static front.
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            source: (!bg.isGif(bg.frontSrc)) ? bg.frontSrc : ""
            visible: bg.frontSrc !== "" && !bg.isGif(bg.frontSrc)
        }
        // Animated front for gifs.
        AnimatedImage {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            source: bg.isGif(bg.frontSrc) ? bg.frontSrc : ""
            visible: bg.frontSrc !== "" && bg.isGif(bg.frontSrc)
            playing: visible
        }
    }

    ParallelAnimation {
        id: anim
        running: false
        NumberAnimation { target: bg; property: "frontOp"; to: 1; duration: bg.fxDur; easing.type: Easing.InOutQuad }
        NumberAnimation { target: bg; property: "frontX"; to: 0; duration: bg.fxDur; easing.type: Easing.InOutQuad }
        NumberAnimation { target: bg; property: "frontY"; to: 0; duration: bg.fxDur; easing.type: Easing.InOutQuad }
        NumberAnimation { target: bg; property: "frontScale"; to: 1; duration: bg.fxDur; easing.type: Easing.OutQuad }
        onFinished: {
            bg.backSrc = bg.frontSrc
            bg.shown = bg.frontSrc
            bg.frontSrc = ""
            bg.frontOp = 0
            bg.frontX = 0
            bg.frontY = 0
            bg.frontScale = 1
        }
    }

    // Bind animated geometry to the container.
    Binding { target: frontItem; property: "x"; value: bg.frontX }
    Binding { target: frontItem; property: "y"; value: bg.frontY }
    Binding { target: frontItem; property: "scale"; value: bg.frontScale }

    FileView {
        id: curFile
        path: bg.cacheDir + "/current.txt"
        watchChanges: true
        blockLoading: true
        onFileChanged: curFile.reload()
        onLoaded: bg.showWallpaper(String(curFile.text()).trim(), transFile.preset)
        onLoadFailed: error => console.log("[wallpaper] current.txt:", error)
    }

    FileView {
        id: transFile
        // NOTE: named `preset`, not `text` — FileView already has text().
        property string preset: "fade"
        path: bg.cacheDir + "/transition.txt"
        watchChanges: true
        blockLoading: true
        onFileChanged: transFile.reload()
        onLoaded: {
            var t = String(transFile.text() || "").trim().split(/\s+/)[0] || "fade"
            transFile.preset = t
            bg.fx = t
        }
        onLoadFailed: { transFile.preset = "fade"; bg.fx = "fade" }
    }

    Component.onCompleted: {
        curFile.reload()
        transFile.reload()
    }
}
