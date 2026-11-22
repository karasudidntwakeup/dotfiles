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

    property string requestedSource: ""
    property string requestedEffect: "fade"
    property WallpaperLayer currentLayer: layerA
    readonly property WallpaperLayer incomingLayer: currentLayer === layerA ? layerB : layerA

    // Transition state for the incoming front image.
    property string fx: "fade"
    property int fxDur: 600
    property real frontOp: 0
    property real frontX: 0
    property real frontY: 0
    property real frontScale: 1

    function isGif(p) {
        return String(p || "").toLowerCase().split(/[?#]/)[0].endsWith(".gif")
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
        bg.requestedSource = p.startsWith("file://") ? p : "file://" + p.split("/").map(encodeURIComponent).join("/")
        bg.requestedEffect = String(transition || "fade").trim().split(/\s+/)[0] || "fade"
        Qt.callLater(bg.updateWallpaper)
    }

    function updateWallpaper() {
        if (anim.running || !bg.requestedSource) return

        var incoming = bg.incomingLayer
        if (bg.requestedSource === bg.currentLayer.imageSource) {
            incoming.imageSource = ""
            return
        }

        if (incoming.imageSource !== bg.requestedSource) {
            incoming.imageSource = bg.requestedSource
            // Let the image source bindings update before checking status.
            Qt.callLater(bg.updateWallpaper)
            return
        }
        if (incoming.loadStatus !== Image.Ready) return

        bg.fx = bg.requestedEffect
        bg.fxDur = durFor(bg.fx)
        if (!bg.currentLayer.imageSource || bg.fxDur === 0) {
            finishWallpaper()
            return
        }

        setupFront()
        anim.start()
    }

    function finishWallpaper() {
        var previous = bg.currentLayer
        bg.currentLayer = bg.incomingLayer
        previous.imageSource = ""
        bg.frontOp = 0
        Qt.callLater(bg.updateWallpaper)
    }

    function setupFront() {
        var W = bg.width
        var H = bg.height
        // Defaults: centered crossfade.
        bg.frontOp = 0
        bg.frontX = 0
        bg.frontY = 0
        bg.frontScale = 1
        bg.incomingLayer.transformOrigin = Item.Center
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
            bg.incomingLayer.transformOrigin = Item.BottomRight
            break
        case "grow-top":
            bg.frontScale = 0.3
            bg.incomingLayer.transformOrigin = Item.Top
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
            bg.incomingLayer.transformOrigin = origins[bg.incomingLayer.imageSource.length % origins.length]
            break
        case "implode":
        case "outer":
            bg.frontScale = 1.4
            break
        case "ripple":
            // Anchored at bottom-left (matches the picker preset map).
            bg.frontScale = 1.4
            bg.incomingLayer.transformOrigin = Item.BottomLeft
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

    // Keep the decoded image in its own layer when it becomes the wallpaper.
    component WallpaperLayer: Item {
        id: wallpaperLayer
        property string imageSource: ""
        readonly property bool animated: bg.isGif(imageSource)
        readonly property int loadStatus: animated ? animatedImage.status : stillImage.status
        readonly property bool current: bg.currentLayer === wallpaperLayer

        width: parent.width
        height: parent.height
        z: current ? 0 : 1
        opacity: current ? 1 : bg.frontOp
        x: current ? 0 : bg.frontX
        y: current ? 0 : bg.frontY
        scale: current ? 1 : bg.frontScale

        onLoadStatusChanged: Qt.callLater(bg.updateWallpaper)

        Image {
            id: stillImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: wallpaperLayer.animated ? "" : wallpaperLayer.imageSource
        }

        AnimatedImage {
            id: animatedImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: wallpaperLayer.animated ? wallpaperLayer.imageSource : ""
            playing: wallpaperLayer.current || anim.running
        }
    }

    WallpaperLayer { id: layerA }
    WallpaperLayer { id: layerB }

    ParallelAnimation {
        id: anim
        running: false
        NumberAnimation { target: bg; property: "frontOp"; to: 1; duration: bg.fxDur; easing.type: Easing.InOutQuad }
        NumberAnimation { target: bg; property: "frontX"; to: 0; duration: bg.fxDur; easing.type: Easing.InOutQuad }
        NumberAnimation { target: bg; property: "frontY"; to: 0; duration: bg.fxDur; easing.type: Easing.InOutQuad }
        NumberAnimation { target: bg; property: "frontScale"; to: 1; duration: bg.fxDur; easing.type: Easing.OutQuad }
        onFinished: bg.finishWallpaper()
    }

    FileView {
        id: curFile
        path: bg.cacheDir + "/current.txt"
        watchChanges: true
        blockLoading: true
        onFileChanged: curFile.reload()
        onLoaded: {
            transFile.wallpaperPath = curFile.text()
            transFile.reload()
        }
        onLoadFailed: error => console.log("[wallpaper] current.txt:", error)
    }

    FileView {
        id: transFile
        property string wallpaperPath: ""
        path: bg.cacheDir + "/transition.txt"
        blockLoading: true
        onLoaded: bg.showWallpaper(wallpaperPath, transFile.text())
        onLoadFailed: bg.showWallpaper(wallpaperPath, "fade")
    }
}
