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
    property string currentPath: ""

    // Theme hooks (provided by shell.qml)
    property color surfaceColor: "#1f1f24"
    property color borderColor: "#3a3a42"
    property color fgColor: "#ffffff"
    property color accentColor: "#96c8f6"
    property string uiFont: "Inter"
    property string iconFont: "Symbols Nerd Font"

    // Derived surfaces
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function brighten(c, f) {
        return Qt.rgba(Math.min(1, c.r * f), Math.min(1, c.g * f), Math.min(1, c.b * f), 1)
    }
    readonly property color baseColor: withAlpha(surfaceColor, 0.90) // filter pill bg
    readonly property color surface0: surfaceColor
    readonly property color surface1: brighten(surfaceColor, 1.18) // tab hover
    readonly property color surface2: brighten(surfaceColor, 1.45) // tab active
    readonly property color textColor: fgColor
    readonly property color subtextColor: withAlpha(fgColor, 0.55)
    readonly property color blue: accentColor

    // Sizing
    readonly property real u: Screen.height >= 1400 ? 1.0 : 0.85
    readonly property real itemWidth: 400 * u
    readonly property real itemHeight: 420 * u
    readonly property real borderWidth: 3 * u
    readonly property real spacing: 10 * u
    readonly property real skewFactor: -0.35
    readonly property real cornerRadius: 18 * u
    readonly property real selectedCenterOffset: (window.skewFactor * window.itemHeight) / 2

    readonly property var filterData: [
        { name: "All", hex: "", icon: "grid" },
        { name: "Red", hex: "#FF4500" },
        { name: "Orange", hex: "#FFA500" },
        { name: "Yellow", hex: "#FFD700" },
        { name: "Green", hex: "#32CD32" },
        { name: "Blue", hex: "#1E90FF" },
        { name: "Purple", hex: "#8A2BE2" },
        { name: "Pink", hex: "#FF69B4" },
        { name: "Monochrome", hex: "#A9A9A9" }
    ]

    // Manifest (thumbnails + buckets from indexer)
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
        try {
            var data = JSON.parse(raw)
            var items = data.items || []
            for (var i = 0; i < items.length; i++) {
                var it = items[i]
                out.push({
                    fileName: it.fileName || "",
                    filePath: it.filePath || "",
                    thumbUrl: it.thumbUrl || "",
                    colors: (it.colors || []).slice(0, 8),
                    bucket: it.bucket || "Monochrome"
                })
            }
        } catch (e) {
            console.log("[wallpaper] manifest parse error:", e, "len=" + raw.length)
        }
        wallpaperModel = out
        applyFilters()
        isLoaded = true
    }

    FolderListModel {
        id: srcModel
        folder: "file://" + window.srcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif",
                      "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.GIF"]
        showDirs: false
        onStatusChanged: if (status === FolderListModel.Ready) Qt.callLater(window.triggerIndexer)
    }

    Process {
        id: indexer
        running: false
        command: ["python3", window.scriptDir + "/color_extract.py", window.srcDir, window.cacheDir]
        stdout: StdioCollector { onStreamFinished: Qt.callLater(() => listFile.reload()) }
        onExited: Qt.callLater(() => listFile.reload())
    }

    function triggerIndexer() {
        indexer.running = false
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

    // Reopen on the currently applied wallpaper.
    function jumpToCurrent() {
        var path = window.currentPath
        if (path === "") {
            view.currentIndex = Math.max(0, Math.min(window.displayModel.length - 1, view.currentIndex))
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
        if (window.displayModel.length === 0) return
        var next = view.currentIndex + direction
        if (next >= 0 && next < window.displayModel.length) view.currentIndex = next
    }

    function setFilter(name) {
        if (window.isApplying || window.currentFilter === name) return
        window.currentFilter = name
        window.applyFilters()
        view.forceActiveFocus()
    }

    // Click opens the apply panel (scheme/mode/color), not immediate apply.
    property bool showPanel: false
    property var selectedItem: null
    property string applyMode: "dark"
    property string applyScheme: "content"
    property string applyColor: ""

    readonly property var schemeData: [
        { key: "content",      label: "Content" },
        { key: "expressive",   label: "Expressive" },
        { key: "fidelity",     label: "Fidelity" },
        { key: "fruit_salad",  label: "Fruit Salad" },
        { key: "monochrome",   label: "Monochrome" },
        { key: "neutral",      label: "Neutral" },
        { key: "rainbow",      label: "Rainbow" },
        { key: "smart",        label: "Smart" },
        { key: "vibrant",      label: "Vibrant" },
        { key: "wallpaper_color", label: "Wallpaper Colors" }
    ]

    function openPanel(index) {
        if (index < 0 || index >= window.displayModel.length) return
        var item = window.displayModel[index]
        window.selectedItem = item
        window.applyMode = "dark"
        window.applyScheme = "content"
        window.applyColor = (item.colors && item.colors.length > 0) ? item.colors[0] : ""
        window.showPanel = true
    }

    property var applyArgs: []
    function confirmApply() {
        if (!window.selectedItem || window.isApplying) return
        window.isApplying = true
        var args = ["sh", window.scriptDir + "/wallpaper_apply.sh",
                    window.selectedItem.filePath, window.applyMode, window.applyScheme]
        if (window.applyScheme === "wallpaper_color" && window.applyColor !== "")
            args.push(window.applyColor.replace("#", ""))
        window.applyArgs = args
        applyProc.running = true
    }

    Process {
        id: applyProc
        running: false
        command: window.applyArgs
        onExited: {
            window.isApplying = false
            window.showPanel = false
            window.requestClose()
        }
    }

    // Read the last-applied wallpaper so reopening lands on it.
    Process {
        id: currentReader
        command: ["cat", window.cacheDir + "/current.txt"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text || "").trim()
                window.currentPath = t
                window.jumpToCurrent()
            }
        }
    }

    onVisible_Changed: {
        if (window.visible_) {
            currentReader.running = false
            currentReader.running = true
        }
    }

    // Carousel (skewed horizontal)
    ListView {
        id: view
        anchors.fill: parent
        clip: false
        focus: true
        orientation: ListView.Horizontal
        spacing: 0
        interactive: !window.isApplying

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2) + window.selectedCenterOffset
        preferredHighlightEnd: (width / 2) + ((window.itemWidth * 1.5 + window.spacing) / 2) + window.selectedCenterOffset

        model: window.displayModel
        currentIndex: 0
        cacheBuffer: window.itemWidth * 4

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

            Behavior on width { enabled: window.isLoaded && !window.isApplying; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: window.isLoaded && !window.isApplying; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            // Skewed wrapper (Matrix4x4 shear).
            Item {
                id: skewedWrapper
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -(window.skewFactor * height) / 2
                width: parent.width
                height: parent.height
                transform: Matrix4x4 {
                    property real s: window.skewFactor
                    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !window.isApplying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.currentIndex = index
                        window.openPanel(index)
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: window.borderWidth

                    // Card background + rounded mask.
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
                            sourceSize.width: Math.round(width)
                            sourceSize.height: Math.round(height)
                            transform: Matrix4x4 {
                                property real s: -window.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }
                        }
                    }

                    // Selected border on the current card.
                    Rectangle {
                        anchors.fill: parent
                        radius: window.cornerRadius
                        color: "transparent"
                        border.width: isCurrent ? window.borderWidth : 0
                        border.color: isCurrent ? window.blue : "transparent"
                        Behavior on border.width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        opacity: isCurrent ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
            }
        }
    }

    // Top filter pill (translucent)
    Rectangle {
        id: filterBar
        anchors.horizontalCenter: parent.horizontalCenter
        // Sit directly above the centered carousel cards, not at screen top.
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
        border.color: window.borderColor
        border.width: 1

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

                    // "All" — 2x2 grid icon.
                    Rectangle {
                        visible: modelData.hex === ""
                        anchors.fill: parent
                        radius: window.cornerRadius
                        color: window.currentFilter === modelData.name ? window.surface2
                             : (tabMouse.containsMouse ? window.surface1 : window.surface0)
                        border.color: window.currentFilter === modelData.name ? window.textColor : window.borderColor
                        border.width: window.currentFilter === modelData.name ? (window.u === 1 ? 1.5 : 1) : 1
                        scale: window.currentFilter === modelData.name ? 1.05 : (tabMouse.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        // 2x2 grid using small tiles.
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
                                            radius: 1
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
                            enabled: !window.isApplying
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.setFilter(modelData.name)
                        }
                    }

                    // Color swatch tabs.
                    Rectangle {
                        visible: modelData.hex !== ""
                        anchors.fill: parent
                        radius: window.cornerRadius
                        color: modelData.hex
                        border.color: window.currentFilter === modelData.name ? window.textColor : window.borderColor
                        border.width: window.currentFilter === modelData.name ? (window.u === 1 ? 1.5 : 1) : 1
                        scale: window.currentFilter === modelData.name ? 1.05 : (swatchMouse.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        MouseArea {
                            id: swatchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !window.isApplying
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.setFilter(modelData.name)
                        }
                    }
                }
            }
        }
    }

    // Bottom sheet: scheme / mode / color / apply
    Rectangle {
        id: applyPanel
        visible: window.showPanel && !window.isApplying
        anchors.bottom: parent.bottom
        anchors.bottomMargin: visible ? window.u * 32 : -height
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - window.u * 80, 720)
        height: panelCol.height + window.u * 32
        radius: window.cornerRadius
        color: window.baseColor
        border.color: window.borderColor
        border.width: 1
        z: 200
        opacity: visible ? 1.0 : 0.0
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Column {
            id: panelCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: window.u * 16
            spacing: window.u * 12

            // Title
            Text {
                text: window.selectedItem ? window.selectedItem.fileName : ""
                width: parent.width
                color: window.textColor
                font.family: window.uiFont
                font.pixelSize: window.u * 13
                font.bold: true
                elide: Text.ElideMiddle
            }

            // Color swatches row
            Row {
                spacing: window.u * 6
                visible: window.selectedItem && window.selectedItem.colors && window.selectedItem.colors.length > 0
                Repeater {
                    model: window.selectedItem && window.selectedItem.colors ? window.selectedItem.colors : []
                    delegate: Rectangle {
                        required property string modelData
                        width: window.u * 28; height: window.u * 28
                        radius: window.u * 8
                        color: modelData
                        border.width: window.applyColor === modelData ? 3 : 1
                        border.color: window.applyColor === modelData ? window.blue : window.borderColor
                        scale: swabHover.containsMouse ? 1.12 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        MouseArea {
                            id: swabHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.applyColor = modelData
                        }
                    }
                }
            }

            // Mode row
            Row {
                spacing: window.u * 6
                Text {
                    text: "Mode"
                    color: window.subtextColor
                    font.family: window.uiFont
                    font.pixelSize: window.u * 11
                    anchors.verticalCenter: parent.verticalCenter
                }
                Repeater {
                    model: [
                        { key: "dark",  label: "Dark" },
                        { key: "light", label: "Light" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: modeLabel.implicitWidth + window.u * 20
                        height: window.u * 28
                        radius: window.u * 8
                        color: window.applyMode === modelData.key ? window.surface2
                             : (modeHover.containsMouse ? window.surface1 : window.surface0)
                        border.color: window.applyMode === modelData.key ? window.textColor : window.borderColor
                        border.width: window.applyMode === modelData.key ? (window.u === 1 ? 1.5 : 1) : 1
                        scale: window.applyMode === modelData.key ? 1.04 : (modeHover.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Text {
                            id: modeLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            color: window.applyMode === modelData.key ? window.textColor : window.subtextColor
                            font.family: window.uiFont
                            font.pixelSize: window.u * 11
                            font.weight: window.applyMode === modelData.key ? Font.Bold : Font.Normal
                        }
                        MouseArea {
                            id: modeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.applyMode = modelData.key
                        }
                    }
                }
            }

            // Scheme row
            Flow {
                width: parent.width
                spacing: window.u * 6
                Text {
                    text: "Scheme"
                    color: window.subtextColor
                    font.family: window.uiFont
                    font.pixelSize: window.u * 11
                }
                Repeater {
                    model: window.schemeData
                    delegate: Rectangle {
                        required property var modelData
                        width: schemeLabel.implicitWidth + window.u * 16
                        height: window.u * 28
                        radius: window.u * 8
                        color: window.applyScheme === modelData.key ? window.surface2
                             : (schHover.containsMouse ? window.surface1 : window.surface0)
                        border.color: window.applyScheme === modelData.key ? window.textColor : window.borderColor
                        border.width: window.applyScheme === modelData.key ? (window.u === 1 ? 1.5 : 1) : 1
                        scale: window.applyScheme === modelData.key ? 1.04 : (schHover.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Text {
                            id: schemeLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            color: window.applyScheme === modelData.key ? window.textColor : window.subtextColor
                            font.family: window.uiFont
                            font.pixelSize: window.u * 11
                            font.weight: window.applyScheme === modelData.key ? Font.Bold : Font.Normal
                        }
                        MouseArea {
                            id: schHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.applyScheme = modelData.key
                        }
                    }
                }
            }

            // Apply / Cancel row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: window.u * 10

                Rectangle {
                    width: cancelLabel.implicitWidth + window.u * 28
                    height: window.u * 32
                    radius: window.u * 10
                    color: cancelHov.containsMouse ? window.surface1 : "transparent"
                    border.color: window.borderColor
                    border.width: 1
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
                        onClicked: window.showPanel = false
                    }
                }

                Rectangle {
                    width: applyLabel.implicitWidth + window.u * 28
                    height: window.u * 32
                    radius: window.u * 10
                    color: window.blue
                    scale: applyHov.containsMouse ? 1.04 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Text {
                        id: applyLabel
                        anchors.centerIn: parent
                        text: "Apply"
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
                        onClicked: window.confirmApply()
                    }
                }
            }
        }
    }

    // Click outside panel to dismiss.
    MouseArea {
        anchors.fill: parent
        visible: window.showPanel && !window.isApplying
        z: 150
        acceptedButtons: Qt.LeftButton
        onClicked: window.showPanel = false
    }

    // Keyboard
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

    Component.onCompleted: window.triggerIndexer()
}
