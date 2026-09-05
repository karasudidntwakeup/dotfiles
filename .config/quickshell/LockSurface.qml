import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: lockRoot
    signal unlocked()

    readonly property string fontMain: "Ndot 55"
    readonly property string fontAlt: "Lettera Mono LL"
    readonly property string fontAltBold: "Lettera Mono LL"
    readonly property string fontCaps: "Ndot55Caps"
    readonly property string fontJp: "Noto Sans CJK JP"
    readonly property string assetDir: "/home/karasu/.config/hypr/assets/"
    readonly property color fg: "#ffffff"
    readonly property color failC: "#dd0808"

    FileView {
        id: colorFile
        property var paletteMap: ({})
        path: Quickshell.shellDir + "/colors.js"
        watchChanges: true
        blockLoading: true
        onFileChanged: colorFile.reload()
        onLoadFailed: error => console.log("[lock] failed to load colors.js:", error)
        onLoaded: {
            var map = {}
            var re = /var\s+(\w+)\s+=\s+"([^"]*)"/g
            var content = String(colorFile.text())
            var m
            while ((m = re.exec(content)) !== null) map[m[1]] = m[2]
            colorFile.paletteMap = map
        }
    }
    function colorOf(name) {
        var v = colorFile.paletteMap[name]
        return v !== undefined ? v : "#808080"
    }
    property color acc: colorOf("primary")

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

    // Wallpaper (matches hyprlock blur/brightness/contrast/vibrancy)
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

    // Elements (positions match the old hyprlock config)
    // Clock-hour, left, top
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

    // Clock-minute, below hour
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

    // Date, vertical strip on the right edge
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

    // Name, center-bottom
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

    // Tag, right-bottom
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

    // Hiragana, center-bottom
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

    // Quote, top
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

    // Quote, bottom
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

    // Avatar, left-bottom
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

    // Passcode box, center-bottom
    Rectangle {
        id: passBox
        width: 80; height: 25; radius: 3
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

    property string passDots: "•".repeat(Math.min(passInput.text.length, 24))

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

    Timer { interval: 200; repeat: true; running: true; triggeredOnStart: true
        onTriggered: { if (!passInput.activeFocus) passInput.forceActiveFocus() }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            var h12 = d.getHours() % 12; if (h12 === 0) h12 = 12
            clockHour.text = (h12 < 10 ? "0" : "") + h12
            clockMinute.text = (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
            dateLine.text = Qt.formatDateTime(d, "dddd MMMM d")
        }
    }

    Component.onCompleted: {
        lockRoot.opacity = 0
        openAnim.start()
        passInput.forceActiveFocus()
    }
}
