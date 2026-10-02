import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Item {
    id: window

    readonly property string scriptDir: Quickshell.shellDir + "/scripts"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell/wallpaper"
    readonly property string srcDir: Quickshell.env("HOME") + "/wallpaper"

    property string currentFilter: "All"
    property var wallpaperModel: []
    property var displayModel: []
    property bool isApplying: false
    property bool isLoaded: false

    signal requestClose()
    property bool visible_: false
    // No open/close animation: the picker snaps in/out instantly.
    // (Behaviors on progress properties kept the PanelWindow alive for
    // the outro; without them visible_ toggles apply immediately.)
    property real animProgress: visible_ ? 1.0 : 0.0
    property real fadeProgress: visible_ ? 1.0 : 0.0
    opacity: fadeProgress
    property string currentPath: ""

    property color surfaceColor: "#101013"
    property color borderColor: "#2b2b30"
    property color fgColor: "#ffffff"
    property color accentColor: "#FF3030"
    property string uiFont: "Geist"
    property string iconFont: "Symbols Nerd Font"

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function brighten(c, f) {
        return Qt.rgba(Math.min(1, c.r * f), Math.min(1, c.g * f), Math.min(1, c.b * f), 1)
    }
    readonly property color baseColor: withAlpha(surfaceColor, 0.90)
    readonly property color surface0: surfaceColor
    readonly property color surface1: brighten(surfaceColor, 1.18)
    readonly property color surface2: brighten(surfaceColor, 1.45)
    readonly property color textColor: fgColor
    readonly property color subtextColor: withAlpha(fgColor, 0.55)
    readonly property color blue: accentColor

    readonly property real u: Screen.height >= 1400 ? 1.0 : 0.85
    readonly property real itemWidth: 400 * u
    readonly property real itemHeight: 420 * u
    readonly property real borderWidth: 3 * u
    readonly property real spacing: 10 * u
    readonly property real skewFactor: -0.35
    readonly property real cornerRadius: 10
    readonly property real selectedCenterOffset: (window.skewFactor * window.itemHeight) / 2

    readonly property var filterData: [
        { name: "All", hex: "" },
        { name: "Red", hex: "#E60000" },
        { name: "Maroon", hex: "#800000" },
        { name: "Orange", hex: "#FFA500" },
        { name: "Yellow", hex: "#FFD700" },
        { name: "Green", hex: "#32CD32" },
        { name: "Blue", hex: "#1E90FF" },
        { name: "Purple", hex: "#8A2BE2" },
        { name: "Mauve", hex: "#A49DC8" },
        { name: "Pink", hex: "#FF69B4" },
        { name: "Monochrome", hex: "#A9A9A9" },
        { name: "Pitch", hex: "#1A1A1A" }
    ]

    FileView {
        id: listFile
        path: window.cacheDir + "/wallpaper-list.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: listFile.reload()
        onLoaded: window.parseManifest()
    }

    function parseManifest() {
        var raw = String(listFile.text() || "")
        if (raw.trim().length === 0) return
        var out = []
        var done = true
        try {
            var data = JSON.parse(raw)
            done = data.done !== false
            var items = data.items || []
            for (var i = 0; i < items.length; i++) {
                var it = items[i]
                out.push({
                    fileName: it.fileName || "",
                    filePath: it.filePath || "",
                    thumbUrl: it.thumbUrl || "",
                    colors: (it.colors || []).slice(0, 8),
                    bucket: it.bucket || "Monochrome",
                    mtime: Number(it.mtime) || 0
                })
            }
            out.sort(function (a, b) { return b.mtime - a.mtime })
        } catch (e) {
            console.log("[wallpaper] manifest parse error:", e, "len=" + raw.length)
        }
        wallpaperModel = out
        applyFilters()
        isLoaded = true
        // Keep indexing until every file is processed.
        if (!done) Qt.callLater(window.triggerIndexer)
    }

    FolderListModel {
        folder: "file://" + window.srcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.bmp", "*.heic", "*.avif",
                      "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.GIF", "*.BMP", "*.HEIC", "*.AVIF"]
        showDirs: false
        onStatusChanged: if (status === FolderListModel.Ready) Qt.callLater(window.triggerIndexer)
    }

    Process {
        id: indexer
        running: false
        command: ["python3", window.scriptDir + "/color_extract.py", window.srcDir, window.cacheDir]
        stdout: StdioCollector { onStreamFinished: Qt.callLater(() => listFile.reload()) }
        stderr: StdioCollector {}
        onExited: Qt.callLater(() => listFile.reload())
    }

    function triggerIndexer() {
        // Never overlap runs: the previous run reloads the manifest on exit,
        // and FolderListModel re-fires Ready when the dir actually changes.
        if (indexer.running) return
        indexer.running = true
    }

    function applyFilters() {
        var filter = window.currentFilter
        var out = []
        for (var i = 0; i < window.wallpaperModel.length; i++) {
            var it = window.wallpaperModel[i]
            if (filter !== "All" && filter !== it.bucket) continue
            out.push(it)
        }
        window.displayModel = out
        window.jumpToCurrent()
    }

    function jumpToCurrent() {
        if (window.displayModel.length === 0) {
            view.currentIndex = -1
            return
        }
        var path = window.currentPath
        if (path === "") {
            if (view.currentIndex < 0) view.currentIndex = 0
            else view.currentIndex = Math.max(0, Math.min(window.displayModel.length - 1, view.currentIndex))
            return
        }
        var best = -1
        for (var i = 0; i < window.displayModel.length; i++) {
            if (window.displayModel[i].filePath === path) { best = i; break }
        }
        if (best === -1) {
            view.currentIndex = Math.max(0, Math.min(window.displayModel.length - 1, view.currentIndex))
        } else {
            view.currentIndex = best
        }
    }

    function stepToNextValidIndex(direction) {
        if (window.isApplying || window.showPanel || window.displayModel.length === 0) return
        var next = view.currentIndex < 0
            ? (direction > 0 ? 0 : window.displayModel.length - 1)
            : view.currentIndex + direction
        if (next >= 0 && next < window.displayModel.length) view.currentIndex = next
    }

    function setFilter(name) {
        if (window.isApplying || window.showPanel || window.currentFilter === name) return
        window.currentFilter = name
        window.applyFilters()
        view.forceActiveFocus()
    }

    property bool showPanel: false
    property var selectedItem: null
    property string applyError: ""
    // Live stage reported by wallpaper_apply.sh (@@stage lines on stdout).
    property string applyStatus: ""

    // skwd-wall-inspired transition FX (runs through awww's engine;
    // see the preset map in wallpaper_apply.sh). Grouped like skwd-wall's
    // families: fade / wipe / warp, plus shuffle.
    property string transitionType: "fade"
    readonly property var transitionModel: [
        { name: "fade", label: "Fade", hint: "smooth crossfade" },
        { name: "fade-fast", label: "Fade fast", hint: "quick 0.4s blend" },
        { name: "fade-slow", label: "Fade slow", hint: "cinematic 2.2s blend" },
        { name: "simple", label: "Simple", hint: "instant blend" },
        { name: "wipe", label: "Wipe", hint: "angled sweep" },
        { name: "wipe-h", label: "Wipe H", hint: "horizontal sweep" },
        { name: "wipe-v", label: "Wipe V", hint: "vertical sweep" },
        { name: "wipe-diag", label: "Wipe diag", hint: "diagonal sweep" },
        { name: "wave", label: "Wave", hint: "wavy sweep" },
        { name: "wave-big", label: "Wave big", hint: "wide rolling sweep" },
        { name: "wave-steep", label: "Wave steep", hint: "tight vertical sweep" },
        { name: "slide-left", label: "Slide L", hint: "slide from left" },
        { name: "slide-right", label: "Slide R", hint: "slide from right" },
        { name: "slide-up", label: "Slide up", hint: "slide from top" },
        { name: "slide-down", label: "Slide down", hint: "slide from bottom" },
        { name: "grow", label: "Grow", hint: "expanding circle" },
        { name: "grow-corner", label: "Grow corner", hint: "bloom from corner" },
        { name: "grow-top", label: "Grow top", hint: "bloom from top" },
        { name: "iris", label: "Iris", hint: "grow from center" },
        { name: "any", label: "Anywhere", hint: "grow from random point" },
        { name: "implode", label: "Implode", hint: "shrinking circle" },
        { name: "ripple", label: "Ripple", hint: "sink to corner" },
        { name: "random", label: "Random", hint: "surprise me" }
    ]

    // No confirmation step: picking a wallpaper applies it immediately.
    // showPanel now only drives the progress/error overlay.
    function applyWallpaper(index) {
        if (window.isApplying || window.showPanel || index < 0 || index >= window.displayModel.length) return
        window.selectedItem = window.displayModel[index]
        window.applyError = ""
        window.applyStatus = "Starting " + window.transitionType + "…"
        window.isApplying = true
        window.showPanel = true
        // Non-empty initial command so the QStringList binding never sees [undefined].
        window.applyArgs = ["bash", window.scriptDir + "/wallpaper_apply.sh",
                            window.selectedItem.filePath, "auto"]
        // Restart cleanly on the next tick so the command binding (applyArgs)
        // has propagated before the process spawns.
        applyProc.running = false
        Qt.callLater(function() { applyProc.running = true })
    }

    function parseApplyStage(line) {
        var t = String(line || "").trim()
        if (t.indexOf("@@stage ") !== 0) return
        var stage = t.substring(8)
        if (stage === "wallpaper") window.applyStatus = "Setting wallpaper · " + window.transitionType + "…"
        else if (stage === "theme") window.applyStatus = "Generating theme…"
    }

    function refreshTransition() {
        if (transReader.running) return
        transReader.running = true
    }

    function setTransition(name) {
        if (window.isApplying || window.showPanel || window.transitionType === name) return
        window.transitionType = name
        window.transWriteArgs = ["sh", "-c", "printf '%s\\n' '" + name + "' > '" + window.cacheDir + "/transition.txt'"]
        transWriter.running = false
        Qt.callLater(function() { transWriter.running = true })
    }

    function cycleTransition(direction) {
        var names = []
        for (var i = 0; i < window.transitionModel.length; i++) names.push(window.transitionModel[i].name)
        var idx = names.indexOf(window.transitionType)
        if (idx < 0) idx = 0
        window.setTransition(names[(idx + direction + names.length) % names.length])
    }

    // Non-empty initial command so the QStringList binding never sees [undefined].
    property var applyArgs: ["true"]
    property var transWriteArgs: ["true"]

    Process {
        id: applyProc
        running: false
        command: window.applyArgs
        stdout: SplitParser {
            onRead: data => window.parseApplyStage(data)
        }
        stderr: StdioCollector {}
        onExited: code => {
            window.isApplying = false
            if (code !== 0) {
                window.applyError = "Could not apply wallpaper. Please try again."
                console.warn("Wallpaper apply failed with exit code", code)
                return
            }
            if (window.selectedItem) window.currentPath = window.selectedItem.filePath
            window.showPanel = false
            window.requestClose()
        }
    }

    Process {
        id: currentReader
        command: ["cat", window.cacheDir + "/current.txt"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text || "").trim()
                // Keep the previous selection when current.txt is missing or
                // empty (first run) instead of wiping it.
                if (t.length > 0) window.currentPath = t
                window.jumpToCurrent()
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: transReader
        command: ["sh", "-c", "cat '" + window.cacheDir + "/transition.txt' 2>/dev/null || echo fade"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text || "").trim().split(/\s+/)[0] || "fade"
                var ok = false
                for (var i = 0; i < window.transitionModel.length; i++)
                    if (window.transitionModel[i].name === t) { ok = true; break }
                window.transitionType = ok ? t : "fade"
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: transWriter
        running: false
        command: window.transWriteArgs
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    function refreshCurrent() {
        if (currentReader.running) return
        currentReader.running = true
    }

    onVisible_Changed: {
        if (!window.isApplying) {
            window.showPanel = false
            window.selectedItem = null
            window.applyError = ""
            window.applyStatus = ""
        }
        if (window.visible_) {
            window.refreshCurrent()
            window.refreshTransition()
            view.forceActiveFocus()
        }
    }

    ListView {
        id: view
        anchors.fill: parent
        clip: false
        focus: true
        orientation: ListView.Horizontal
        spacing: 0
        interactive: !window.isApplying && !window.showPanel
        keyNavigationEnabled: !window.isApplying && !window.showPanel

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2) + window.selectedCenterOffset
        preferredHighlightEnd: (width / 2) + ((window.itemWidth * 1.5 + window.spacing) / 2) + window.selectedCenterOffset

        model: window.displayModel
        currentIndex: -1
        // Small buffer so off-screen thumbs are freed quickly.
        // Old itemWidth*6 kept ~7+ full thumbs decoded = high RSS.
        cacheBuffer: Math.max(view.width * 0.5, window.itemWidth * 2)
        highlightMoveDuration: 220
        highlightResizeDuration: 220

        header: Item { width: Math.max(0, (view.width / 2) - (window.itemWidth * 1.5 / 2) + window.selectedCenterOffset) }
        footer: Item { width: Math.max(0, (view.width / 2) - (window.itemWidth * 1.5 / 2) - window.selectedCenterOffset) }

        delegate: Item {
            required property var modelData
            required property int index

            readonly property bool isCurrent: index === view.currentIndex
            readonly property int dist: Math.abs(index - view.currentIndex)
            readonly property real sideScale: Math.max(0.58, Math.pow(0.88, Math.max(0, dist - 1)))

            readonly property real cellWidth: isCurrent ? (window.itemWidth * 1.5 + window.spacing) : (window.itemWidth * 0.48 * sideScale)
            readonly property real targetHeight: isCurrent ? (window.itemHeight + 30 * window.u) : (window.itemHeight * Math.max(0.62, Math.pow(0.90, Math.max(0, dist - 1))))

            width: cellWidth
            height: targetHeight
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            anchors.verticalCenterOffset: window.u * 24
            z: isCurrent ? 100 : Math.max(1, 50 - dist)
            opacity: 1.0

            // NOTE: no Behavior on width/height here on purpose. Animating
            // delegate size relayouts the whole ListView every frame (layout
            // thrash + highlight fighting = jank). Emphasis animates via the
            // GPU-cheap inner scale below; the snap itself stays exact.

            Item {
                id: skewedWrapper
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -(window.skewFactor * height) / 2
                width: parent.width
                height: parent.height
                // GPU transform emphasis instead of layout animation.
                scale: isCurrent ? 1.0 : 0.94
                Behavior on scale { Anim { type: Anim.BouncyFast } }
                // Static fan: neighbours tilt away from the selected card.
                // No Behavior on purpose — snaps instantly, zero per-frame cost.
                rotation: isCurrent ? 0 : (index < view.currentIndex ? 2.2 : -2.2)
                transform: Matrix4x4 {
                    property real s: window.skewFactor
                    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !window.isApplying && !window.showPanel
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.currentIndex = index
                        window.applyWallpaper(index)
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: window.borderWidth

                    Rectangle { anchors.fill: parent; radius: window.cornerRadius; color: window.surface0 }

                    Rectangle {
                        id: cardMask
                        anchors.fill: parent
                        radius: window.cornerRadius
                        visible: false
                        layer.enabled: true
                    }

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect { maskEnabled: true; maskSource: cardMask }

                        Image {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: window.u * -50
                            width: (window.itemWidth * 1.5) + ((window.itemHeight + 30 * window.u) * Math.abs(window.skewFactor)) + window.u * 50
                            height: window.itemHeight + 30 * window.u
                            fillMode: Image.PreserveAspectCrop
                            source: modelData.thumbUrl
                            asynchronous: true
                            cache: true
                            smooth: true
                            // Static zoom steps: side cards sit slightly zoomed,
                            // selected settles to 1.0. No Behavior — snaps
                            // instantly instead of animating every navigation
                            // step across all visible delegates.
                            scale: isCurrent ? 1.0 : 1.07
                            // No sourceSize override: thumbs on disk are
                            // already small (THUMB_HEIGHT 420). Forcing a
                            // size tied to the animated delegate geometry
                            // re-decoded the image on every frame.
                            transform: Matrix4x4 {
                                property real s: -window.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: window.cornerRadius
                        color: "transparent"
                        border.width: isCurrent ? window.borderWidth : 0
                        border.color: isCurrent ? window.blue : "transparent"
                        Behavior on border.width { Anim { type: Anim.BouncyFast } }
                        Behavior on border.color { CAnim { } }
                        opacity: isCurrent ? 1.0 : 0.0
                        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                    }

                    // Apply flash: selecting a card blinks white while the
                    // real awww transition fires behind. No Behavior —
                    // snaps with isApplying, zero animation cost.
                    Rectangle {
                        anchors.fill: parent
                        radius: window.cornerRadius
                        color: "white"
                        opacity: (window.isApplying && isCurrent) ? 0.28 : 0.0
                    }
                }
            }
        }
    }

    Rectangle {
        id: filterBar
        anchors.horizontalCenter: parent.horizontalCenter

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: window.u * 24
                                       - (window.itemHeight + window.u * 30) / 2
                                       - window.u * 18
                                       - window.u * 24
        z: 200
        height: window.u * 48
        width: filterRow.width + window.u * 20
        radius: window.cornerRadius
        color: window.baseColor
        border.width: 0


        Row {
            id: filterRow
            anchors.centerIn: parent
            spacing: window.u * 8

            Repeater {
                model: window.filterData
                delegate: Item {
                    required property var modelData
                    width: modelData.hex === "" ? window.u * 34 : window.u * 34
                    height: window.u * 34
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        visible: modelData.hex === ""
                        anchors.fill: parent
                        radius: window.cornerRadius
                        color: window.currentFilter === modelData.name ? window.surface2
                             : (tabMouse.containsMouse ? window.surface1 : window.surface0)
                        border.width: window.currentFilter === modelData.name ? 2 : 0
                        border.color: window.textColor
                        Behavior on color { CAnim { } }
                        Behavior on border.width { Anim { type: Anim.BouncyFast } }

                        Column {
                            anchors.centerIn: parent
                            spacing: (window.u * 34 - 24) < 0 ? 1 : window.u * 2
                            Repeater {
                                model: 2
                                delegate: Row {
                                    spacing: (window.u * 34 - 24) < 0 ? 1 : window.u * 2
                                    Repeater {
                                        model: 2
                                        delegate: Rectangle {
                                            width: window.u * 5
                                            height: window.u * 5
                                            radius: 10
                                            color: window.currentFilter === modelData.name ? window.surface0 : window.subtextColor
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !window.isApplying && !window.showPanel
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.setFilter(modelData.name)
                        }
                    }

                    Rectangle {
                        visible: modelData.hex !== ""
                        anchors.fill: parent
                        radius: window.cornerRadius
                        color: modelData.hex
                        border.width: window.currentFilter === modelData.name ? 2 : 0
                        border.color: window.textColor
                        Behavior on color { CAnim { } }
                        Behavior on border.width { Anim { type: Anim.BouncyFast } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !window.isApplying && !window.showPanel
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.setFilter(modelData.name)
                        }
                    }
                }
            }
        }
    }

    // skwd-wall-style FX strip: transition picker, bottom-center.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: window.u * 24
        z: 200
        height: window.u * 40
        width: Math.min(parent.width - window.u * 80, fxRow.width + window.u * 20)
        radius: window.cornerRadius
        color: window.baseColor
        border.width: 0
        // Instant show/hide with the picker chrome — no fade Behavior.
        visible: !window.showPanel && !window.isApplying

        ListView {
            id: fxRow
            anchors.centerIn: parent
            width: Math.min(parent.width - window.u * 20, contentWidth)
            height: parent.height
            orientation: ListView.Horizontal
            spacing: window.u * 6
            clip: true
            // Draggable: 23 presets overflow on narrow screens; vertical
            // wheel still passes through (orientation is horizontal).
            interactive: true
            model: window.transitionModel
            delegate: Item {
                required property var modelData
                width: fxLabel.implicitWidth + window.u * 18
                height: window.u * 40
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - window.u * 4
                    height: window.u * 26
                    radius: window.u * 13
                    color: window.transitionType === modelData.name ? window.surface2
                         : (fxMouse.containsMouse ? window.surface1 : "transparent")
                    border.width: window.transitionType === modelData.name ? 1 : 0
                    border.color: window.textColor
                    Behavior on color { CAnim { } }
                    Text {
                        id: fxLabel
                        anchors.centerIn: parent
                        text: modelData.label || modelData.name
                        color: window.transitionType === modelData.name ? window.textColor : window.subtextColor
                        font.family: window.uiFont
                        font.pixelSize: window.u * 11
                    }
                    MouseArea {
                        id: fxMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !window.isApplying && !window.showPanel
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.setTransition(modelData.name)
                    }
                }
            }
        }
    }

    Rectangle {
        id: applyPanel
        visible: window.showPanel
        anchors.bottom: parent.bottom
        anchors.bottomMargin: visible ? window.u * 32 : -height
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - window.u * 80, 720)
        height: panelCol.height + window.u * 32
        radius: window.cornerRadius
        color: window.baseColor
        border.width: 0
        z: 300
        // No entrance animation: snaps with showPanel.
        opacity: visible ? 1.0 : 0.0

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: wheel => wheel.accepted = true
        }

        Column {
            id: panelCol
            enabled: !window.isApplying
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: window.u * 16
            spacing: window.u * 12

            Text {
                text: window.selectedItem ? window.selectedItem.fileName : ""
                width: parent.width
                color: window.textColor
                font.family: window.uiFont
                font.pixelSize: window.u * 13
                font.bold: true
                elide: Text.ElideMiddle
            }

            // Single mode: derived from the wallpaper itself at apply time.
            Text {
                text: "Mode · Auto (from wallpaper)   ·   FX · " + window.transitionType
                color: window.subtextColor
                font.family: window.uiFont
                font.pixelSize: window.u * 11
            }

            Text {
                visible: window.isApplying
                text: window.applyStatus !== "" ? window.applyStatus : "Applying…"
                width: parent.width
                color: window.textColor
                font.family: window.uiFont
                font.pixelSize: window.u * 11
            }

            Text {
                visible: window.applyError !== ""
                text: window.applyError
                width: parent.width
                color: window.blue
                font.family: window.uiFont
                font.pixelSize: window.u * 11
                wrapMode: Text.WordWrap
            }

            Row {
                visible: !window.isApplying
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: window.u * 10

                Rectangle {
                    width: closeLabel.implicitWidth + window.u * 28
                    height: window.u * 32
                    radius: 10
                    color: closeHov.containsMouse ? window.surface1 : "transparent"
                    Text {
                        id: closeLabel
                        anchors.centerIn: parent
                        text: "Close"
                        color: window.subtextColor
                        font.family: window.uiFont
                        font.pixelSize: window.u * 12
                    }
                    MouseArea {
                        id: closeHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !window.isApplying
                        onClicked: {
                            window.showPanel = false
                            window.applyError = ""
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: window.showPanel
        z: 250
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
        onClicked: mouse => {
            if (!window.isApplying && mouse.button === Qt.LeftButton) window.showPanel = false
        }
    }

    Shortcut {
        sequence: "Left"; enabled: window.visible_ && !window.isApplying && !window.showPanel
        onActivated: window.stepToNextValidIndex(-1)
    }
    Shortcut {
        sequence: "Right"; enabled: window.visible_ && !window.isApplying && !window.showPanel
        onActivated: window.stepToNextValidIndex(1)
    }
    Shortcut {
        sequence: "h"; enabled: window.visible_ && !window.isApplying && !window.showPanel
        onActivated: window.stepToNextValidIndex(-1)
    }
    Shortcut {
        sequence: "l"; enabled: window.visible_ && !window.isApplying && !window.showPanel
        onActivated: window.stepToNextValidIndex(1)
    }
    Shortcut {
        sequence: "Return"; enabled: window.visible_ && !window.isApplying
        onActivated: {
            if (!window.showPanel) window.applyWallpaper(view.currentIndex)
        }
    }
    Shortcut {
        sequence: "t"; enabled: window.visible_ && !window.isApplying && !window.showPanel
        onActivated: window.cycleTransition(1)
    }
    Shortcut {
        sequence: "T"; enabled: window.visible_ && !window.isApplying && !window.showPanel
        onActivated: window.cycleTransition(-1)
    }
    Shortcut {
        sequence: "Tab"; enabled: window.visible_ && !window.isApplying && !window.showPanel
        onActivated: window.cycleFilter(1)
    }
    Shortcut {
        sequence: "Backtab"; enabled: window.visible_ && !window.isApplying && !window.showPanel
        onActivated: window.cycleFilter(-1)
    }
    Shortcut {
        sequence: "Escape"
        enabled: window.visible_ && !window.isApplying
        onActivated: {
            if (window.showPanel) window.showPanel = false
            else window.requestClose()
        }
    }

    function cycleFilter(direction) {
        var names = []
        for (var i = 0; i < window.filterData.length; i++) names.push(window.filterData[i].name)
        var idx = names.indexOf(window.currentFilter)
        var next = (idx + direction + names.length) % names.length
        window.setFilter(names[next])
    }
}
