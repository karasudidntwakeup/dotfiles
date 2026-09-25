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
    readonly property int pad: 14
    readonly property int panelMaxHeight: Math.max(120, Math.round(center.height - 40))
    readonly property bool weekOn: rootRef && rootRef.weatherWeek && rootRef.weatherWeek.length > 0
    readonly property int weekHeight: 288
    readonly property int mountedDiskCount: rootRef && rootRef.mountedDisks ? rootRef.mountedDisks.length : 0
    readonly property int mountedDisksHeight: Math.ceil(center.mountedDiskCount / 2) * 106
    readonly property var removableList: rootRef && rootRef.removableDrives ? rootRef.removableDrives : []
    readonly property int removableCount: center.removableList.length
    // Header (~30) + per-drive card (~64 + 40/volume), + spacing.
    readonly property int removableHeight: {
        if (center.removableCount === 0) return 0
        var h = 38
        for (var i = 0; i < center.removableList.length; i++) {
            var d = center.removableList[i]
            var vols = (d && d.volumes) ? d.volumes.length : 0
            h += 72 + Math.max(1, vols) * 40 + 8
        }
        return h
    }
    readonly property int listMaxHeight: Math.max(64, center.panelMaxHeight - center.pad * 2 - 30 - 40 - center.mountedDisksHeight - center.removableHeight - (center.weekOn ? center.weekHeight + 10 : 0) - (center.mediaOn ? 224 + 10 : 0))
    readonly property bool mediaOn: rootRef && rootRef.mediaStatus !== "none"
    readonly property string cardTile: "notif_card"
    // Same shading as the bar pills so the background matches them.
    readonly property color panelColor: rootRef
        ? rootRef.tonalPillColor(rootRef.pillColor(cardTile))
        : "#15161a"
    readonly property color panelBorder: rootRef ? rootRef.withAlpha(Qt.color(rootRef.colorOf("widget_border")), rootRef.qsLight ? 0.7 : 0.5) : "#ffffff33"
    readonly property color fg: rootRef ? rootRef.contrastColor(center.panelColor) : "#ffffff"
    readonly property color muteFg: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.72)
    readonly property color accent: rootRef ? Qt.color(rootRef.colorOf("widget_accent")) : "#ff8fb2"
    readonly property color signalAccent: "#ffffff"
    readonly property string iconFont: rootRef && rootRef.iconFont ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string uiFont: rootRef && rootRef.uiFont ? rootRef.uiFont : "Geist"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13

    function weekGlyph(key) {
        switch (key) {
        case "sun": return ""
        case "partly": return ""
        case "cloud": return ""
        case "rain": return ""
        case "storm": return ""
        case "snow": return ""
        case "fog": return ""
        default: return ""
        }
    }

    readonly property int weekLo: {
        var days = rootRef ? rootRef.weatherWeek : []
        if (!days || days.length === 0) return 0
        var lo = days[0].min
        for (var i = 1; i < days.length; i++) lo = Math.min(lo, days[i].min)
        return lo
    }
    readonly property int weekHi: {
        var days = rootRef ? rootRef.weatherWeek : []
        if (!days || days.length === 0) return 1
        var hi = days[0].max
        for (var i = 1; i < days.length; i++) hi = Math.max(hi, days[i].max)
        return Math.max(hi, center.weekLo + 1)
    }
    function weekFrac(min, max) {
        var span = Math.max(1, center.weekHi - center.weekLo)
        return [(min - center.weekLo) / span, Math.max(0.06, (max - min) / span)]
    }

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
    function diskFreeText(mount) {
        if (!mount || !rootRef || !rootRef.mountedDisks) return ""
        for (var i = 0; i < rootRef.mountedDisks.length; i++) {
            var m = rootRef.mountedDisks[i]
            if (m && m.mount === mount) return m.free + "G free of " + m.total + "G"
        }
        return ""
    }

    // Refresh the drive list every time the center opens.
    Connections {
        target: center.svc
        enabled: center.svc !== null
        function onCenterOpenChanged() {
            if (center.svc && center.svc.centerOpen && center.rootRef)
                center.rootRef.refreshRemovable()
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
        id: backdropArea
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
        radius: 0
        border.width: 0
        border.color: center.panelBorder
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: Quickshell.env("QS_NO_SHADOW") !== "1"
            shadowBlur: 0.9
            blurMax: 28
            shadowHorizontalOffset: 5
            shadowVerticalOffset: 10
            shadowColor: Qt.rgba(0, 0, 0, 0.9)
            shadowOpacity: 0.95
        }


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
            spacing: 10

            Rectangle {
                id: mediaCard
                Layout.fillWidth: true
                Layout.preferredHeight: 224
                Layout.minimumHeight: 224
                visible: rootRef && rootRef.mediaStatus !== "none"
                radius: 0
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
                    radius: 0
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
                    iconSize: 40
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Item { Layout.fillHeight: true }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            Layout.fillWidth: true
                            text: mediaCard.mediaTitle
                             color: mediaCard.hasArt ? "#ffffff" : center.fg
                             font.family: center.uiFont
                            font.pixelSize: center.fontSize + 1
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            maximumLineCount: 2
                        }

                        Text {
                            Layout.fillWidth: true
                            text: mediaCard.mediaArtist
                             color: mediaCard.hasArt ? Qt.rgba(1, 1, 1, 0.7) : center.muteFg
                             font.family: center.uiFont
                            font.pixelSize: 10
                            font.letterSpacing: 0
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16

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
                                id: waveTimer
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
                        spacing: 16
                        Layout.alignment: Qt.AlignVCenter

                        Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }

                        MediaBtn {
                            btnSize: 30
                            iconSource: Qt.resolvedUrl("../assets/icons/prev.svg")
                            onTapped: rootRef ? Quickshell.execDetached(["playerctl", "previous"]) : {}
                        }

                        MediaBtn {
                            btnSize: 44
                            iconSource: rootRef && rootRef.mediaStatus === "Playing" ? Qt.resolvedUrl("../assets/icons/pause.svg") : Qt.resolvedUrl("../assets/icons/play.svg")
                            accent: false
                            onTapped: rootRef ? Quickshell.execDetached(["playerctl", "play-pause"]) : {}
                        }

                        MediaBtn {
                            btnSize: 30
                            iconSource: Qt.resolvedUrl("../assets/icons/next.svg")
                            onTapped: rootRef ? Quickshell.execDetached(["playerctl", "next"]) : {}
                        }

                        Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
                    }
                }
            }

            // Week forecast widget: tinted like the weather tile,
            // with day rows and min/max range bars.
            Rectangle {
                id: weekWidget
                Layout.fillWidth: true
                Layout.preferredHeight: center.weekHeight
                Layout.minimumHeight: center.weekHeight
                visible: center.weekOn
                radius: 0
                color: rootRef ? rootRef.tonalPillColor(rootRef.pillColor("primary_fixed_dim")) : "#1a1b1e"
                border.width: 0
                clip: true

                readonly property color wfg: rootRef ? rootRef.pillForeground(weekWidget.color) : center.fg
                readonly property color wdim: Qt.rgba(wfg.r, wfg.g, wfg.b, 0.68)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        spacing: 8

                        Text {
                            visible: rootRef ? !rootRef.weatherIsY2kMoon() : false
                            Layout.alignment: Qt.AlignVCenter
                            text: rootRef ? rootRef.weatherGlyph() : ""
                            color: weekWidget.wfg
                            font.family: center.iconFont
                            font.pixelSize: center.fontSize + 6
                        }

                        QIcon {
                            visible: rootRef ? rootRef.weatherIsY2kMoon() : false
                            Layout.alignment: Qt.AlignVCenter
                            source: Qt.resolvedUrl("../assets/icons/y2k-moon-star.svg")
                            color: weekWidget.wfg
                            iconSize: center.fontSize + 6
                        }

                        Text {
                            Layout.fillWidth: true
                            text: rootRef ? rootRef.weatherText : ""
                            color: weekWidget.wfg
                            font.family: center.uiFont
                            font.pixelSize: center.fontSize + 4
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 0
                            color: weekRefreshHover.containsMouse ? Qt.rgba(weekWidget.wfg.r, weekWidget.wfg.g, weekWidget.wfg.b, 0.15) : "transparent"

                            QIcon {
                                anchors.centerIn: parent
                                source: Qt.resolvedUrl("../assets/icons/refresh.svg")
                                color: weekWidget.wfg
                                iconSize: center.fontSize + 2
                            }

                            MouseArea {
                                id: weekRefreshHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { if (rootRef) rootRef.refreshWeather() }
                            }
                        }
                    }

                    Repeater {
                        model: rootRef ? rootRef.weatherWeek : []
                        delegate: RowLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            spacing: 8

                            Text {
                                Layout.preferredWidth: 52
                                text: modelData.day
                                color: weekWidget.wfg
                                opacity: index === 0 ? 1.0 : 0.7
                                font.family: center.uiFont
                                font.pixelSize: center.fontSize
                                font.weight: index === 0 ? Font.Bold : Font.Normal
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.preferredWidth: 22
                                horizontalAlignment: Text.AlignHCenter
                                text: center.weekGlyph(modelData.key)
                                color: weekWidget.wfg
                                font.family: center.iconFont
                                font.pixelSize: center.fontSize + 4
                            }
                            Text {
                                Layout.preferredWidth: 34
                                horizontalAlignment: Text.AlignRight
                                text: modelData.min + "°"
                                color: weekWidget.wdim
                                font.family: center.uiFont
                                font.pixelSize: center.fontSize
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 4

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 0
                                    color: Qt.rgba(weekWidget.wfg.r, weekWidget.wfg.g, weekWidget.wfg.b, 0.18)
                                }
                                Rectangle {
                                    height: 4
                                    radius: 0
                                    color: weekWidget.wfg
                                    width: parent.width * center.weekFrac(modelData.min, modelData.max)[1]
                                    x: parent.width * center.weekFrac(modelData.min, modelData.max)[0]
                                }
                            }
                            Text {
                                Layout.preferredWidth: 34
                                text: modelData.max + "°"
                                color: weekWidget.wfg
                                font.family: center.uiFont
                                font.pixelSize: center.fontSize
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            // Mounted disks, two tiles per row.
            Grid {
                Layout.fillWidth: true
                visible: center.mountedDiskCount > 0
                columns: 2
                rowSpacing: 10
                columnSpacing: 8

                Repeater {
                    model: rootRef && rootRef.mountedDisks ? rootRef.mountedDisks : []
                    delegate: InfoWidget {
                        width: Math.round((center.panelWidth - center.pad * 2 - 8) / 2)
                        height: 96
                        visible: true
                        tintName: "tertiary_container"
                        title: modelData.pct + "%"
                        subtitle: modelData.free + "G free of " + modelData.total + "G"
                        caption: modelData.mount === "/" ? "System /" : modelData.mount
                        glyph: ""
                        isY2kMoon: false
                        progress: Math.max(0, Math.min(1, (modelData.pct || 0) / 100))
                    }
                }
            }

            // Removable drives (USB sticks, SD cards, external drives):
            // mount, open, unmount and safely eject without a terminal.
            ColumnLayout {
                Layout.fillWidth: true
                visible: center.removableCount > 0
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    spacing: 8

                    QIcon {
                        source: Qt.resolvedUrl("../assets/icons/y2k-folder.svg")
                        color: center.muteFg
                        iconSize: center.fontSize + 4
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Removable" + (center.removableCount > 1 ? " · " + center.removableCount : "")
                        color: center.muteFg
                        font.family: center.uiFont
                        font.pixelSize: center.fontSize
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    HeaderBtn {
                        iconSource: Qt.resolvedUrl("../assets/icons/refresh.svg")
                        active: false
                        onTapped: { if (rootRef) rootRef.refreshRemovable() }
                    }
                }

                Repeater {
                    model: center.removableList
                    delegate: Rectangle {
                        required property var modelData
                        property var drive: modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: driveCol.implicitHeight + 20
                        radius: 0
                        color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.09)
                        clip: true

                        ColumnLayout {
                            id: driveCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: center.driveName(drive)
                                        color: center.fg
                                        font.family: center.uiFont
                                        font.pixelSize: center.fontSize + 1
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: {
                                            var size = center.fmtSizeGB(drive.sizeGB)
                                            var dev = (drive.dev || "").replace("/dev/", "")
                                            return (size ? size + " · " : "") + dev
                                        }
                                        color: center.muteFg
                                        font.family: center.uiFont
                                        font.pixelSize: center.fontSize - 2
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }

                                DriveBtn {
                                    label: "Eject"
                                    accent: true
                                    onTapped: { if (rootRef) rootRef.ejectDrive(drive.dev) }
                                }
                            }

                            Repeater {
                                model: drive.volumes || []
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 6
                                        Layout.fillHeight: true
                                        radius: 0
                                        color: modelData.mount ? center.accent : Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.25)
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        Text {
                                            Layout.fillWidth: true
                                            text: center.volTitle(modelData)
                                            color: center.fg
                                            font.family: center.uiFont
                                            font.pixelSize: center.fontSize
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: text.length > 0
                                            text: modelData.mount
                                                ? (modelData.mount + (center.diskFreeText(modelData.mount).length > 0 ? " · " + center.diskFreeText(modelData.mount) : ""))
                                                : "Not mounted"
                                            color: center.muteFg
                                            font.family: center.uiFont
                                            font.pixelSize: center.fontSize - 2
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }

                                    DriveBtn {
                                        visible: !modelData.mount
                                        label: "Mount"
                                        onTapped: { if (rootRef) rootRef.mountVolume(modelData.path) }
                                    }
                                    DriveBtn {
                                        visible: !!modelData.mount
                                        label: "Open"
                                        onTapped: { if (rootRef) rootRef.openMount(modelData.mount) }
                                    }
                                    DriveBtn {
                                        visible: !!modelData.mount
                                        label: "Unmount"
                                        onTapped: { if (rootRef) rootRef.unmountVolume(modelData.path) }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Notifications header: sits directly above the list.
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                Layout.minimumHeight: 30
                spacing: 8

                QIcon {
                    source: Qt.resolvedUrl("../assets/icons/bell.svg")
                    color: center.fg
                    iconSize: center.fontSize + 5
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Notifications"
                    color: center.fg
                    font.family: center.uiFont
                    font.pixelSize: center.fontSize + 2
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    visible: svc && svc.unreadCount > 0
                    Layout.preferredHeight: 20
                    implicitWidth: unreadLabel.implicitWidth + 12
                    radius: 0
                    color: center.accent

                    Text {
                        id: unreadLabel
                        anchors.centerIn: parent
                        text: svc ? String(svc.unreadCount) : ""
                        color: rootRef ? rootRef.contrastColor(center.accent) : "#000000"
                        font.family: center.uiFont
                        font.pixelSize: center.fontSize - 2
                        font.weight: Font.DemiBold
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
                Layout.preferredHeight: Math.min(centerList.contentHeight, center.listMaxHeight) + 16
                visible: centerList.count > 0
                radius: 0
                color: "transparent"
                border.width: 0
                border.color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.09)
                clip: true

            ListView {
                id: centerList
                anchors.fill: parent
                anchors.margins: 8
                anchors.rightMargin: 18
                model: svc ? svc.history : []
                spacing: 10
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
                    anchors.rightMargin: 8
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    width: 4
                    policy: ScrollBar.AsNeeded
                    background: Item {}
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 0
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
                    selected: centerList.currentIndex === index
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
                    iconSize: center.fontSize + 8
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "All clear"
                    color: center.fg
                    font.family: center.uiFont
                    font.pixelSize: center.fontSize
                }

                QIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl("../assets/icons/y2k-sparkle.svg")
                    color: center.fg
                    iconSize: center.fontSize + 2
                }
            }

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
            radius: 0
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

        Layout.preferredWidth: 30
        Layout.preferredHeight: 30

        Rectangle {
            anchors.fill: parent
            radius: 0
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

        Layout.preferredHeight: 26
        Layout.minimumWidth: 58
        implicitWidth: Math.max(58, dbtnLabel.implicitWidth + 20)

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: dbtn.accent
                ? Qt.rgba(center.accent.r, center.accent.g, center.accent.b, 0.28)
                : (dbHover.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
            border.width: 1
            border.color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.14)
            Behavior on color { CAnim { type: CAnim.FastEffects } }

            Text {
                id: dbtnLabel
                anchors.centerIn: parent
                text: dbtn.label
                color: center.fg
                font.family: center.uiFont
                font.pixelSize: center.fontSize - 1
                font.weight: Font.DemiBold
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

    // Widget-style cards mirroring the top-bar weather / prayer pills,
    // with a caption, a big value and a subtitle line.
    component InfoWidget: Rectangle {
        id: widget
        property string tintName: "primary_fixed_dim"
        property string caption: ""
        property string title: ""
        property string subtitle: ""
        property string glyph: ""
        property bool isY2kMoon: false
        // 0..1 usage bar at the card bottom; negative hides it.
        property real progress: -1

        Layout.preferredHeight: 96
        Layout.fillHeight: false
        radius: 0
        color: rootRef ? rootRef.tonalPillColor(rootRef.pillColor(widget.tintName)) : "#1a1b1e"
        border.width: 0
        clip: true

        readonly property color widgetFg: rootRef ? rootRef.pillForeground(widget.color) : center.fg
        readonly property color widgetDim: Qt.rgba(widgetFg.r, widgetFg.g, widgetFg.b, 0.68)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 10
            anchors.bottomMargin: 22
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 1

                Text {
                    visible: widget.caption.length > 0
                    Layout.fillWidth: true
                    text: widget.caption.toUpperCase()
                    color: widget.widgetDim
                    font.family: center.uiFont
                    font.pixelSize: center.fontSize - 3
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: widget.title
                    color: widget.widgetFg
                    font.family: center.uiFont
                    font.pixelSize: center.fontSize + 9
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: widget.subtitle
                    color: widget.widgetDim
                    font.family: center.uiFont
                    font.pixelSize: center.fontSize - 1
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    verticalAlignment: Text.AlignTop
                }
            }

            Text {
                visible: !widget.isY2kMoon && widget.glyph.length > 0
                Layout.alignment: Qt.AlignVCenter
                text: widget.glyph
                color: widget.widgetFg
                font.family: center.iconFont
                font.pixelSize: 30
            }

            QIcon {
                visible: widget.isY2kMoon
                Layout.alignment: Qt.AlignVCenter
                source: Qt.resolvedUrl("../assets/icons/y2k-moon-star.svg")
                color: widget.widgetFg
                iconSize: 32
            }
        }

        // Usage bar inset above the card bottom edge.
        Rectangle {
            visible: widget.progress >= 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 10
            height: 6
            radius: 0
            color: Qt.rgba(widget.widgetFg.r, widget.widgetFg.g, widget.widgetFg.b, 0.18)
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, widget.progress))
                color: widget.widgetFg
            }
        }
    }


}
}
