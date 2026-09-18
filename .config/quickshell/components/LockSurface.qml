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

    readonly property string uiFont: rootRef && rootRef.fontFamily ? rootRef.fontFamily : "Ndot 57"
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

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: lockRoot; property: "blurAmount"; from: 1.0; to: 0; duration: 380; easing.type: Easing.OutCubic }
        NumberAnimation { target: lockRoot; property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: lockRoot; property: "scale"; from: 1.025; to: 1; duration: 380; easing.type: Easing.OutCubic }
    }
    property bool closing: false
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: lockRoot; property: "opacity"; to: 0; duration: 240; easing.type: Easing.InOutCubic }
        NumberAnimation { target: lockRoot; property: "blurAmount"; to: 1.0; duration: 240; easing.type: Easing.InOutCubic }
        NumberAnimation { target: lockRoot; property: "scale"; to: 1.015; duration: 240; easing.type: Easing.InOutCubic }
        onFinished: {
            if (!lockRoot.closing) return
            lockRoot.closing = false
            lockRoot.unlockInProgress = false
            lockRoot.statusText = ""
            lockRoot.unlocked()
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
                openAnim.stop()
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
                NumberAnimation { target: dateLine; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            }
        }
    }

    Text {
        text: (Quickshell.env("USER") || "HUMAN").toUpperCase() + "-01"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 58
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
        font.family: lockRoot.uiFont
        font.pixelSize: 8
        color: lockRoot.fg
    }

    Text {
        id: quoteBot
        text: "What you resist, persists. What you accept, dissolves."
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 115
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
        width: 110; height: 25; radius: 8
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
                font.family: lockRoot.uiFont
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
        font.family: lockRoot.uiFont; font.pixelSize: 9
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
            radius: 8
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

    Component.onCompleted: {
        lockRoot.opacity = 0
        openAnim.start()
        passInput.forceActiveFocus()
    }
}
