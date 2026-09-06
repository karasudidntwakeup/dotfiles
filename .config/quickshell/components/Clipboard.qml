import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: clipMgr

    property var rootRef: null
    property bool active: false

    signal requestClose()

    readonly property int cardWidth: 620
    readonly property int rowHeight: 46
    readonly property int maxRows: 8
    readonly property int searchHeight: 40
    readonly property int pad: 14
    readonly property int cornerRadius: 20

    readonly property string cardTile: "secondary_fixed"
    readonly property color cardColor: rootRef
        ? (rootRef.qsLight
            ? rootRef.pillColor(cardTile)
            : rootRef.colorOf(cardTile))
        : "#f3dfd1"
    readonly property color cardBorder: rootRef
        ? rootRef.withAlpha(rootRef.colorOf("outline_variant"),
            rootRef.qsLight ? 0.5 : 0.35)
        : "#00000000"

    readonly property color fg: rootRef
        ? (rootRef.qsLight ? rootRef.qsPillFg : rootRef.textColor)
        : "#000000"
    readonly property color accent: fg
    readonly property color accentText: rootRef && rootRef.qsLight
        ? "#000000" : "#ffffff"
    readonly property color selectedFg: accentText
    readonly property color errorColor: rootRef ? rootRef.error : "#e30000"
    readonly property string iconFont: rootRef ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string fontFamily: rootRef ? rootRef.fontFamily : "Ndot 57"
    readonly property string uiFont: rootRef ? rootRef.uiFont : "Inter"
    readonly property int fontSize: rootRef ? rootRef.fontSize : 13
    readonly property string thumbDir: "/tmp/quickshell-cliphist"

    function alpha(c: color, a: double): color {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // Entrance/exit: pops up from the bottom edge like the app launcher.
    property real animProgress: clipMgr.active ? 1.0 : 0.0
    Behavior on animProgress {
        NumberAnimation {
            duration: clipMgr.active ? 320 : 220
            easing.type: Easing.OutCubic
        }
    }

    readonly property int bottomMargin: 24
    readonly property real slideOffset: (1.0 - clipMgr.animProgress)
        * (clipMgr.bottomMargin * 2 + card.height)

    opacity: clipMgr.animProgress

    property var allEntries: []
    ListModel { id: listModel }
    property int totalCount: 0

    onActiveChanged: {
        if (clipMgr.active) {
            searchField.text = ""
            clipMgr.reload()
            focusRequest.restart()
        }
    }

    Timer {
        id: focusRequest
        interval: 40
        repeat: false
        onTriggered: searchField.forceActiveFocus()
    }

    function reload() {
        clipMgr.allEntries = []
        listModel.clear()
        clipMgr.totalCount = 0
        clipProc.running = true
    }

    Process {
        id: clipProc
        command: ["sh", "-c", "cliphist list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: clipMgr.ingest(this.text)
        }
    }

    function ingest(raw) {
        var arr = []
        if (raw) {
            var lines = raw.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                if (!line) continue
                var t = line.indexOf("\t")
                if (t <= 0) continue
                var entryId = line.substring(0, t).trim()
                if (!/^\d+$/.test(entryId)) continue
                arr.push({ entryId: entryId, preview: line.substring(t + 1).replace(/\s+$/g, "") })
            }
        }
        clipMgr.allEntries = arr
        clipMgr.totalCount = arr.length
        clipMgr.applyFilter(searchField.text)
    }

    function applyFilter(text) {
        var q = (text || "").toLowerCase()
        var src = clipMgr.allEntries
        listModel.clear()
        for (var i = 0; i < src.length; i++) {
            var e = src[i]
            if (q.length > 0 && e.preview.toLowerCase().indexOf(q) < 0) continue
            listModel.append({ entryId: e.entryId, preview: e.preview })
        }
        listView.currentIndex = 0
    }

    function copyEntry(eid) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode '" + eid + "' | wl-copy"])
        clipMgr.requestClose()
    }

    function deleteEntry(eid) {
        Quickshell.execDetached(["sh", "-c", "cliphist delete '" + eid + "'"])
        var src = clipMgr.allEntries
        for (var i = 0; i < src.length; i++) {
            if (src[i].entryId === eid) { src.splice(i, 1); break }
        }
        clipMgr.totalCount = src.length
        clipMgr.applyFilter(searchField.text)
        if (listView.currentIndex >= listModel.count)
            listView.currentIndex = Math.max(0, listModel.count - 1)
    }

    function deleteSelected() {
        if (listModel.count === 0) return
        var idx = listView.currentIndex
        if (idx < 0 || idx >= listModel.count) return
        clipMgr.deleteEntry(listModel.get(idx).entryId)
    }

    function activate() {
        if (listModel.count === 0) return
        var idx = listView.currentIndex
        if (idx < 0 || idx >= listModel.count) return
        clipMgr.copyEntry(listModel.get(idx).entryId)
    }

    function wipeAll() {
        Quickshell.execDetached(["cliphist", "wipe"])
        clipMgr.allEntries = []
        clipMgr.totalCount = 0
        clipMgr.applyFilter(searchField.text)
    }

    function wipeArm() { clipMgr.wipeArmed = true }
    function wipeDisarm() { clipMgr.wipeArmed = false }

    property bool wipeArmed: false
    Timer {
        id: wipeDisarmTimer
        interval: 2600
        repeat: false
        onTriggered: clipMgr.wipeArmed = false
    }
    onWipeArmedChanged: {
        if (clipMgr.wipeArmed) {
            wipeDisarmTimer.restart()
            clipMgr.wipeStateText = "Confirm clear"
        } else {
            clipMgr.wipeStateText = "Clear all"
        }
    }
    property string wipeStateText: "Clear all"

    function imageLabel(preview) {
        return preview
            .replace(/\[\[\s*binary data/i, "")
            .replace(/\s*\]\]\s*$/, "")
            .trim()
            || "image"
    }

    Rectangle {
        z: 0
        anchors.fill: parent
        color: "transparent"
        MouseArea {
            anchors.fill: parent
            onClicked: clipMgr.requestClose()
        }
    }

    Rectangle {
        id: card
        z: 1
        width: clipMgr.cardWidth
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.floor(parent.height - card.height - clipMgr.bottomMargin) + clipMgr.slideOffset
        height: contentColumn.implicitHeight + clipMgr.pad * 2
        radius: clipMgr.cornerRadius
        color: clipMgr.cardColor
        border.width: 1
        border.color: clipMgr.cardBorder
        clip: true

        Column {
            id: contentColumn
            x: clipMgr.pad
            y: clipMgr.pad
            width: clipMgr.cardWidth - clipMgr.pad * 2
            spacing: 8

            RowLayout {
                width: parent.width
                spacing: 6

                Text {
                    text: "󰆓"
                    color: clipMgr.fg
                    font.family: clipMgr.iconFont
                    font.pixelSize: clipMgr.fontSize + 2
                    Layout.preferredWidth: 22
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Clipboard"
                    color: clipMgr.fg
                    font.family: clipMgr.fontFamily
                    font.pixelSize: clipMgr.fontSize + 1
                    font.weight: Font.Black
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text: clipMgr.totalCount + (clipMgr.totalCount === 1 ? " item" : " items")
                    color: clipMgr.alpha(clipMgr.fg, 0.5)
                    font.family: clipMgr.uiFont
                    font.pixelSize: clipMgr.fontSize - 2
                    verticalAlignment: Text.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: wipeBtn
                    Layout.preferredWidth: wipeText.implicitWidth + 20
                    Layout.preferredHeight: 24
                    radius: 7
                    color: clipMgr.wipeArmed
                        ? (wipeHover.containsMouse ? clipMgr.alpha(clipMgr.errorColor, 0.7) : clipMgr.errorColor)
                        : (wipeHover.containsMouse ? clipMgr.alpha(clipMgr.fg, 0.25) : clipMgr.alpha(clipMgr.fg, 0.1))
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: wipeText
                        anchors.centerIn: parent
                        text: clipMgr.wipeArmed ? "Confirm clear" : "󰇘 Clear all"
                        color: clipMgr.wipeArmed ? "#ffffff" : clipMgr.fg
                        font.family: clipMgr.uiFont
                        font.pixelSize: clipMgr.fontSize - 1
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: wipeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (clipMgr.wipeArmed) {
                                clipMgr.wipeAll()
                                clipMgr.wipeDisarm()
                            } else {
                                clipMgr.wipeArm()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 6
                    color: closeHover.containsMouse
                        ? clipMgr.alpha(clipMgr.fg, 0.2)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: clipMgr.fg
                        font.family: clipMgr.iconFont
                        font.pixelSize: clipMgr.fontSize
                    }

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipMgr.requestClose()
                    }
                }
            }

            // Search field
            Rectangle {
                id: searchBox
                width: parent.width
                height: clipMgr.searchHeight
                radius: clipMgr.searchHeight / 2
                color: clipMgr.alpha(clipMgr.fg, 0.08)
                border.width: 1
                border.color: searchField.activeFocus
                    ? clipMgr.alpha(clipMgr.fg, 0.4)
                    : clipMgr.alpha(clipMgr.fg, 0.12)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 6
                    spacing: 8

                    Text {
                        text: "󰀂"
                        color: clipMgr.alpha(clipMgr.fg, 0.55)
                        font.family: clipMgr.iconFont
                        font.pixelSize: clipMgr.fontSize + 1
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: clipMgr.fg
                        font.family: clipMgr.uiFont
                        font.pixelSize: clipMgr.fontSize + 1
                        font.weight: Font.Medium
                        placeholderText: "Search history"
                        placeholderTextColor: clipMgr.alpha(clipMgr.fg, 0.4)
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter
                        background: Item {}

                        onTextEdited: clipMgr.applyFilter(searchField.text)

                        Keys.onDownPressed: event => {
                            if (listModel.count > 0 && listView.currentIndex < listModel.count - 1)
                                listView.currentIndex++
                            event.accepted = true
                        }
                        Keys.onUpPressed: event => {
                            if (listView.currentIndex > 0) listView.currentIndex--
                            event.accepted = true
                        }
                        Keys.onReturnPressed: event => {
                            clipMgr.activate()
                            event.accepted = true
                        }
                        Keys.onDeletePressed: event => {
                            clipMgr.deleteSelected()
                            event.accepted = true
                        }
                        Keys.onEscapePressed: event => {
                            clipMgr.requestClose()
                            event.accepted = true
                        }
                    }

                    Rectangle {
                        id: clearBtn
                        visible: searchField.text.length > 0
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 11
                        color: clearHover.containsMouse
                            ? clipMgr.alpha(clipMgr.fg, 0.25)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: clipMgr.fg
                            font.family: clipMgr.iconFont
                            font.pixelSize: clipMgr.fontSize
                        }

                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = ""
                                searchField.forceActiveFocus()
                                clipMgr.applyFilter("")
                            }
                        }
                    }
                }
            }

            // Entry list
            Item {
                id: listContainer
                width: parent.width
                height: listModel.count === 0
                    ? 96
                    : Math.min(clipMgr.maxRows, listModel.count) * clipMgr.rowHeight
                clip: true

                ListView {
                    id: listView
                    anchors.fill: parent
                    model: listModel
                    spacing: 4
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Rectangle {
                        id: morphHighlight
                        parent: listView.contentItem
                        z: 0
                        visible: listModel.count > 0 && listView.currentIndex >= 0 && listView.currentItem !== null
                        width: listView.width
                        height: clipMgr.rowHeight
                        radius: 9
                        color: clipMgr.accent

                        readonly property real targetY: (listView.currentIndex >= 0 && listView.currentItem !== null)
                            ? listView.currentItem.y : 0
                        y: targetY

                        Behavior on y {
                            NumberAnimation {
                                duration: 240
                                easing.type: Easing.OutQuint
                            }
                        }
                    }

                    delegate: Item {
                        required property int index
                        required property string entryId
                        required property string preview

                        readonly property bool isSelected: listView.currentIndex === index
                        readonly property bool isImage: preview.indexOf("binary data") >= 0
                        readonly property string thumbPath: clipMgr.thumbDir + "/" + entryId + ".png"

                        width: listView.width
                        height: clipMgr.rowHeight
                        z: 1

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: rowHover.containsMouse && !isSelected
                                ? clipMgr.alpha(clipMgr.fg, 0.08)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: isSelected
                                        ? clipMgr.alpha(clipMgr.accentText, 0.14)
                                        : clipMgr.alpha(clipMgr.fg, 0.10)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    visible: isImage
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    mipmap: true
                                    cache: false
                                    source: ""

                                    // Decode the cached thumbnail (once per open; the file
                                    // persists in /tmp so later opens reuse it instantly).
                                    Process {
                                        id: thumbGen
                                        command: ["sh", "-c",
                                            "mkdir -p " + clipMgr.thumbDir +
                                            " && cliphist decode '" + entryId +
                                            "' > '" + thumbPath + "'"]
                                        onExited: code => {
                                            if (code === 0)
                                                thumbImg.source = "file://" + thumbPath + "?t=" + Date.now()
                                        }
                                    }

                                    Component.onCompleted: {
                                        if (isImage) thumbGen.running = true
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !isImage
                                    text: "󰆓"
                                    color: isSelected ? clipMgr.selectedFg : clipMgr.fg
                                    font.family: clipMgr.iconFont
                                    font.pixelSize: clipMgr.fontSize
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: isImage ? clipMgr.imageLabel(preview)
                                        : (preview.length === 0 ? "(empty)" : preview)
                                    color: isSelected ? clipMgr.selectedFg : clipMgr.fg
                                    font.family: isImage ? clipMgr.uiFont : clipMgr.fontFamily
                                    font.pixelSize: clipMgr.fontSize + (isSelected ? 1 : 0)
                                    font.weight: isSelected ? Font.Black : Font.Medium
                                    maximumLineCount: preview.length === 0 ? 1 : 2
                                    clip: true
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Text {
                                    visible: isImage
                                    width: parent.width
                                    text: "image — " + preview
                                    elide: Text.ElideRight
                                    font.family: clipMgr.uiFont
                                    font.pixelSize: Math.max(9, clipMgr.fontSize - 2)
                                    color: isSelected
                                        ? clipMgr.alpha(clipMgr.selectedFg, 0.75)
                                        : clipMgr.alpha(clipMgr.fg, 0.55)
                                }
                            }

                            Text {
                                visible: !isSelected && !rowHover.containsMouse && !deleteHover.containsMouse
                                Layout.preferredWidth: 16
                                Layout.alignment: Qt.AlignVCenter
                                text: "󰄴"
                                color: clipMgr.alpha(clipMgr.fg, 0.35)
                                font.family: clipMgr.iconFont
                                font.pixelSize: clipMgr.fontSize
                            }

                            Rectangle {
                                id: deleteBtn
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                radius: 6
                                color: deleteHover.containsMouse
                                    ? clipMgr.alpha(clipMgr.errorColor, 0.5)
                                    : clipMgr.alpha(clipMgr.fg, isSelected ? 0.25 : 0.12)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰇘"
                                    color: deleteHover.containsMouse ? "#ffffff" : clipMgr.fg
                                    font.family: clipMgr.iconFont
                                    font.pixelSize: clipMgr.fontSize
                                }

                                MouseArea {
                                    id: deleteHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        listView.currentIndex = index
                                        clipMgr.deleteEntry(entryId)
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                listView.currentIndex = index
                                clipMgr.activate()
                            }
                        }
                    }
                }

                // Empty state (overlays the list container)
                Item {
                    anchors.fill: parent
                    visible: listModel.count === 0

                    MouseArea {
                        anchors.fill: parent
                        onClicked: clipMgr.requestClose()
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰆓"
                            color: clipMgr.alpha(clipMgr.fg, 0.35)
                            font.family: clipMgr.iconFont
                            font.pixelSize: clipMgr.fontSize + 14
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: searchField.text.length > 0
                                ? "No matches"
                                : "Clipboard is empty"
                            color: clipMgr.alpha(clipMgr.fg, 0.55)
                            font.family: clipMgr.uiFont
                            font.pixelSize: clipMgr.fontSize
                        }
                    }
                }
            }

            // Footer hints
            RowLayout {
                width: parent.width
                spacing: 6

                Item { Layout.fillWidth: true }

                Text {
                    text: "Enter  copy      Del  remove      Esc  close"
                    color: clipMgr.alpha(clipMgr.fg, 0.45)
                    font.family: clipMgr.uiFont
                    font.pixelSize: Math.max(9, clipMgr.fontSize - 2)
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}