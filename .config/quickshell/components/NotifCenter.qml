import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell

Item {
    id: center

    property var rootRef: null
    property var svc: null

    focus: svc ? svc.centerOpen : false

    readonly property int panelWidth: 440
    readonly property int pad: 12
    readonly property int panelMaxHeight: Math.max(120, Math.round(center.height - 40))
    readonly property bool weekOn: rootRef && rootRef.weatherWeek && rootRef.weatherWeek.length > 0
    readonly property int weekHeight: 64

    // One storage list holds the mounted filesystems and the removable drives,
    // so a plugged-in stick is listed once instead of in two places.
    // These four numbers are the single source of truth for the section's
    // height: the rows are sized from the same constants this adds up.
    readonly property int storageHeaderHeight: 24
    readonly property int storageRowHeight: 40
    readonly property int storageGap: 4
    readonly property int storageSpacing: 8

    readonly property var removableList: rootRef && rootRef.removableDrives ? rootRef.removableDrives : []
    readonly property var storageRows: center.buildStorageRows()
    readonly property bool storageOn: center.storageRows.length > 0
    readonly property int storageHeight: {
        if (center.storageRows.length === 0) return 0
        return center.storageHeaderHeight
             + center.storageRows.length * (center.storageRowHeight + center.storageGap)
             + center.storageSpacing
    }
    readonly property int listMaxHeight: Math.max(64, center.panelMaxHeight - center.pad * 2 - 24 - 40 - center.storageHeight - (center.weekOn ? center.weekHeight + 8 : 0) - (center.mediaOn ? 168 + 8 : 0))
    readonly property bool mediaOn: rootRef && rootRef.mediaStatus !== "none"
    // YtX-style Android roles: flat surface card, theme text tokens.
    readonly property color panelColor: rootRef ? Qt.color(rootRef.colorOf("surface_container")) : "#1f2c34"
    readonly property color panelBorder: rootRef
        ? rootRef.withAlpha(Qt.color(rootRef.colorOf("outline_variant")), 0.5)
        : "#222d34"
    readonly property color fg: rootRef ? Qt.color(rootRef.colorOf("on_surface")) : "#e9edef"
    readonly property color muteFg: rootRef ? Qt.color(rootRef.colorOf("on_surface_variant")) : "#8696a0"
    readonly property color accent: rootRef ? Qt.color(rootRef.colorOf("widget_accent")) : "#ff8fb2"
    readonly property color signalAccent: "#ffffff"
    readonly property string iconFont: rootRef && rootRef.iconFont ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string uiFont: rootRef && rootRef.uiFont ? rootRef.uiFont : "Geist"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13


    // Removable-drive helpers (port of wian47.removable-drives, simple scope:
    // mount / open / unmount / safely eject USB sticks, SD cards, ext. drives).
    function fmtSizeGB(gb) {
        var n = parseFloat(gb)
        if (!isFinite(n) || n <= 0) return ""
        if (n >= 1024) return (n / 1024).toFixed(1) + " TB"
        return n.toFixed(n >= 100 ? 0 : 1) + " GB"
    }
    function driveName(d) {
        if (!d) return "Drive"
        var parts = []
        if (d.vendor) parts.push(d.vendor)
        if (d.model) parts.push(d.model)
        if (parts.length > 0) return parts.join(" ")
        if (d.volumes && d.volumes.length === 1 && d.volumes[0].label)
            return d.volumes[0].label
        return d.dev || "Drive"
    }
    function volTitle(v) {
        if (!v) return ""
        if (v.label) return v.label
        var fs = (v.fstype || "").toUpperCase()
        var dev = (v.path || "").replace("/dev/", "")
        return (fs ? fs + " · " : "") + dev
    }
    // Free space for a mount point, from the `df` list. Null when the
    // filesystem is not mounted or is not in that list.
    function diskInfo(mount) {
        if (!mount || !rootRef || !rootRef.mountedDisks) return null
        for (var i = 0; i < rootRef.mountedDisks.length; i++) {
            var m = rootRef.mountedDisks[i]
            if (m && m.mount === mount) return m
        }
        return null
    }

    // Flattens the mounted filesystems and the removable drives into one list
    // of row descriptors, so the section is a single Repeater.
    //   kind "disk"  a mounted filesystem        -> usage, bar, Open
    //   kind "drive" the physical device         -> name, size, Eject
    //   kind "vol"   one partition of a device   -> Mount or Open+Unmount
    // A mounted partition is skipped as a "disk" row, so a USB stick that
    // `df` also reports (it does for /mnt and /media mounts) shows up once.
    function buildStorageRows() {
        var rows = []
        var disks = (rootRef && rootRef.mountedDisks) ? rootRef.mountedDisks : []
        if (!(disks instanceof Array)) disks = []
        var drives = (center.removableList instanceof Array) ? center.removableList : []

        // Mount points already claimed by a removable partition.
        var claimed = {}
        for (var r = 0; r < drives.length; r++) {
            var drv = drives[r]
            var dvolumes = (drv && drv.volumes) ? drv.volumes : []
            for (var w = 0; w < dvolumes.length; w++) {
                if (dvolumes[w] && dvolumes[w].mount) claimed[dvolumes[w].mount] = true
            }
        }

        for (var i = 0; i < disks.length; i++) {
            var d = disks[i]
            if (!d || !d.mount || claimed[d.mount]) continue
            var pct = parseInt(d.pct, 10) || 0
            rows.push({
                kind: "disk",
                label: d.mount === "/" ? "System /" : d.mount,
                value: pct + "%",
                sub: d.free + "G/" + d.total + "G",
                progress: Math.max(0, Math.min(1, pct / 100)),
                mount: d.mount,
                mounted: true
            })
        }

        for (var j = 0; j < drives.length; j++) {
            var drive = drives[j]
            if (!drive) continue
            var size = center.fmtSizeGB(drive.sizeGB)
            var dev = (drive.dev || "").replace("/dev/", "")
            rows.push({
                kind: "drive",
                label: center.driveName(drive),
                sub: (size ? size + " · " : "") + dev,
                eject: drive.dev
            })
            var volumes = (drive.volumes) ? drive.volumes : []
            for (var k = 0; k < volumes.length; k++) {
                var v = volumes[k]
                if (!v) continue
                var info = v.mount ? center.diskInfo(v.mount) : null
                rows.push({
                    kind: "vol",
                    label: center.volTitle(v),
                    value: info ? info.pct + "%" : "",
                    sub: v.mount
                        ? (info ? v.mount + " · " + info.free + "G/" + info.total + "G" : v.mount)
                        : "Not mounted",
                    progress: info ? Math.max(0, Math.min(1, (parseInt(info.pct, 10) || 0) / 100)) : -1,
                    mount: v.mount,
                    devPath: v.path,
                    mounted: !!v.mount
                })
            }
        }
        return rows
    }

    // Refresh the drive list every time the center opens.
    Connections {
        target: center.svc
        enabled: center.svc !== null
        function onCenterOpenChanged() {
            if (center.svc && center.svc.centerOpen && center.rootRef)
                center.rootRef.refreshStorage()
        }
    }
    property real animProgress: (svc && svc.centerOpen && ready) ? 1.0 : 0.0
    Behavior on animProgress {
        Anim { type: Anim.Bouncy }
    }

    // Smooth opacity ramp decoupled from the bouncy slide: OutBack
    // finishes ~95% in the first 150ms, which reads as a pop.
    property real fadeProgress: (svc && svc.centerOpen && ready) ? 1.0 : 0.0
    Behavior on fadeProgress { Anim { type: Anim.SlowEffects } }

    // Starts false so a freshly loaded instance fades in (animProgress
    // would otherwise initialize straight to 1 with no transition).
    property bool ready: false
    Component.onCompleted: Qt.callLater(() => center.ready = true)

    Keys.onEscapePressed: event => {
        if (center.rootRef && center.rootRef.closeNotifCenter) center.rootRef.closeNotifCenter()
        else if (svc) svc.closeCenter()
        event.accepted = true
    }
    Keys.onDownPressed: event => {
        if (centerList.count > 0) centerList.incrementCurrentIndex()
        event.accepted = true
    }
    Keys.onUpPressed: event => {
        if (centerList.count > 0) centerList.decrementCurrentIndex()
        event.accepted = true
    }
    Keys.onReturnPressed: event => {
        var current = centerList.currentItem
        if (current && typeof current.activate === "function") current.activate()
        event.accepted = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (center.rootRef && center.rootRef.closeNotifCenter) center.rootRef.closeNotifCenter()
            else if (svc) svc.closeCenter()
        }
    }

    Rectangle {
        id: panel
        width: center.panelWidth
        height: Math.min(center.panelMaxHeight, panelColumn.implicitHeight + center.pad * 2)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.topMargin: rootRef ? rootRef.barHeight - 15 : 21

        color: center.panelColor
        radius: 10
        border.width: 0
        border.color: center.panelBorder
        clip: true
        // No drop shadow: the panel is flat against the desktop. The panel
        // used to run an offscreen MultiEffect pass just for this.


        opacity: center.fadeProgress
        transform: Translate { x: (1 - center.animProgress) * (panel.width + panel.anchors.rightMargin) }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: panelColumn
            anchors.fill: parent
            anchors.leftMargin: center.pad
            anchors.rightMargin: center.pad
            anchors.topMargin: center.pad
            anchors.bottomMargin: center.pad
            spacing: 8

            Rectangle {
                id: mediaCard
                Layout.fillWidth: true
                Layout.preferredHeight: 168
                Layout.minimumHeight: 168
                visible: rootRef && rootRef.mediaStatus !== "none"
                radius: 10
                clip: true
                antialiasing: true
                smooth: true
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.16)
                color: "transparent"

                 readonly property color mediaAccent: mediaCard.hasArt ? center.signalAccent : center.fg
                property string mediaTitle: rootRef ? (rootRef.mediaTitle || "") : ""
                property string mediaArtist: rootRef ? (rootRef.mediaArtist || "") : ""
                property bool hasArt: rootRef && !!rootRef.mediaArt
                property real progress: rootRef && rootRef.mediaLenMs > 0
                    ? Math.max(0, Math.min(1, rootRef.mediaPosMs / rootRef.mediaLenMs))
                    : 0

                function fmtTime(ms) {
                    if (!isFinite(ms) || ms <= 0) return "0:00"
                    var s = Math.floor(ms / 1000)
                    var m = Math.floor(s / 60)
                    s = s % 60
                    return m + ":" + (s < 10 ? "0" : "") + s
                }

                Rectangle {
                    id: mediaArtMask
                    anchors.fill: parent
                    anchors.margins: -5
                    radius: 10
                    color: "#ffffff"
                    antialiasing: true
                    smooth: true
                    visible: false
                    layer.enabled: true
                }

                Image {
                    anchors.fill: parent
                    source: mediaCard.hasArt ? (rootRef.mediaArt || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                    antialiasing: true
                    smooth: true
                    mipmap: true
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: mediaArtMask }
                    visible: source !== ""
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 0
                    radius: mediaCard.radius
                    antialiasing: true
                    smooth: true
                    color: mediaCard.hasArt
                        ? Qt.rgba(0.03, 0.04, 0.05, 0.55)
                        : Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.05)
                }

                QIcon {
                    anchors.centerIn: parent
                    visible: !mediaCard.hasArt
                    source: Qt.resolvedUrl("../assets/icons/music.svg")
                    color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.75)
                    iconSize: 32
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Item { Layout.fillHeight: true }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Txt {
                            Layout.fillWidth: true
                            text: mediaCard.mediaTitle
                            color: mediaCard.hasArt ? "#ffffff" : center.fg
                            sizeDelta: 1
                            weight_: Font.Bold
                            maximumLineCount: 2
                        }

                        Txt {
                            Layout.fillWidth: true
                            text: mediaCard.mediaArtist
                            color: mediaCard.hasArt ? Qt.rgba(1, 1, 1, 0.7) : center.muteFg
                            sizeDelta: -3
                            font.letterSpacing: 0
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12

                            Canvas {
                                id: waveCanvas
                                anchors.fill: parent
                                antialiasing: true

                                readonly property real waveLength: 64
                                readonly property real amplitude: 3.5
                                readonly property real thickness: 2
                                property real phase: 0
                                property bool playing: rootRef && rootRef.mediaStatus === "Playing"
                                property bool hovered: seekArea.containsMouse || seekArea.dragging

                                onPlayingChanged: waveCanvas.requestPaint()
                                onHoveredChanged: waveCanvas.requestPaint()
                                onWidthChanged: waveCanvas.requestPaint()
                                onHeightChanged: waveCanvas.requestPaint()

                                function ampFactor(x, edge, taper) {
                                    var d = edge - x
                                    if (d >= taper) return 1
                                    if (d <= 0) return 0
                                    var k = d / taper
                                    return k * k * (3 - 2 * k)
                                }

                                onPaint: () => {
                                    var ctx = waveCanvas.getContext("2d")
                                    var w = waveCanvas.width
                                    var h = waveCanvas.height
                                    ctx.clearRect(0, 0, w, h)
                                    if (w <= 0 || h <= 0) return

                                    var edge = Math.max(0, Math.min(w, mediaCard.progress * w))
                                    var midY = h / 2
                                    var taper = Math.max(30, Math.min(90, w * 0.12))
                                    var freq = 2 * Math.PI / waveCanvas.waveLength

                                    ctx.lineWidth = waveCanvas.thickness
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"

                                    if (edge < w) {
                                        ctx.strokeStyle = Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.22)
                                        ctx.beginPath()
                                        ctx.moveTo(edge, midY)
                                        ctx.lineTo(w, midY)
                                        ctx.stroke()
                                    }

                                    ctx.strokeStyle = mediaCard.mediaAccent
                                    ctx.beginPath()
                                    for (var i = 0; i <= w; i += 2) {
                                        var amp = waveCanvas.amplitude * waveCanvas.ampFactor(i, edge, taper)
                                        var y = midY + Math.sin(i * freq + waveCanvas.phase) * amp
                                        if (i === 0) ctx.moveTo(i, y)
                                        else ctx.lineTo(i, y)
                                    }
                                    ctx.stroke()

                                    var thumbR = waveCanvas.hovered ? 5 : 3.5
                                        ctx.fillStyle = mediaCard.mediaAccent
                                        ctx.beginPath()
                                        ctx.arc(edge, midY, thumbR, 0, 2 * Math.PI)
                                        ctx.fill()
                                        ctx.fillStyle = center.fg
                                        ctx.beginPath()
                                        ctx.arc(edge, midY, 2.5, 0, 2 * Math.PI)
                                        ctx.fill()
                                }
                            }

                            Timer {
                                interval: 50
                                repeat: true
                                running: waveCanvas.playing && waveCanvas.visible && center.visible
                                    && center.svc !== null && center.svc.centerOpen
                                onTriggered: () => {
                                    waveCanvas.phase += 0.14
                                    waveCanvas.requestPaint()
                                }
                            }

                            MouseArea {
                                id: seekArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                property bool dragging: false

                                function seekTo(posX) {
                                    if (!rootRef || rootRef.mediaLenMs <= 0) return
                                    var ratio = Math.max(0, Math.min(1, posX / seekArea.width))
                                    var targetMs = Math.round(ratio * rootRef.mediaLenMs)
                                    Quickshell.execDetached(["playerctl", "position", String(targetMs / 1000)])
                                    rootRef.mediaPosMs = targetMs
                                }

                                onPressed: (mouse) => {
                                    dragging = true
                                    seekTo(mouse.x)
                                }
                                onPositionChanged: (mouse) => {
                                    if (dragging) seekTo(mouse.x)
                                }
                                onReleased: (mouse) => {
                                    dragging = false
                                }
}
                    }

                    RowLayout {
                        spacing: 12
                        Layout.alignment: Qt.AlignVCenter

                        Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }

                        MediaBtn {
                            btnSize: 26
                            iconSource: Qt.resolvedUrl("../assets/icons/prev.svg")
                            onTapped: rootRef ? Quickshell.execDetached(["playerctl", "previous"]) : {}
                        }

                        MediaBtn {
                            btnSize: 36
                            iconSource: rootRef && rootRef.mediaStatus === "Playing" ? Qt.resolvedUrl("../assets/icons/pause.svg") : Qt.resolvedUrl("../assets/icons/play.svg")
                            accent: false
                            onTapped: rootRef ? Quickshell.execDetached(["playerctl", "play-pause"]) : {}
                        }

                        MediaBtn {
                            btnSize: 26
                            iconSource: Qt.resolvedUrl("../assets/icons/next.svg")
                            onTapped: rootRef ? Quickshell.execDetached(["playerctl", "next"]) : {}
                        }

                        Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
                    }
                }
            }

            // The featured card of the panel, but on the same surface as a
            // storage drive row: a flat wash of the foreground plus a hairline,
            // rather than the mauve tonal pill the bar uses.
            Rectangle {
                id: weekWidget
                Layout.fillWidth: true
                Layout.preferredHeight: center.weekHeight
                Layout.minimumHeight: center.weekHeight
                visible: center.weekOn
                radius: 8
                color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.05)
                border.width: 1
                border.color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.09)
                clip: true

                readonly property color wfg: center.fg
                readonly property color wdim: center.muteFg
                readonly property int cardPad: 10

                // Everything sits on one line: the reading, its label and
                // place, then the forecast pushed to the far right.
                Item {
                    anchors.fill: parent
                    anchors.margins: weekWidget.cardPad

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        Txt {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.maximumWidth: 64
                            text: rootRef ? rootRef.weatherTempOnly() : ""
                            color: weekWidget.wfg
                            sizeDelta: 9
                            weight_: Font.DemiBold
                        }

                        Txt {
                            Layout.alignment: Qt.AlignVCenter
                            visible: text.length > 0
                            text: rootRef ? rootRef.weatherLabel() : ""
                            color: weekWidget.wfg
                            sizeDelta: -1
                        }

                        Txt {
                            Layout.alignment: Qt.AlignVCenter
                            visible: text.length > 0
                            text: {
                                var bits = []
                                if (rootRef && rootRef.weatherFeels) bits.push("Feels " + rootRef.weatherFeels)
                                if (rootRef && rootRef.weatherCity) bits.push(rootRef.weatherCity)
                                return bits.join(" · ")
                            }
                            color: weekWidget.wdim
                            sizeDelta: -3
                        }

                        // Pushes the forecast to the trailing edge.
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                        }

                        // The next four days, so today is not repeated next
                        // to the current reading.
                        RowLayout {
                            spacing: 4

                            Repeater {
                                model: rootRef ? rootRef.weatherWeek.slice(1, 5) : []
                                delegate: ColumnLayout {
                                    Layout.preferredWidth: 32
                                    spacing: 1

                                    Txt {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData.day
                                        color: weekWidget.wdim
                                        sizeDelta: -3
                                    }

                                    Txt {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: rootRef ? rootRef.hourGlyph(modelData.key, true) : ""
                                        color: weekWidget.wdim
                                        glyphFont: true
                                    }

                                    Txt {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData.max + "°"
                                        color: weekWidget.wfg
                                        sizeDelta: -2
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Storage: the mounted filesystems and the removable drives in
            // one flat list, each row a single line.
            ColumnLayout {
                Layout.fillWidth: true
                visible: center.storageOn
                spacing: center.storageGap

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: center.storageHeaderHeight
                    spacing: 6

                    QIcon {
                        source: Qt.resolvedUrl("../assets/icons/y2k-folder.svg")
                        color: center.muteFg
                        iconSize: center.fontSize + 2
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Txt {
                        Layout.fillWidth: true
                        text: "Storage"
                        dim: true
                        sizeDelta: 0
                        weight_: Font.DemiBold
                    }

                    HeaderBtn {
                        iconSource: Qt.resolvedUrl("../assets/icons/refresh.svg")
                        active: false
                        onTapped: { if (rootRef) rootRef.refreshStorage() }
                    }
                }

                Repeater {
                    model: center.storageRows
                    delegate: StorageRow {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: center.storageRowHeight
                        Layout.minimumHeight: center.storageRowHeight
                        rowData: modelData
                    }
                }
            }

            // Notifications header: sits directly above the list.
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                Layout.minimumHeight: 24
                spacing: 6

                QIcon {
                    source: Qt.resolvedUrl("../assets/icons/bell.svg")
                    color: center.fg
                    iconSize: center.fontSize + 3
                    Layout.alignment: Qt.AlignVCenter
                }

                Txt {
                    text: "Notifications"
                    sizeDelta: 1
                    weight_: Font.DemiBold
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    visible: svc && svc.unreadCount > 0
                    Layout.preferredHeight: 18
                    implicitWidth: unreadLabel.implicitWidth + 12
                    radius: 10
                    color: center.accent

                    Txt {
                        id: unreadLabel
                        anchors.centerIn: parent
                        text: svc ? String(svc.unreadCount) : ""
                        color: rootRef ? rootRef.contrastColor(center.accent) : "#000000"
                        sizeDelta: -2
                        weight_: Font.DemiBold
                    }
                }

                HeaderBtn {
                    iconSource: Qt.resolvedUrl("../assets/icons/bell.svg")
                    active: svc ? svc.dnd : false
                    onTapped: { if (svc) svc.dnd = !svc.dnd }
                }

                HeaderBtn {
                    iconSource: Qt.resolvedUrl("../assets/icons/trash.svg")
                    enabled_: svc && svc.history.count > 0
                    active: false
                    onTapped: { if (svc) svc.clearAll() }
                }
            }

            Rectangle {
                id: listWrap
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 64
                // Exact: the list fills this wrapper edge to edge, so no
                // padding is added here.
                Layout.preferredHeight: Math.min(centerList.contentHeight, center.listMaxHeight)
                visible: centerList.count > 0
                radius: 10
                color: "transparent"
                border.width: 0
                border.color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.09)
                clip: true

            ListView {
                id: centerList
                // No side insets: notification cards are the same width as the
                // weather and storage cards above them. The scrollbar overlays
                // the trailing edge instead of stealing width from the list.
                anchors.fill: parent
                model: svc ? svc.history : []
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds

                add: Transition {
                    Anim { property: "opacity"; from: 0; to: 1; type: Anim.DefaultEffects }
                    Anim { property: "x"; from: 28; to: 0; type: Anim.DefaultSpatial }
                }
                displaced: Transition {
                    Anim { property: "y"; type: Anim.BouncyFast }
                }
                flickableDirection: Flickable.VerticalFlick
                clip: true

                ScrollBar.vertical: ScrollBar {
                    parent: listWrap
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    // Sits just inside the card's right edge, clear of the
                    // close button in the card's top-right corner.
                    anchors.rightMargin: 3
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    width: 4
                    policy: ScrollBar.AsNeeded
                    background: Item {}
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 10
                         color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.25)
                    }
                }

                onCountChanged: {
                    if (centerList.count === 0) centerList.currentIndex = -1
                    else if (centerList.currentIndex >= centerList.count)
                        centerList.currentIndex = centerList.count - 1
                }

                onCurrentIndexChanged: {
                    if (centerList.currentIndex >= 0)
                        centerList.positionViewAtIndex(centerList.currentIndex, ListView.Contain)
                }

                Component.onCompleted: {
                    if (centerList.count > 0) centerList.currentIndex = 0
                }

                delegate: NotificationCard {
                    width: centerList.width
                    rootRef: center.rootRef
                    svc: center.svc
                    nData: model
                    context: "center"
                    z: centerList.currentIndex === index ? 2 : 1
                    onCardSelected: centerList.currentIndex = index
                }
            }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                visible: centerList.count === 0
                spacing: 8
                opacity: 0.6

                QIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl("../assets/icons/y2k-moon-star.svg")
                    color: center.fg
                    iconSize: center.fontSize + 4
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "All clear"
                }

                QIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl("../assets/icons/y2k-sparkle.svg")
                    color: center.fg
                    iconSize: center.fontSize + 2
                }
            }

        }

    // Every label in the panel is the same Text with a size offset and a
    // weight, so they all come from here instead of being spelled out.
    component Txt: Text {
        // Offset from center.fontSize, so the panel scales as one piece.
        property int sizeDelta: 0
        property int weight_: Font.Normal
        property bool dim: false
        // Glyphs (Symbols Nerd Font) rather than the UI face.
        property bool glyphFont: false

        color: dim ? center.muteFg : center.fg
        font.family: glyphFont ? center.iconFont : center.uiFont
        font.pixelSize: center.fontSize + sizeDelta
        font.weight: weight_
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    component MediaBtn: Item {
        id: btn
        property url iconSource
        property bool accent: false
        property int btnSize: 30
        signal tapped()

        Layout.preferredWidth: btn.btnSize
        Layout.preferredHeight: btn.btnSize

        Rectangle {
            anchors.centerIn: parent
            width: btn.btnSize
            height: btn.btnSize
            radius: 10
            color: btn.accent
                ? Qt.color(center.signalAccent)
                : (hoverArea.containsMouse ? Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.1) : "transparent")

            QIcon {
                anchors.centerIn: parent
                source: btn.iconSource
                color: btn.accent ? "#15161a" : center.fg
                iconSize: center.fontSize + (btn.accent ? 8 : 4)
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btn.tapped()
            }
        }
    }

    component HeaderBtn: Item {
        id: btn
        property url iconSource
        property bool active: false
        property bool enabled_: true
        signal tapped()

        Layout.preferredWidth: 26
        Layout.preferredHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: !btn.enabled_
                ? Qt.rgba(1, 1, 1, 0.04)
                : btn.active
                    ? Qt.rgba(center.accent.r, center.accent.g, center.accent.b, 0.35)
                    : (hoverArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
            Behavior on color { CAnim { type: CAnim.FastEffects } }
        }

        QIcon {
            anchors.centerIn: parent
            source: btn.iconSource
            color: !btn.enabled_ ? Qt.rgba(1, 1, 1, 0.25) : center.fg
            iconSize: center.fontSize + 2
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            enabled: btn.enabled_
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.tapped()
        }
    }

    // Small text pill button for drive actions (Mount / Open / Unmount / Eject).
    component DriveBtn: Item {
        id: dbtn
        property string label: ""
        property bool accent: false
        signal tapped()

        Layout.preferredHeight: 24
        Layout.minimumWidth: 54
        implicitWidth: Math.max(54, dbtnLabel.implicitWidth + 16)

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: dbtn.accent
                ? Qt.rgba(center.accent.r, center.accent.g, center.accent.b, 0.28)
                : (dbHover.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
            border.width: 1
            border.color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.14)
            Behavior on color { CAnim { type: CAnim.FastEffects } }

            Txt {
                id: dbtnLabel
                anchors.centerIn: parent
                text: dbtn.label
                sizeDelta: -1
                weight_: Font.DemiBold
            }

            MouseArea {
                id: dbHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: dbtn.tapped()
            }
        }
    }

    // One line of the storage list. The row's kind decides what it shows:
    // a filesystem is usage + bar + Open, a device is name + size + Eject,
    // a partition is Mount when it is out and Open + Unmount when it is in.
    component StorageRow: Rectangle {
        id: row
        property var rowData: ({})
        readonly property var data_: row.rowData || ({})
        readonly property bool isDrive: data_.kind === "drive"
        readonly property bool isVol: data_.kind === "vol"
        readonly property bool isMounted: !!data_.mounted
        // Partitions read as an inset under the device they belong to.
        readonly property real inset: row.isVol ? 14 : 0

        Layout.fillHeight: false
        radius: 8
        color: row.isDrive
            ? Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.05)
            : "transparent"
        border.width: row.isDrive ? 1 : 0
        border.color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.09)
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10 + row.inset
            anchors.rightMargin: 10
            spacing: 8

            // Usage percentage, only where there is a filesystem to measure.
            Txt {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 38
                visible: (row.data_.value || "") !== ""
                text: row.data_.value || ""
                sizeDelta: row.isDrive ? -2 : 1
                weight_: Font.DemiBold
            }

            Txt {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 108
                text: row.data_.label || ""
                sizeDelta: row.isDrive ? 0 : -1
                weight_: row.isDrive ? Font.DemiBold : Font.Medium
            }

            Txt {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                text: row.data_.sub || ""
                dim: true
                sizeDelta: -3
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 28
                Layout.preferredHeight: 3
                visible: row.data_.progress !== undefined && row.data_.progress >= 0
                radius: 10
                color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.18)
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.max(0, Math.min(1, row.data_.progress || 0))
                    color: center.fg
                }
            }

            DriveBtn {
                Layout.alignment: Qt.AlignVCenter
                visible: row.isVol && !row.isMounted
                label: "Mount"
                onTapped: { if (rootRef) rootRef.mountVolume(row.data_.devPath) }
            }
            DriveBtn {
                Layout.alignment: Qt.AlignVCenter
                visible: !row.isDrive && row.isMounted
                label: "Open"
                onTapped: { if (rootRef) rootRef.openMount(row.data_.mount) }
            }
            DriveBtn {
                Layout.alignment: Qt.AlignVCenter
                visible: row.isVol && row.isMounted
                label: "Unmount"
                onTapped: { if (rootRef) rootRef.unmountVolume(row.data_.devPath) }
            }
            DriveBtn {
                Layout.alignment: Qt.AlignVCenter
                visible: row.isDrive
                label: "Eject"
                accent: true
                onTapped: { if (rootRef) rootRef.ejectDrive(row.data_.eject) }
            }
        }
    }


}
}
