import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: lockRoot
    signal unlocked()
    property var rootRef: null
    property bool locked: false

    readonly property string fontMain: "Ndot 55"
    readonly property string fontAltBold: "Lettera Mono LL"
    readonly property string fontCaps: "Ndot55Caps"
    readonly property string fontJp: "Noto Sans CJK JP"
    readonly property string assetDir: "/home/karasu/.config/hypr/assets/"
    readonly property color fg: "#ffffff"
    readonly property color failC: "#dd0808"
    readonly property color acc: rootRef ? rootRef.colorOf("primary") : "#96c8f6"
    readonly property string iconFontName: rootRef && rootRef.iconFont ? rootRef.iconFont : "Symbols Nerd Font"

    property bool unlockInProgress: false
    property bool failed: false
    property string statusText: ""
    property int attempts: 0
    property real blurAmount: 1.0
    property real foldScale: 1.0
    transform: Scale { origin.x: width / 2; origin.y: height / 2; xScale: lockRoot.foldScale; yScale: lockRoot.foldScale }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: lockRoot; property: "blurAmount"; from: 1.0; to: 0; duration: 900; easing.type: Easing.OutQuint }
        NumberAnimation { target: lockRoot; property: "opacity"; from: 0; to: 1; duration: 900; easing.type: Easing.OutQuint }
        NumberAnimation { target: lockRoot; property: "foldScale"; from: 0.95; to: 1; duration: 900; easing.type: Easing.OutCubic }
    }
    property bool closing: false
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: lockRoot; property: "opacity"; from: 1; to: 0; duration: 400; easing.type: Easing.InOutCubic }
        NumberAnimation { target: lockRoot; property: "blurAmount"; from: 0; to: 1.0; duration: 400; easing.type: Easing.InCubic }
        onRunningChanged: {
            if (!running && lockRoot.closing) {
                lockRoot.closing = false
                unlockInProgress = false
                statusText = ""
                lockRoot.unlocked()
            }
        }
    }

    function tryUnlock() {
        if (unlockInProgress || passInput.text.length === 0) return
        unlockInProgress = true
        statusText = ""
        failed = false
        pam.start()
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellDir + "/pam"
        config: "quickshell.conf"
        onPamMessage: { if (responseRequired) respond(passInput.text) }
        onCompleted: result => {
            if (result === PamResult.Success) {
                closing = true
                closeAnim.start()
            } else {
                unlockInProgress = false
                lockRoot.attempts++
                statusText = "WRONG PASSCODE (" + lockRoot.attempts + ")"
                failed = true
                passInput.text = ""
                cardshake.restart()
                passInput.forceActiveFocus()
            }
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Process {
        id: wpQuery
        command: ["awww", "query"]
        stdout: SplitParser {
            onRead: line => {
                var i = line.indexOf("currently displaying: image: ")
                if (i >= 0) {
                    var p = line.substring(i + "currently displaying: image: ".length).trim()
                    if (p.length > 0) wallpaper.source = "file://" + p
                }
            }
        }
    }
    Timer {
        interval: 1000; running: true; repeat: false; triggeredOnStart: true
        onTriggered: wpQuery.running = true
    }
    MultiEffect {
        id: blurFx
        anchors.fill: wallpaper
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 48
        blur: 0.6 + lockRoot.blurAmount
        brightness: -0.18
        contrast: -0.11
        saturation: 0.17
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.18 }

    MouseArea { anchors.fill: parent; onClicked: passInput.forceActiveFocus() }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (lockRoot.unlockInProgress) return
            if (!passInput.activeFocus && event.key !== Qt.Key_Return
                && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Tab
                && event.key !== Qt.Key_Escape) {
                passInput.forceActiveFocus()
                if (event.text.length > 0 && event.key !== Qt.Key_Backspace)
                    passInput.insert(event.text)
                event.accepted = true
            }
        }
    }

    Text {
        id: clockHour
        x: 7
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.02 + 22
        font.family: lockRoot.fontMain
        font.pixelSize: Math.max(70, parent.height * 0.09)
        color: lockRoot.fg
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.35)
    }

    Text {
        id: clockMinute
        x: 7
        anchors.top: clockHour.bottom
        anchors.topMargin: -10
        font.family: lockRoot.fontMain
        font.pixelSize: Math.max(70, parent.height * 0.09)
        color: lockRoot.fg
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.35)
    }

    Item {
        id: dateWrap
        width: Math.max(28, parent.height * 0.045)
        height: parent.height * 0.45
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: dateLine
            anchors.centerIn: parent
            width: dateWrap.height
            height: dateWrap.width
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: lockRoot.fontMain
            font.pixelSize: dateWrap.width + 4
            color: lockRoot.fg
            transform: Rotation { angle: 90; origin.x: width / 2; origin.y: height / 2 }
            opacity: 0
            SequentialAnimation {
                running: true
                PauseAnimation { duration: 200 }
                NumberAnimation { target: dateLine; property: "opacity"; to: 1; duration: 500; easing.type: Easing.OutCubic }
            }
        }
    }

    Text {
        text: (Quickshell.env("USER") || "HUMAN").toUpperCase() + "-01"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 58
        font.family: lockRoot.fontAltBold
        font.pixelSize: 11
        font.bold: true
        color: lockRoot.fg
    }

    Text {
        text: "ManchmalKarasu"
        anchors.right: parent.right
        anchors.rightMargin: 35
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 25
        font.family: lockRoot.fontAltBold
        font.pixelSize: 9
        font.bold: true
        color: lockRoot.fg
    }

    Text {
        text: "かいぜん"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 190
        font.family: lockRoot.fontJp
        font.pixelSize: 10
        font.bold: true
        color: lockRoot.fg
    }

    Text {
        id: quoteTop
        text: "You can have everything and feel nothing."
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 130
        font.family: lockRoot.fontCaps
        font.pixelSize: 8
        color: lockRoot.fg
    }

    Text {
        id: quoteBot
        text: "What you resist, persists. What you accept, dissolves."
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 115
        font.family: lockRoot.fontCaps
        font.pixelSize: 8
        color: lockRoot.fg
    }

    Image {
        source: lockRoot.assetDir + "globe-3d.png"
        width: 110; height: 110
        x: 30
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 25
        fillMode: Image.PreserveAspectCrop
        opacity: 0.2
        asynchronous: true
    }

    Rectangle {
        id: passBox
        width: 110; height: 25; radius: 6
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        color: "transparent"
        border.width: 0

        transform: Translate { id: shakeT; property real x: 0 }
        SequentialAnimation {
            id: cardshake; running: false
            NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 45; easing.type: Easing.OutQuad }
            NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 90; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeT; property: "x"; to: 4; duration: 70; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 70; easing.type: Easing.OutQuad }
        }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; spacing: 4
            Text {
                id: passPrompt
                text: passInput.text.length === 0 ? "PASSCODE" : lockRoot.passDots
                font.family: lockRoot.fontAltBold
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1
                color: lockRoot.failed ? lockRoot.failC : lockRoot.fg
                Layout.fillWidth: true; Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            Rectangle {
                id: caret; width: 1; height: 14; color: lockRoot.fg
                property real blink: 0
                opacity: passInput.activeFocus ? blink : 0
            }
        }

        Timer {
            interval: 500; repeat: true; running: passInput.activeFocus
            triggeredOnStart: true
            onTriggered: caret.blink = caret.blink === 0 ? 1 : 0
        }

        TextInput {
            id: passInput; anchors.fill: parent; visible: false
            echoMode: TextInput.Password; passwordCharacter: "•"; focus: true
            onTextChanged: { if (lockRoot.failed) { lockRoot.failed = false; lockRoot.statusText = "" } }
            onAccepted: lockRoot.tryUnlock()
        }
    }

    property string passDots: "•".repeat(Math.min(passInput.text.length, 14))

    Text {
        id: statusLine
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 54
        text: lockRoot.statusText
        font.family: lockRoot.fontAltBold; font.pixelSize: 9
        font.weight: Font.Bold; font.letterSpacing: 1
        visible: lockRoot.statusText.length > 0
        color: lockRoot.failed ? lockRoot.failC : lockRoot.acc
    }

    Timer { interval: 200; repeat: true; running: lockRoot.locked; triggeredOnStart: true
        onTriggered: { if (!passInput.activeFocus) passInput.forceActiveFocus() }
    }

    Timer {
        interval: 1000; running: lockRoot.locked; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            var h12 = d.getHours() % 12; if (h12 === 0) h12 = 12
            clockHour.text = (h12 < 10 ? "0" : "") + h12
            clockMinute.text = (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
            dateLine.text = Qt.formatDateTime(d, "dddd MMMM d")
        }
    }

    component LockMediaBtn: Item {
        id: lockBtn
        property string glyph: ""
        property bool accent: false
        property int btnSize: 36
        signal tapped()

        Layout.preferredWidth: lockBtn.btnSize
        Layout.preferredHeight: lockBtn.btnSize

        Rectangle {
            anchors.centerIn: parent
            width: lockBtn.btnSize
            height: lockBtn.btnSize
            radius: lockBtn.btnSize / 2
            color: lockBtn.accent
                ? lockRoot.acc
                : (lockBtnHover.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
            border.width: lockBtn.accent ? 0 : 1
            border.color: lockBtn.accent ? "transparent" : Qt.rgba(1, 1, 1, 0.20)
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: lockBtn.glyph
                color: lockBtn.accent ? "#0c0d10" : "#ffffff"
                font.family: lockRoot.iconFontName
                font.pixelSize: Math.round(lockBtn.btnSize * 0.42)
            }

            MouseArea {
                id: lockBtnHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: lockBtn.tapped()
            }
        }
    }

    Rectangle {
        id: lockMediaCard
        width: Math.min(560, parent.width * 0.56)
        height: 268
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        radius: 26
        color: Qt.rgba(0.03, 0.04, 0.06, 0.52)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        clip: true
        visible: rootRef && rootRef.mediaStatus !== "none"

        property real enter: 0
        readonly property string mTitle: rootRef ? (rootRef.mediaTitle || "") : ""
        readonly property string mArtist: rootRef ? (rootRef.mediaArtist || "") : ""
        readonly property bool mArt: rootRef && !!rootRef.mediaArt
        readonly property bool playing: rootRef && rootRef.mediaStatus === "Playing"
        readonly property real progress: rootRef && rootRef.mediaLenMs > 0
            ? Math.max(0, Math.min(1, rootRef.mediaPosMs / rootRef.mediaLenMs))
            : 0

        function fmtTime(ms) {
            if (!isFinite(ms) || ms <= 0) return "0:00"
            var s = Math.floor(ms / 1000)
            var m = Math.floor(s / 60)
            s = s % 60
            return m + ":" + (s < 10 ? "0" : "") + s
        }

        NumberAnimation {
            id: lockMediaAnim
            target: lockMediaCard
            property: "enter"
            from: 0; to: 1
            duration: 340
            easing.type: Easing.OutCubic
        }
        onVisibleChanged: if (lockMediaCard.visible) lockMediaAnim.restart()
        Component.onCompleted: if (lockMediaCard.visible) lockMediaAnim.restart()

        opacity: lockMediaCard.enter
        transform: Translate { id: lockMediaSlide; y: 40 * (1 - lockMediaCard.enter) }

        Rectangle {
            id: lockArtMask
            anchors.fill: parent
            anchors.margins: -6
            radius: lockMediaCard.radius + 6
            color: "#ffffff"
            visible: false
            layer.enabled: true
        }

        Image {
            anchors.fill: parent
            source: lockMediaCard.mArt ? (rootRef.mediaArt || "") : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            mipmap: true
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: lockArtMask }
            visible: source !== ""
        }

        Rectangle {
            anchors.fill: parent
            radius: lockMediaCard.radius
            color: lockMediaCard.mArt
                ? Qt.rgba(0.02, 0.03, 0.05, 0.62)
                : Qt.rgba(0, 0, 0, 0.28)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                Rectangle {
                    id: lockThumb
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 100
                    radius: 18
                    clip: true
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Image {
                        anchors.fill: parent
                        source: lockMediaCard.mArt ? (rootRef.mediaArt || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: lockMediaCard.mArt
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰽴"
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.family: lockRoot.iconFontName
                        font.pixelSize: 34
                        visible: !lockMediaCard.mArt
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 5

                    RowLayout {
                        spacing: 8

                        Text {
                            text: "NOW PLAYING"
                            color: Qt.rgba(lockRoot.acc.r, lockRoot.acc.g, lockRoot.acc.b, 0.95)
                            font.family: lockRoot.fontAltBold
                            font.pixelSize: 11
                            font.letterSpacing: 4
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            visible: lockMediaCard.playing
                            Layout.preferredWidth: 6; Layout.preferredHeight: 6
                            Layout.alignment: Qt.AlignVCenter
                            radius: 3
                            color: lockRoot.acc
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: lockMediaCard.mTitle
                        color: "#ffffff"
                        font.family: lockRoot.fontMain
                        font.pixelSize: 26
                        elide: Text.ElideRight
                        maximumLineCount: 2
                    }

                    Text {
                        Layout.fillWidth: true
                        text: lockMediaCard.mArtist.toUpperCase()
                        color: Qt.rgba(1, 1, 1, 0.68)
                        font.family: lockRoot.fontAltBold
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.preferredWidth: 42
                    text: lockMediaCard.fmtTime(rootRef ? (rootRef.mediaPosMs || 0) : 0)
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.family: lockRoot.fontAltBold
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20

                    Canvas {
                        id: lockWave
                        anchors.fill: parent
                        antialiasing: true

                        readonly property real waveLength: 52
                        readonly property real amplitude: 4
                        readonly property real thickness: 2.2
                        property real phase: 0
                        property bool playing: lockMediaCard.playing
                        property bool hovered: seekArea.containsMouse || seekArea.dragging

                        onPlayingChanged: {
                            if (lockMediaCard.playing) lockWaveTimer.start()
                            else lockWaveTimer.stop()
                            lockWave.requestPaint()
                        }
                        onHoveredChanged: lockWave.requestPaint()
                        onWidthChanged: lockWave.requestPaint()
                        onHeightChanged: lockWave.requestPaint()

                        function ampFactor(x, edge, taper) {
                            var d = edge - x
                            if (d >= taper) return 1
                            if (d <= 0) return 0
                            var k = d / taper
                            return k * k * (3 - 2 * k)
                        }

                        onPaint: () => {
                            var ctx = lockWave.getContext("2d")
                            var w = lockWave.width
                            var h = lockWave.height
                            ctx.clearRect(0, 0, w, h)
                            if (w <= 0 || h <= 0) return

                            var edge = Math.max(0, Math.min(w, lockMediaCard.progress * w))
                            var midY = h / 2
                            var taper = Math.max(30, Math.min(90, w * 0.1))
                            var freq = 2 * Math.PI / lockWave.waveLength

                            ctx.lineWidth = lockWave.thickness
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"

                            if (edge < w) {
                                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.22)
                                ctx.beginPath()
                                ctx.moveTo(edge, midY)
                                ctx.lineTo(w, midY)
                                ctx.stroke()
                            }

                            ctx.strokeStyle = lockRoot.acc
                            ctx.beginPath()
                            for (var i = 0; i <= w; i += 2) {
                                var amp = lockWave.amplitude * lockWave.ampFactor(i, edge, taper)
                                var y = midY + Math.sin(i * freq + lockWave.phase) * amp
                                if (i === 0) ctx.moveTo(i, y)
                                else ctx.lineTo(i, y)
                            }
                            ctx.stroke()

                            var thumbR = lockWave.hovered ? 6 : 4
                            if (lockMediaCard.progress > 0.001) {
                                ctx.fillStyle = lockRoot.acc
                                ctx.beginPath()
                                ctx.arc(edge, midY, thumbR, 0, 2 * Math.PI)
                                ctx.fill()
                                ctx.fillStyle = "#ffffff"
                                ctx.beginPath()
                                ctx.arc(edge, midY, 2.6, 0, 2 * Math.PI)
                                ctx.fill()
                            }
                        }
                    }

                    Timer {
                        id: lockWaveTimer
                        interval: 50
                        repeat: true
                        running: lockMediaCard.playing
                        onTriggered: () => {
                            lockWave.phase += 0.15
                            lockWave.requestPaint()
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

                        onPressed: (mouse) => { dragging = true; seekTo(mouse.x) }
                        onPositionChanged: (mouse) => { if (dragging) seekTo(mouse.x) }
                        onReleased: (mouse) => { dragging = false }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignRight
                    text: lockMediaCard.fmtTime(rootRef ? (rootRef.mediaLenMs || 0) : 0)
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font.family: lockRoot.fontAltBold
                    font.pixelSize: 12
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 18

                Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }

                LockMediaBtn {
                    btnSize: 42
                    glyph: "󰼨"
                    onTapped: rootRef ? Quickshell.execDetached(["playerctl", "previous"]) : {}
                }

                LockMediaBtn {
                    btnSize: 60
                    glyph: lockMediaCard.playing ? "󰏤" : "󰐊"
                    accent: true
                    onTapped: rootRef ? Quickshell.execDetached(["playerctl", "play-pause"]) : {}
                }

                LockMediaBtn {
                    btnSize: 42
                    glyph: "󰼧"
                    onTapped: rootRef ? Quickshell.execDetached(["playerctl", "next"]) : {}
                }

                Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
            }
        }
    }

    Component.onCompleted: {
        lockRoot.opacity = 0
        openAnim.start()
        passInput.forceActiveFocus()
    }
}
