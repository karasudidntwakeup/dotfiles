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
    readonly property bool memOn: rootRef && rootRef.memText && rootRef.memText.length > 0
    readonly property bool diskOn: rootRef && rootRef.diskText && rootRef.diskText.length > 0
    readonly property bool infoOn: center.memOn || center.diskOn
    readonly property int infoHeight: center.infoOn ? 96 : 0
    readonly property int listMaxHeight: Math.max(64, center.panelMaxHeight - center.pad * 2 - 30 - 40 - (center.infoOn ? center.infoHeight + 10 : 0) - (center.mediaOn ? 224 + 10 : 0))
    readonly property bool mediaOn: rootRef && rootRef.mediaStatus !== "none"
    readonly property string cardTile: "notif_card"
    readonly property color panelColor: {
        var base = rootRef
            ? (rootRef.qsLight ? rootRef.pillColor(cardTile) : rootRef.colorOf(cardTile))
            : "#15161a"
        if (rootRef && rootRef.mixColor && rootRef.colorOf)
            base = rootRef.mixColor(base, rootRef.colorOf("surface_container_highest"), 0.1)
        return Qt.darker(base, 1.2)
    }
    readonly property color panelBorder: rootRef ? rootRef.withAlpha(Qt.color(rootRef.colorOf("widget_border")), rootRef.qsLight ? 0.7 : 0.5) : "#ffffff33"
    readonly property color fg: rootRef ? rootRef.contrastColor(center.panelColor) : "#ffffff"
    readonly property color muteFg: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.72)
    readonly property color accent: rootRef ? Qt.color(rootRef.colorOf("widget_accent")) : "#ff8fb2"
    readonly property color signalAccent: "#ffffff"
    readonly property string iconFont: rootRef && rootRef.iconFont ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string uiFont: rootRef && rootRef.uiFont ? rootRef.uiFont : "Geist"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13

    function memSubtitle() {
        if (!rootRef || !rootRef.memText) return ""
        var pct = rootRef.memPercent || 0
        var total = rootRef.memTotalText || ""
        return pct + "%" + (total.length > 0 ? " of " + total : "") + " used"
    }

    function diskSubtitle() {
        if (!rootRef || !rootRef.diskText) return ""
        var free = rootRef.diskFreeText || ""
        var total = rootRef.diskTotalText || ""
        if (free.length > 0 && total.length > 0) return free + " free of " + total
        if (free.length > 0) return free + " free"
        return rootRef.diskText + " used"
    }

    // Text helper lives on root (contrastColor).
    property real animProgress: svc && svc.centerOpen ? 1.0 : 0.0
    Behavior on animProgress {
        Anim { type: Anim.Bouncy }
    }

    Keys.onEscapePressed: event => {
        if (svc) svc.closeCenter()
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
        onClicked: { if (svc) svc.closeCenter() }
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
        radius: 12
        border.width: 1
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


        opacity: Math.min(1, center.animProgress * 3)
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

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
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
                    radius: 8
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

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: center.infoHeight
                visible: center.infoOn
                spacing: 8

                // RAM widget: used GB + percent of total + usage bar.
                InfoWidget {
                    visible: center.memOn
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    tintName: "secondary_container"
                    title: rootRef ? rootRef.memText : ""
                    subtitle: center.memSubtitle()
                    caption: "Memory"
                    glyph: ""
                    isY2kMoon: false
                    progress: rootRef ? Math.max(0, Math.min(1, (rootRef.memPercent || 0) / 100)) : 0
                }

                // Disk widget: used percent + free of total + usage bar.
                InfoWidget {
                    visible: center.diskOn
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    tintName: "primary_fixed_dim"
                    title: rootRef ? rootRef.diskText : ""
                    subtitle: center.diskSubtitle()
                    caption: "Disk /"
                    glyph: ""
                    isY2kMoon: false
                    progress: rootRef ? Math.max(0, Math.min(1, (rootRef.diskPercent || 0) / 100)) : 0
                }
            }

            // Mounted disks widgets
            Repeater {
                model: rootRef && rootRef.mountedDisks ? rootRef.mountedDisks : []
                delegate: InfoWidget {
                    Layout.fillWidth: true
                    visible: true
                    tintName: "tertiary_container"
                    title: modelData.pct + "%"
                    subtitle: modelData.free + "G free of " + modelData.total + "G"
                    caption: modelData.mount
                    glyph: ""
                    isY2kMoon: false
                    progress: Math.max(0, Math.min(1, (modelData.pct || 0) / 100))
                }
            }

            Rectangle {
                id: mediaCard
                Layout.fillWidth: true
                Layout.preferredHeight: 224
                visible: rootRef && rootRef.mediaStatus !== "none"
                radius: 12
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
                    radius: mediaCard.radius + 5
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
            Rectangle {
                id: listWrap
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(centerList.contentHeight, center.listMaxHeight) + 16
                visible: centerList.count > 0
                radius: 12
                color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.04)
                border.width: 1
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
                        radius: 2
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
            radius: 8
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
            radius: 8
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
        radius: 12
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
            radius: 3
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
