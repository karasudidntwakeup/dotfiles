import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: lockRoot
    signal unlocked()

    readonly property string fontFamily: "Ndot"
    readonly property string altFont: "Inter"
    readonly property string capsFont: "Ndot55Caps"
    readonly property string jpFont: "Noto Sans CJK JP"
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
        NumberAnimation { target: lockRoot; property: "opacity"; from: 0; to: 1; duration: 600; easing.type: Easing.OutQuint }
        NumberAnimation { target: lockRoot; property: "foldScale"; from: 0.9; to: 1; duration: 600; easing.type: Easing.OutBack }
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
        statusText = "AUTHENTICATING"
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
        blur: 0.55 + lockRoot.blurAmount
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
            }
            event.accepted = true
        }
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 7
        anchors.topMargin: 22
        spacing: 21
        Text { id: clockHours; font.family: lockRoot.fontFamily; font.pixelSize: 80; font.bold: true; color: lockRoot.fg }
        Text { id: clockMinutes; font.family: lockRoot.fontFamily; font.pixelSize: 80; font.bold: true; color: lockRoot.fg }
    }

    Item {
        id: dateHang
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 20
        anchors.topMargin: 125
        width: dateText.implicitHeight
        height: dateText.implicitWidth
        Text {
            id: dateText
            anchors.centerIn: parent
            rotation: 90
            transformOrigin: Item.Center
            font.family: lockRoot.fontFamily
            font.pixelSize: 50
            font.bold: true
            color: lockRoot.fg
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            var h24 = d.getHours()
            var h12 = h24 % 12; if (h12 === 0) h12 = 12
            clockHours.text = (h12 < 10 ? "0" : "") + h12
            clockMinutes.text = (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
            dateText.text = Qt.formatDateTime(d, "ddd MMMM dd")
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        text: (Quickshell.env("USER") || "HUMAN").toUpperCase() + "-01"
        font.family: lockRoot.altFont; font.pixelSize: 11; font.weight: Font.Bold
        font.letterSpacing: 2; color: lockRoot.fg
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 220
        text: "かいぜん"
        font.family: lockRoot.jpFont; font.pixelSize: 10; color: lockRoot.fg
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 160
        text: "You can have everything and feel nothing."
        font.family: lockRoot.capsFont; font.pixelSize: 8
        font.letterSpacing: 2; color: lockRoot.fg
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 145
        text: "What you resist, persists. What you accept, dissolves."
        font.family: lockRoot.capsFont; font.pixelSize: 8
        font.letterSpacing: 2; color: lockRoot.fg
    }

    Column {
        id: inputCol
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 55
        spacing: 10
        opacity: 0
        scale: 0.9

        NumberAnimation {
            id: inputPop
            target: inputCol
            property: "scale"
            from: 0.9; to: 1
            duration: 400; easing.type: Easing.OutBack
        }

        SequentialAnimation {
            id: inputPopSeq
            running: false
            NumberAnimation { target: inputCol; property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: inputCol; property: "scale"; from: 0.9; to: 1; duration: 300; easing.type: Easing.OutBack }
        }

        Text {
            id: statusLine
            anchors.horizontalCenter: parent.horizontalCenter
            text: lockRoot.statusText
            font.family: lockRoot.altFont; font.pixelSize: 11
            font.weight: Font.Bold; font.letterSpacing: 2
            visible: lockRoot.statusText.length > 0
            color: lockRoot.failed ? lockRoot.failC : lockRoot.acc
        }

        Rectangle {
            id: passBox
            width: 380; height: 44; radius: 14
            color: Qt.rgba(0, 0, 0, 0.28)
            border.width: 1
            border.color: lockRoot.failed ? lockRoot.failC : Qt.rgba(1, 1, 1, 0.25)

            transform: Translate { id: shakeT; property real x: 0 }
            SequentialAnimation {
                id: cardshake; running: false
                NumberAnimation { target: shakeT; property: "x"; to: 12; duration: 45; easing.type: Easing.OutQuad }
                NumberAnimation { target: shakeT; property: "x"; to: -12; duration: 90; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeT; property: "x"; to: 6; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 70; easing.type: Easing.OutQuad }
            }

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18; spacing: 12
                Text {
                    id: passPrompt
                    text: passInput.text.length === 0 ? "PASSCODE" : lockRoot.passDots
                    font.family: lockRoot.altFont; font.pixelSize: 12
                    font.weight: Font.Bold; font.letterSpacing: 3
                    color: lockRoot.failed ? lockRoot.failC : lockRoot.fg
                    Layout.fillWidth: true; Layout.fillHeight: true
                    verticalAlignment: Text.AlignVCenter
                }
                Rectangle {
                    id: caret; width: 1; height: 18; color: lockRoot.fg
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
    }

    property string passDots: "•".repeat(Math.min(passInput.text.length, 24))

    Timer { interval: 200; repeat: true; running: true; triggeredOnStart: true
        onTriggered: { if (!passInput.activeFocus) passInput.forceActiveFocus() }
    }

    Component.onCompleted: {
        lockRoot.opacity = 0
        openAnim.start()
        passInput.forceActiveFocus()
        inputPopSeq.start()
    }
}
