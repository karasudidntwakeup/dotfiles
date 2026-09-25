import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Lean theme/scheme picker — same carousel pattern as WallpaperPicker.
// No favorites, no collections, no grid. Lists every scheme from
// scheme_list.py (fzf list + fixed palettes + nvim extras) and applies via
// wallpaper_apply.sh with widgets pinned.
Item {
    id: window

    readonly property string scriptDir: Quickshell.shellDir + "/scripts"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell/wallpaper"
    readonly property string srcDir: Quickshell.env("HOME") + "/wallpaper"

    property string currentKind: "All"
    property string searchText: ""
    property var schemeModel: []
    property var displayModel: []
    property string currentKey: ""
    property string wallpaperPath: ""
    property bool isApplying: false
    property bool isLoaded: false

    signal requestClose()
    property bool visible_: false
    // Same animProgress pattern as the other pickers: PanelWindow stays alive
    // until this reaches ~0 so close animates. Transform-only per frame.
    property real animProgress: visible_ ? 1.0 : 0.0
    Behavior on animProgress { Anim { type: Anim.Bouncy } }
    // Smooth opacity ramp decoupled from the bouncy slide: OutBack
    // finishes ~95% in the first 150ms, which reads as a pop.
    property real fadeProgress: visible_ ? 1.0 : 0.0
    Behavior on fadeProgress { Anim { type: Anim.SlowEffects } }
    opacity: fadeProgress
    transform: Translate { y: (1.0 - animProgress) * 24 }

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
    readonly property real cornerRadius: 0
    readonly property real selectedCenterOffset: (window.skewFactor * window.itemHeight) / 2

    readonly property var kindData: ["All", "Auto", "Fixed", "Nvim"]

    FileView {
        id: listFile
        path: window.cacheDir + "/scheme-list.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: listFile.reload()
        onLoaded: window.parseManifest()
    }

    function parseManifest() {
        var raw = String(listFile.text() || "")
        if (raw.trim().length === 0) return
        var out = []
        try {
            var data = JSON.parse(raw)
            window.currentKey = data.current || ""
            var items = data.items || []
            for (var i = 0; i < items.length; i++) {
                var it = items[i]
                var kind = it.kind === "nv" ? "Nvim"
                    : it.kind === "auto" ? "Auto" : "Fixed"
                out.push({
                    key: it.key || "",
                    label: it.label || it.key || "",
                    kind: kind,
                    colors: it.colors || []
                })
            }
        } catch (e) {
            console.log("[theme] manifest parse error:", e, "len=" + raw.length)
        }
        schemeModel = out
        applyFilters()
        isLoaded = true
    }

    // Regenerate the manifest. Instant (~300 tiny entries), so unlike the
    // wallpaper indexer there is no chunking or overlap guard beyond this.
    Process {
        id: generator
        running: false
        command: ["python3", window.scriptDir + "/scheme_list.py", window.cacheDir]
        stdout: StdioCollector { onStreamFinished: Qt.callLater(() => listFile.reload()) }
        stderr: StdioCollector {}
        onExited: Qt.callLater(() => listFile.reload())
    }

    function triggerGenerator() {
        if (generator.running) return
        generator.running = true
    }

    // Current wallpaper (current.txt, else first image in ~/wallpaper).
    // Resolved once per open; the apply step
    // needs it as wallpaper_apply.sh's first arg.
    Process {
        id: wallpaperReader
        command: ["sh", "-c", "cat '" + window.cacheDir + "/current.txt' 2>/dev/null || find '" + window.srcDir + "' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                window.wallpaperPath = String(this.text || "").trim()
                window.jumpToCurrent()
            }
        }
        stderr: StdioCollector {}
    }

    function refreshWallpaper() {
        if (wallpaperReader.running) return
        wallpaperReader.running = true
    }

    function applyFilters() {
        var kind = window.currentKind
        var q = window.searchText.trim().toLowerCase()
        var out = []
        for (var i = 0; i < window.schemeModel.length; i++) {
            var it = window.schemeModel[i]
            if (kind !== "All" && it.kind !== kind) continue
            if (q.length > 0) {
                var hay = (it.label + " " + it.key).toLowerCase()
                if (hay.indexOf(q) < 0) continue
            }
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
        var key = window.currentKey
        if (!key) {
            if (view.currentIndex < 0) view.currentIndex = 0
            else view.currentIndex = Math.max(0, Math.min(window.displayModel.length - 1, view.currentIndex))
            return
        }
        var best = -1
        for (var i = 0; i < window.displayModel.length; i++) {
            if (window.displayModel[i].key === key) { best = i; break }
        }
        view.currentIndex = best === -1
            ? Math.max(0, Math.min(window.displayModel.length - 1, view.currentIndex < 0 ? 0 : view.currentIndex))
            : best
    }

    function stepToNextValidIndex(direction) {
        if (window.isApplying || window.showPanel || window.displayModel.length === 0) return
        var next = view.currentIndex < 0
            ? (direction > 0 ? 0 : window.displayModel.length - 1)
            : view.currentIndex + direction
        if (next >= 0 && next < window.displayModel.length) view.currentIndex = next
    }

    function setKind(name) {
        if (window.isApplying || window.showPanel || window.currentKind === name) return
        window.currentKind = name
        window.applyFilters()
        view.forceActiveFocus()
    }

    function cycleKind(direction) {
        var names = window.kindData
        var next = (names.indexOf(window.currentKind) + direction + names.length) % names.length
        window.setKind(names[next])
    }

    property bool showPanel: false
    property var selectedItem: null
    property string applyError: ""
    // Live stage reported by wallpaper_apply.sh (@@stage lines on stdout).
    property string applyStatus: ""

    // Relative luminance of a #rrggbb swatch; >= 0.40 counts as light.
    // Mirrors derive_mode_from_scheme() in wallpaper_apply.sh.
    function swatchIsLight(hex) {
        var h = String(hex || "").replace("#", "")
        if (h.length < 6) return false
        var r = parseInt(h.substr(0, 2), 16) / 255
        var g = parseInt(h.substr(2, 2), 16) / 255
        var b = parseInt(h.substr(4, 2), 16) / 255
        if (isNaN(r) || isNaN(g) || isNaN(b)) return false
        var f = function(c) { return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4) }
        return (0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)) >= 0.40
    }

    function derivedModeText(item) {
        if (!item || !item.colors || item.colors.length === 0)
            return "Mode · Auto (from wallpaper)"
        return "Mode · " + (window.swatchIsLight(item.colors[0]) ? "Light" : "Dark") + " (from scheme)"
    }

    function openPanel(index) {
        if (window.isApplying || window.showPanel || index < 0 || index >= window.displayModel.length) return
        window.selectedItem = window.displayModel[index]
        window.applyError = ""
        window.applyStatus = ""
        window.showPanel = true
    }

    function parseApplyStage(line) {
        var t = String(line || "").trim()
        if (t.indexOf("@@stage ") !== 0) return
        var stage = t.substring(8)
        if (stage === "wallpaper") window.applyStatus = "Setting wallpaper…"
        else if (stage === "theme") window.applyStatus = "Generating theme…"
    }

    // Non-empty initial command so the QStringList binding never sees [undefined].
    property var applyArgs: ["true"]
    function confirmApply() {
        if (!window.selectedItem || window.isApplying) return
        if (!window.wallpaperPath) {
            window.applyError = "No wallpaper found in ~/wallpaper."
            return
        }
        window.applyError = ""
        window.applyStatus = "Starting…"
        window.isApplying = true
        window.applyArgs = ["bash", window.scriptDir + "/wallpaper_apply.sh",
                            window.wallpaperPath, "auto",
                            window.selectedItem.key, "", "1"]
        // Restart cleanly on the next tick so the command binding (applyArgs)
        // has propagated before the process spawns.
        applyProc.running = false
        Qt.callLater(function() { applyProc.running = true })
    }

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
                window.applyError = "Could not apply theme. Please try again."
                console.warn("Theme apply failed with exit code", code)
                return
            }
            if (window.selectedItem) window.currentKey = window.selectedItem.key
            window.showPanel = false
            window.requestClose()
        }
    }

    onVisible_Changed: {
        if (!window.isApplying) {
            window.showPanel = false
            window.selectedItem = null
            window.applyError = ""
            window.applyStatus = ""
        }
        if (window.visible_) {
            window.triggerGenerator()
            window.refreshWallpaper()
            searchField.text = ""
            window.searchText = ""
            window.applyFilters()
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
        // Typing filters the list (same "type to search" as ejuro's picker,
        // without the extra UI). Backspace edits the query.
        Keys.onPressed: event => {
            if (window.isApplying || window.showPanel) return
            var t = event.text || ""
            if (t.length === 1 && t >= " " && t <= "~") {
                searchField.text += t
                searchField.cursorPosition = searchField.text.length
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace && searchField.text.length > 0) {
                searchField.text = searchField.text.slice(0, -1)
                event.accepted = true
            }
        }

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2) + window.selectedCenterOffset
        preferredHighlightEnd: (width / 2) + ((window.itemWidth * 1.5 + window.spacing) / 2) + window.selectedCenterOffset

        model: window.displayModel
        currentIndex: -1
        cacheBuffer: Math.max(view.width, window.itemWidth * 6)
        highlightMoveDuration: 220
        highlightResizeDuration: 220

        header: Item { width: Math.max(0, (view.width / 2) - (window.itemWidth * 1.5 / 2) + window.selectedCenterOffset) }
        footer: Item { width: Math.max(0, (view.width / 2) - (window.itemWidth * 1.5 / 2) - window.selectedCenterOffset) }

        delegate: Item {
            required property var modelData
            required property int index

            readonly property bool isCurrent: index === view.currentIndex
            readonly property bool isActive: modelData.key === window.currentKey
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

            // NOTE: no Behavior on width/height on purpose (same reason as
            // WallpaperPicker): animating delegate size relayouts the whole
            // ListView every frame. Emphasis animates via inner scale.
            Item {
                id: skewedWrapper
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -(window.skewFactor * height) / 2
                width: parent.width
                height: parent.height
                scale: isCurrent ? 1.0 : 0.94
                Behavior on scale { Anim { type: Anim.BouncyFast } }
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
                        window.openPanel(index)
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

                        Column {
                            anchors.fill: parent
                            spacing: 0

                            // Palette preview: base block on top, accent strip
                            // below. Auto schemes have no fixed palette.
                            Rectangle {
                                width: parent.width
                                height: parent.height * 0.62
                                color: modelData.colors.length > 0 ? modelData.colors[0] : window.surface1
                                Text {
                                    visible: modelData.colors.length === 0
                                    anchors.centerIn: parent
                                    text: "Auto\nfrom wallpaper"
                                    horizontalAlignment: Text.AlignHCenter
                                    color: window.subtextColor
                                    font.family: window.uiFont
                                    font.pixelSize: window.u * 12
                                }
                                // Counter-skew keeps swatches rectangular
                                // inside the skewed card (same trick as the
                                // wallpaper thumbnails).
                                Row {
                                    visible: modelData.colors.length > 0
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: window.u * 8
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.horizontalCenterOffset: window.u * 50
                                    spacing: window.u * 6
                                    transform: Matrix4x4 {
                                        property real s: -window.skewFactor
                                        matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                    }
                                    Repeater {
                                        model: modelData.colors.slice(3, 9)
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: window.u * 26
                                            height: window.u * 26
                                            radius: 0
                                            color: modelData
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.25)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: parent.height * 0.38
                                color: window.surface0
                                Column {
                                    anchors.fill: parent
                                    anchors.margins: window.u * 10
                                    spacing: window.u * 4
                                    Text {
                                        text: modelData.label
                                        width: parent.width
                                        color: window.textColor
                                        font.family: window.uiFont
                                        font.pixelSize: window.u * 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Row {
                                        spacing: window.u * 6
                                        Text {
                                            text: modelData.kind.toUpperCase()
                                            color: window.subtextColor
                                            font.family: window.uiFont
                                            font.pixelSize: window.u * 10
                                        }
                                        Text {
                                            visible: isActive
                                            text: "● ACTIVE"
                                            color: window.blue
                                            font.family: window.uiFont
                                            font.pixelSize: window.u * 10
                                            font.bold: true
                                        }
                                    }
                                }
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
                }
            }
        }
    }

    // Filter bar: search field + kind chips, same position as the wallpaper
    // color-bucket bar.
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

            Rectangle {
                width: window.u * 220
                height: window.u * 34
                anchors.verticalCenter: parent.verticalCenter
                radius: window.cornerRadius
                color: searchField.activeFocus ? window.surface2 : window.surface0
                border.width: searchField.activeFocus ? 1 : 0
                border.color: window.textColor
                Behavior on color { CAnim { } }

                TextInput {
                    id: searchField
                    anchors.fill: parent
                    anchors.leftMargin: window.u * 10
                    anchors.rightMargin: window.u * 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: window.textColor
                    font.family: window.uiFont
                    font.pixelSize: window.u * 12
                    clip: true
                    onTextChanged: {
                        if (window.searchText !== text) {
                            window.searchText = text
                            window.applyFilters()
                        }
                    }
                    Keys.onPressed: event => {
                        // Ctrl+Backspace clears (same as ejuro's picker).
                        if (event.key === Qt.Key_Backspace && (event.modifiers & Qt.ControlModifier)) {
                            searchField.text = ""
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape && searchField.text.length > 0) {
                            searchField.text = ""
                            event.accepted = true
                        }
                    }
                }
                Text {
                    visible: searchField.text.length === 0
                    anchors.fill: parent
                    anchors.leftMargin: window.u * 10
                    verticalAlignment: Text.AlignVCenter
                    text: window.isLoaded ? schemeModel.length + " themes · type to filter" : "Loading…"
                    color: window.subtextColor
                    font.family: window.uiFont
                    font.pixelSize: window.u * 12
                }
            }

            Repeater {
                model: window.kindData
                delegate: Rectangle {
                    required property var modelData
                    width: kindLabel.implicitWidth + window.u * 20
                    height: window.u * 34
                    anchors.verticalCenter: parent.verticalCenter
                    radius: window.cornerRadius
                    color: window.currentKind === modelData ? window.surface2
                         : (kindMouse.containsMouse ? window.surface1 : window.surface0)
                    border.width: window.currentKind === modelData ? 2 : 0
                    border.color: window.textColor
                    Behavior on color { CAnim { } }
                    Behavior on border.width { Anim { type: Anim.BouncyFast } }
                    Text {
                        id: kindLabel
                        anchors.centerIn: parent
                        text: modelData
                        color: window.currentKind === modelData ? window.textColor : window.subtextColor
                        font.family: window.uiFont
                        font.pixelSize: window.u * 11
                        font.weight: window.currentKind === modelData ? Font.Bold : Font.Normal
                    }
                    MouseArea {
                        id: kindMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !window.isApplying && !window.showPanel
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.setKind(modelData)
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
        opacity: visible ? 1.0 : 0.0
        Behavior on anchors.bottomMargin { Anim { type: Anim.Bouncy } }
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }

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
                text: window.selectedItem ? window.selectedItem.label : ""
                width: parent.width
                color: window.textColor
                font.family: window.uiFont
                font.pixelSize: window.u * 13
                font.bold: true
                elide: Text.ElideMiddle
            }

            // Single mode: the scheme decides. Light schemes apply the light
            // system, dark schemes the dark system (from palette base color,
            // or the wallpaper itself for Auto schemes).
            Text {
                text: window.derivedModeText(window.selectedItem)
                color: window.subtextColor
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
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: window.u * 10

                Rectangle {
                    width: cancelLabel.implicitWidth + window.u * 28
                    height: window.u * 32
                    radius: 0
                    color: cancelHov.containsMouse ? window.surface1 : "transparent"
                    Text {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: window.subtextColor
                        font.family: window.uiFont
                        font.pixelSize: window.u * 12
                    }
                    MouseArea {
                        id: cancelHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !window.isApplying
                        onClicked: window.showPanel = false
                    }
                }

                Rectangle {
                    width: applyLabel.implicitWidth + window.u * 28
                    height: window.u * 32
                    radius: 0
                    color: window.blue
                    Text {
                        id: applyLabel
                        anchors.centerIn: parent
                        text: window.isApplying ? (window.applyStatus !== "" ? window.applyStatus : "Applying…") : "Apply"
                        color: "#000000"
                        font.family: window.uiFont
                        font.pixelSize: window.u * 12
                        font.bold: true
                    }
                    MouseArea {
                        id: applyHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !window.isApplying
                        onClicked: window.confirmApply()
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
            if (window.showPanel) window.confirmApply()
            else window.openPanel(view.currentIndex)
        }
    }
    Shortcut {
        sequence: "Tab"; enabled: window.visible_ && !window.isApplying && !window.showPanel
        onActivated: window.cycleKind(1)
    }
    Shortcut {
        sequence: "Backtab"; enabled: window.visible_ && !window.isApplying && !window.showPanel
        onActivated: window.cycleKind(-1)
    }
    Shortcut {
        sequence: "Escape"
        enabled: window.visible_ && !window.isApplying
        onActivated: {
            if (window.showPanel) window.showPanel = false
            else window.requestClose()
        }
    }
}
