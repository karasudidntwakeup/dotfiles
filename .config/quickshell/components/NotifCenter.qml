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
    readonly property int listMaxHeight: Math.max(64, center.panelMaxHeight - center.pad * 2 - 30 - 40 - (center.mediaOn ? 224 : 0))
    readonly property bool mediaOn: rootRef && rootRef.mediaStatus !== "none"
    readonly property color panelColor: rootRef
        ? (rootRef.qsLight ? rootRef.pillColor("surface") : rootRef.colorOf("surface"))
        : "#15161a"
    readonly property color panelBorder: rootRef ? rootRef.withAlpha(Qt.color(rootRef.colorOf("widget_border")), rootRef.qsLight ? 0.7 : 0.5) : "#ffffff33"
    readonly property color fg: rootRef ? center.contrastColor(center.panelColor) : "#ffffff"
    readonly property color muteFg: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.55)
    readonly property color accent: rootRef ? Qt.color(rootRef.colorOf("widget_accent")) : "#ff8fb2"
    readonly property color signalAccent: "#FF3030"
    readonly property string iconFont: rootRef && rootRef.iconFont ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string uiFont: rootRef && rootRef.uiFont ? rootRef.uiFont : "Inter"
    readonly property string fontFamily: rootRef && rootRef.fontFamily ? rootRef.fontFamily : "Ndot 57"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13

    function _lin(v: double): double {
        if (v <= 0.03928) return v / 12.92
        return Math.pow((v + 0.055) / 1.055, 2.4)
    }
    function relLum(c: color): double {
        return 0.2126 * center._lin(c.r) + 0.7152 * center._lin(c.g) + 0.0722 * center._lin(c.b)
    }
    function contrastColor(c: color): color {
        var l = center.relLum(c)
        var white = (1.05) / (l + 0.05)
        var black = (l + 0.05) / (0.05)
        return white >= black ? "#ffffff" : "#000000"
    }
    property real animProgress: svc && svc.centerOpen ? 1.0 : 0.0
    Behavior on animProgress {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
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
        anchors.topMargin: 30
        anchors.rightMargin: 10
        color: center.panelColor
        radius: 22
        border.width: 1
        border.color: center.panelBorder
        clip: true


        transform: Translate {
            x: (1.0 - center.animProgress) * (center.panelWidth + 48)
        }
        scale: 0.98 + 0.02 * center.animProgress
        rotation: (1.0 - center.animProgress) * 1.5
        transformOrigin: Item.Right

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

                Text {
                    text: "󰆂"
                    color: center.fg
                    font.family: center.iconFont
                    font.pixelSize: center.fontSize + 3
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 30
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text: "Notifications"
                    color: center.fg
                    font.family: center.fontFamily
                    font.pixelSize: center.fontSize + 2
                    font.weight: Font.Black
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    visible: svc && svc.unreadCount > 0
                    Layout.preferredHeight: 20
                    implicitWidth: unreadLabel.implicitWidth + 12
                    radius: 10
                    color: center.accent

                    Text {
                        id: unreadLabel
                        anchors.centerIn: parent
                        text: svc ? String(svc.unreadCount) : ""
                        color: "#15161a"
                        font.family: center.fontFamily
                        font.pixelSize: center.fontSize - 2
                        font.weight: Font.Black
                    }
                }

                HeaderBtn {
                    glyph: "󰂚"
                    active: svc ? svc.dnd : false
                    onTapped: { if (svc) svc.dnd = !svc.dnd }
                }

                HeaderBtn {
                    glyph: "󰗩"
                    enabled_: svc && svc.history.count > 0
                    active: false
                    onTapped: { if (svc) svc.clearAll() }
                }
            }

            Rectangle {
                id: mediaCard
                Layout.fillWidth: true
                Layout.preferredHeight: 224
                visible: rootRef && rootRef.mediaStatus !== "none"
                radius: 22
                clip: true
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.16)
                color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.045)

                readonly property color mediaAccent: center.signalAccent
                property string mediaTitle: rootRef ? (rootRef.mediaTitle || "") : ""
                property string mediaArtist: rootRef ? (rootRef.mediaArtist || "") : ""
                property bool hasArt: rootRef && !!rootRef.mediaArt
                property real progress: rootRef && rootRef.mediaLenMs > 0
                    ? Math.max(0, Math.min(1, rootRef.mediaPosMs / rootRef.mediaLenMs))
                    : 0

                Rectangle {
                    id: mediaArtMask
                    anchors.fill: parent
                    radius: mediaCard.radius
                    visible: false
                    layer.enabled: true
                }

                Image {
                    anchors.fill: parent
                    source: mediaCard.hasArt ? (rootRef.mediaArt || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: mediaArtMask }
                    visible: source !== ""
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 0
                    radius: mediaCard.radius
                    color: mediaCard.hasArt
                        ? Qt.rgba(0.04, 0.05, 0.06, 0.62)
                        : Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.05)
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰽴"
                    color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.35)
                    font.family: center.iconFont
                    font.pixelSize: 34
                    visible: !mediaCard.hasArt
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "NOW PLAYING"
                        color: Qt.rgba(mediaCard.mediaAccent.r, mediaCard.mediaAccent.g, mediaCard.mediaAccent.b, 0.9)
                        font.family: center.uiFont
                        font.pixelSize: 10
                        font.letterSpacing: 3
                        font.weight: Font.DemiBold
                    }

                    Item { Layout.fillHeight: true }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            Layout.fillWidth: true
                            text: mediaCard.mediaTitle
                            color: "#ffffff"
                            font.family: center.fontFamily
                            font.pixelSize: center.fontSize + 1
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            maximumLineCount: 2
                        }

                        Text {
                            Layout.fillWidth: true
                            text: mediaCard.mediaArtist.toUpperCase()
                            color: Qt.rgba(1, 1, 1, 0.7)
                            font.family: center.uiFont
                            font.pixelSize: 10
                            font.letterSpacing: 2
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

                                onPlayingChanged: {
                                    if (waveCanvas.playing) waveTimer.start()
                                    else waveTimer.stop()
                                    waveCanvas.requestPaint()
                                }
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
                                running: waveCanvas.playing
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
                            glyph: "󰼨"
                            onTapped: rootRef ? Quickshell.execDetached(["playerctl", "previous"]) : {}
                        }

                        MediaBtn {
                            btnSize: 44
                            glyph: rootRef && rootRef.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                            accent: true
                            onTapped: rootRef ? Quickshell.execDetached(["playerctl", "play-pause"]) : {}
                        }

                        MediaBtn {
                            btnSize: 30
                            glyph: "󰼧"
                            onTapped: rootRef ? Quickshell.execDetached(["playerctl", "next"]) : {}
                        }

                        Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
                    }
                }
            }
            ListView {
                id: centerList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(centerList.contentHeight, center.listMaxHeight)
                model: svc ? svc.history : []
                spacing: 10
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    width: 3
                    policy: ScrollBar.AsNeeded
                    background: Item {}
                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: 1.5
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }

                onCountChanged: {
                    if (centerList.count === 0) centerList.currentIndex = -1
                    else if (centerList.currentIndex >= centerList.count)
                        centerList.currentIndex = centerList.count - 1
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

    component MediaBtn: Item {
        id: btn
        property string glyph: ""
        property bool accent: false
        property int btnSize: 30
        signal tapped()

        Layout.preferredWidth: btn.btnSize
        Layout.preferredHeight: btn.btnSize

        Rectangle {
            anchors.centerIn: parent
            width: btn.btnSize
            height: btn.btnSize
            radius: btn.btnSize / 2
            color: btn.accent
                ? Qt.color(center.signalAccent)
                : (hoverArea.containsMouse ? Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.1) : "transparent")

            Text {
                anchors.centerIn: parent
                text: btn.glyph
                color: btn.accent ? "#15161a" : center.fg
                font.family: center.iconFont
                font.pixelSize: center.fontSize + (btn.accent ? 6 : 2)
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
        property string glyph: ""
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
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: !btn.enabled_ ? Qt.rgba(1, 1, 1, 0.25) : center.fg
            font.family: center.iconFont
            font.pixelSize: center.fontSize
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


}
}
