import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Effects

Item {
    id: lockRoot
    signal unlocked()
    property var rootRef: null
    property bool locked: false

    readonly property string uiFont: rootRef && rootRef.fontFamily ? rootRef.fontFamily : "Ndot 57"
    readonly property string fontJp: "Noto Sans CJK JP"
    readonly property string assetDir: "/home/karasu/.config/hypr/assets/"
    readonly property color fg: "#ffffff"
    readonly property color failC: "#dd0808"
    readonly property color acc: rootRef ? rootRef.colorOf("primary") : "#96c8f6"
    readonly property string iconFontName: rootRef && rootRef.iconFont ? rootRef.iconFont : "Symbols Nerd Font"

    property bool unlockInProgress: false
    // y2k dot-art mask cycle (emojicombos y2k-dot-art vocabulary)
    readonly property var y2kDots: ["✦", "˚", "☾", "⋆", "✧", "★", "･", "♡"]
    readonly property var y2kSizes: [42, 56, 40, 42, 42, 40, 40, 40]
    // Drives the icon bob while PAM verifies.
    property real verifyPhase: 0
    NumberAnimation on verifyPhase {
        from: 0; to: Math.PI * 2; duration: 1100
        loops: Animation.Infinite; running: lockRoot.unlockInProgress
    }
    property bool failed: false
    property string statusText: ""
    property int attempts: 0
    // Android 17-style attempt policy
    property string lastWrong: ""
    property real lockoutUntil: 0
    property bool lockedOut: false
    property real blurAmount: 1.0

    // Guesses 1-4 free; then escalating waits. Capped at 1h (Android goes
    // to years/permanent — unsafe for a desktop, where a reboot is the
    // only recovery).
    function lockoutFor(n) {
        if (n <= 4) return 0
        if (n === 5) return 60
        if (n === 6) return 300
        if (n === 7) return 900
        if (n === 8) return 1800
        return 3600
    }

    function humanTimeout(ms) {
        var s = Math.ceil(ms / 1000)
        if (s < 60) return s + (s === 1 ? " SECOND" : " SECONDS")
        var m = Math.ceil(s / 60)
        if (m < 60) return m + (m === 1 ? " MINUTE" : " MINUTES")
        var h = Math.ceil(m / 60)
        if (h < 48) return h + (h === 1 ? " HOUR" : " HOURS")
        var d = Math.ceil(h / 24)
        return d + (d === 1 ? " DAY" : " DAYS")
    }

    ParallelAnimation {
        id: openAnim
        Anim { target: lockRoot; property: "blurAmount"; from: 1.0; to: 0; type: Anim.DefaultEffects }
        Anim { target: lockRoot; property: "opacity"; from: 0; to: 1; type: Anim.DefaultEffects }
        Anim { target: lockRoot; property: "scale"; from: 1.025; to: 1; type: Anim.Bouncy }
    }
    property bool closing: false
    ParallelAnimation {
        id: closeAnim
        Anim { target: lockRoot; property: "opacity"; to: 0; type: Anim.FastEffects }
        Anim { target: lockRoot; property: "blurAmount"; to: 1.0; type: Anim.FastEffects }
        Anim { target: lockRoot; property: "scale"; to: 1.015; type: Anim.BouncyFast }
        onFinished: {
            if (!lockRoot.closing) return
            lockRoot.closing = false
            lockRoot.unlockInProgress = false
            lockRoot.statusText = ""
            lockRoot.unlocked()
        }
    }

    function tryUnlock() {
        if (unlockInProgress || lockedOut || passInput.text.length === 0) {
            if (lockedOut)
                statusText = "TRY AGAIN IN " + humanTimeout(lockoutUntil - Date.now())
            return
        }
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
                lockRoot.attempts = 0
                lockRoot.lastWrong = ""
                lockRoot.lockoutUntil = 0
                lockRoot.lockedOut = false
                openAnim.stop()
                closing = true
                closeAnim.start()
            } else {
                unlockInProgress = false
                // NOTE: read + clear first — clearing fires onTextChanged,
                // which wipes a status set before it.
                var guess = passInput.text
                passInput.text = ""
                if (guess.length > 0 && guess === lockRoot.lastWrong) {
                    statusText = "ALREADY TRIED — NOT COUNTED"
                } else {
                    lockRoot.lastWrong = guess
                    lockRoot.attempts++
                    var wait = lockRoot.lockoutFor(lockRoot.attempts)
                    if (wait > 0) {
                        lockRoot.lockoutUntil = Date.now() + wait * 1000
                        lockRoot.lockedOut = true
                        statusText = "TRY AGAIN IN " + humanTimeout(wait * 1000)
                    } else {
                        statusText = "WRONG PASSCODE (" + lockRoot.attempts + ")"
                    }
                }
                failed = true
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
        blur: 0.6 + 0.4 * lockRoot.blurAmount
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
            if (lockRoot.unlockInProgress || lockRoot.lockedOut) return
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

    Item {
        id: clockBlock
        height: clockHour.implicitHeight + clockMinute.implicitHeight - 10
        anchors.left: parent.left
        anchors.leftMargin: 7
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.02 + 22

        Text {
            id: clockHour
            font.family: "Ndot57Caps"
            font.pixelSize: Math.round(lockRoot.height * 0.11)
            font.weight: Font.Normal
            color: lockRoot.fg
            style: Text.Normal
        }

        Text {
            id: clockMinute
            anchors.top: clockHour.bottom
            anchors.topMargin: -10
            font.family: "Ndot57Caps"
            font.pixelSize: Math.round(lockRoot.height * 0.11)
            font.weight: Font.Normal
            color: lockRoot.fg
            style: Text.Normal
        }
    }

    Item {
        id: dateWrap
        width: Math.max(28, parent.height * 0.125)
        height: parent.height * 0.35
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: dateLine
            anchors.centerIn: parent
            width: dateWrap.height
            height: dateWrap.width
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: "Ndot57Caps"
            font.pixelSize: Math.round(lockRoot.height * 0.07)
            color: lockRoot.fg
            rotation: 270
            opacity: 0
            SequentialAnimation {
                running: true
                Anim { target: dateLine; property: "opacity"; to: 1; type: Anim.DefaultEffects }
            }
        }
    }

    Text {
        text: (Quickshell.env("USER") || "HUMAN").toUpperCase() + "-01"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 94
        font.family: lockRoot.uiFont
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
        font.family: lockRoot.uiFont
        font.pixelSize: 9
        font.bold: true
        color: lockRoot.fg
    }

    Text {
        text: "かいぜん"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 175
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
        anchors.bottomMargin: 147
        font.family: lockRoot.uiFont
        font.pixelSize: 8
        color: lockRoot.fg
    }

    Text {
        id: quoteBot
        text: "What you resist, persists. What you accept, dissolves."
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 132
        font.family: lockRoot.uiFont
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
        width: 480; height: 72
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
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

        Item {
            id: dotsArea
            anchors.centerIn: parent
            width: 460; height: 64

                Row {
                    id: dotsRow
                    anchors.centerIn: parent
                    spacing: 8

                Repeater {
                    model: Math.min(passInput.text.length, 12)
                        delegate: Item {
                            id: slot
                            width: 30; height: 56
                        property color dotColor: lockRoot.failed ? lockRoot.failC : lockRoot.fg
                        transformOrigin: Item.Center
                        scale: 0.6
                        opacity: 0
                        y: 3.5
                        rotation: -9
                        ParallelAnimation {
                            id: slotIn
                            Anim { target: slot; property: "scale"; from: 0.6; to: 1.0; type: Anim.Bouncy }
                            Anim { target: slot; property: "y"; from: 3.5; to: 0; type: Anim.BouncyFast }
                            Anim { target: slot; property: "rotation"; from: -9; to: 0; type: Anim.FastEffects }
                            Anim { target: slot; property: "opacity"; from: 0; to: 1.0; type: Anim.FastEffects }
                        }
                        Component.onCompleted: slotIn.start()

                        // y2k dot-art icon, one glyph per keystroke — never "."/real chars
                        Text {
                            id: glyphText
                            anchors.centerIn: parent
                            // staggered float while PAM verifies
                            y: lockRoot.unlockInProgress
                                ? Math.sin(lockRoot.verifyPhase - index * 0.7) * 3 : 0
                            text: lockRoot.y2kDots[index % lockRoot.y2kDots.length]
                            color: slot.dotColor
                            font.family: lockRoot.uiFont
                            font.pixelSize: lockRoot.y2kSizes[index % lockRoot.y2kSizes.length]
                            font.weight: Font.Bold
                            Behavior on color { CAnim { type: CAnim.FastEffects } }
                        }
                    }
                }

                    Rectangle {
                        id: caret
                        width: 2; height: 24
                        y: 16
                    color: lockRoot.failed ? lockRoot.failC : lockRoot.acc
                    property real blink: 0
                    opacity: passInput.activeFocus ? blink : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                    Text {
                        y: 22
                        visible: passInput.text.length > 12
                        text: "+" + (passInput.text.length - 12)
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font.family: lockRoot.uiFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
            }
        }

        Timer {
            interval: 500; repeat: true; running: passInput.activeFocus
            triggeredOnStart: true
            onTriggered: caret.blink = caret.blink === 0 ? 1 : 0
        }
    }

        TextInput {
            id: passInput; anchors.fill: parent; visible: false
            echoMode: TextInput.Password; passwordCharacter: "×"; focus: true
            maximumLength: 32
            enabled: !lockRoot.lockedOut
            onTextChanged: { if (lockRoot.failed) { lockRoot.failed = false; lockRoot.statusText = "" } }
            onAccepted: lockRoot.tryUnlock()
        }

    Text {
        id: statusLine
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 112
        text: lockRoot.statusText
        font.family: lockRoot.uiFont; font.pixelSize: 9
        font.weight: Font.Bold; font.letterSpacing: 1
        property real shown: lockRoot.statusText.length > 0 ? 1 : 0
        Behavior on shown { Anim { type: Anim.FastEffects } }
        opacity: shown
        visible: opacity > 0.01
        transform: Translate { y: (1 - statusLine.shown) * 5 }
        color: lockRoot.failed ? lockRoot.failC : lockRoot.acc
    }

    Timer { interval: 200; repeat: true; running: lockRoot.locked; triggeredOnStart: true
        onTriggered: { if (!passInput.activeFocus) passInput.forceActiveFocus() }
    }

    Timer {
        interval: 1000; running: lockRoot.locked; repeat: true; triggeredOnStart: true
        onTriggered: {
            var out = Date.now() < lockRoot.lockoutUntil
            if (out) {
                lockRoot.lockedOut = true
                lockRoot.statusText = "TRY AGAIN IN " + humanTimeout(lockRoot.lockoutUntil - Date.now())
            } else if (lockRoot.lockedOut) {
                lockRoot.lockedOut = false
                if (!lockRoot.failed) lockRoot.statusText = ""
                passInput.forceActiveFocus()
            }
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
