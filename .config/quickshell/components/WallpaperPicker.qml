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
    readonly property real cornerRadius: 12 * u
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
        if (window.isApplying || window.showPanel || window.displayModel.length === 0) return
        var next = view.currentIndex + direction
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
    property string currentMode: "dark"
    property string applyMode: currentMode
    property string applyError: ""

    function openPanel(index) {
        if (window.isApplying || window.showPanel || index < 0 || index >= window.displayModel.length) return
        window.selectedItem = window.displayModel[index]
        window.applyMode = window.currentMode
        window.applyError = ""
        window.showPanel = true
    }

    property var applyArgs: []
    function confirmApply() {
        if (!window.selectedItem || window.isApplying) return
        window.applyError = ""
        window.isApplying = true
        window.applyArgs = ["bash", window.scriptDir + "/wallpaper_apply.sh",
                            window.selectedItem.filePath, window.applyMode]
        applyProc.running = true
    }

    Process {
        id: applyProc
        running: false
        command: window.applyArgs
        onExited: code => {
            window.isApplying = false
            if (code !== 0) {
                window.applyError = "Could not apply wallpaper. Please try again."
                console.warn("Wallpaper apply failed with exit code", code)
                return
            }
            window.currentPath = window.selectedItem.filePath
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
                window.currentPath = t
                window.jumpToCurrent()
            }
        }
    }

    onVisible_Changed: {
        if (!window.isApplying) {
            window.showPanel = false
            window.selectedItem = null
            window.applyError = ""
        }
        if (window.visible_) {
            currentReader.running = false
            currentReader.running = true
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
        currentIndex: 0
        cacheBuffer: window.itemWidth * 2

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

            Behavior on width { enabled: window.isLoaded && !window.isApplying; Anim { type: Anim.BouncyFast } }
            Behavior on height { enabled: window.isLoaded && !window.isApplying; Anim { type: Anim.BouncyFast } }

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
                        border.width: 0
                        Behavior on color { CAnim { } }

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
                        border.width: 0
                        Behavior on color { CAnim { } }

                        MouseArea {
                            id: swatchMouse
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
                text: window.selectedItem ? window.selectedItem.fileName : ""
                width: parent.width
                color: window.textColor
                font.family: window.uiFont
                font.pixelSize: window.u * 13
                font.bold: true
                elide: Text.ElideMiddle
            }

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
                        Behavior on color { CAnim { } }
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
                    radius: window.u * 10
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
                        onClicked: window.showPanel = false
                    }
                }

                Rectangle {
                    width: applyLabel.implicitWidth + window.u * 28
                    height: window.u * 32
                    radius: window.u * 10
                    color: window.blue
                    Text {
                        id: applyLabel
                        anchors.centerIn: parent
                        text: window.isApplying ? "Applying..." : "Apply"
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
