import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: notes

    property var rootRef: null
    property bool active: false

    signal requestClose()

    readonly property int cardWidth: 620
    readonly property int rowHeight: 46
    readonly property int maxRows: 8
    readonly property int searchHeight: 40
    readonly property int pad: 14
    readonly property int cornerRadius: 12

    readonly property string cardTile: "surface"
    readonly property color cardColor: rootRef
        ? (rootRef.qsLight
            ? rootRef.pillColor(cardTile)
            : rootRef.colorOf(cardTile))
        : "#f3dfd1"
    readonly property color cardBorder: rootRef
        ? rootRef.withAlpha(rootRef.colorOf("widget_border"),
            rootRef.qsLight ? 0.7 : 0.5)
        : "#00000000"

    readonly property color fg: rootRef
        ? notes.contrastColor(notes.cardColor)
        : "#000000"
    readonly property color accent: rootRef
        ? Qt.color(rootRef.colorOf("secondary_container"))
        : "#ebcb8b"
    readonly property color accentText: notes.contrastColor(notes.accent)
    readonly property color selectedFg: accentText
    readonly property color errorColor: rootRef ? Qt.color(rootRef.colorOf("widget_error")) : "#e30000"

    function alpha(c: color, a: double): color {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function _lin(v: double): double {
        if (v <= 0.03928) return v / 12.92
        return Math.pow((v + 0.055) / 1.055, 2.4)
    }

    function relLum(c: color): double {
        return 0.2126 * notes._lin(c.r) + 0.7152 * notes._lin(c.g) + 0.0722 * notes._lin(c.b)
    }

    function contrastColor(c: color): color {
        var l = notes.relLum(c)
        var white = (1.05) / (l + 0.05)
        var black = (l + 0.05) / (0.05)
        return white >= black ? "#ffffff" : "#000000"
    }
    readonly property string iconFont: rootRef && rootRef.iconFont ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string fontFamily: uiFont
    readonly property string uiFont: "Geist"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13
    readonly property string notesScript: Quickshell.shellDir + "/scripts/notes.py"

    property real animProgress: notes.active ? 1.0 : 0.0
    Behavior on animProgress {
        NumberAnimation {
            duration: notes.active ? 180 : 140
            easing.type: Easing.OutCubic
        }
    }

    readonly property int bottomMargin: 24

    opacity: notes.animProgress

    property var allNotes: []
    ListModel { id: listModel }
    property int totalCount: 0

    onActiveChanged: {
        if (notes.active) {
            notesField.text = ""
            searchField.text = ""
            notes.reload()
            addFocus.restart()
        }
    }

    Timer {
        id: addFocus
        interval: 40
        repeat: false
        onTriggered: notesField.forceActiveFocus()
    }

    Timer {
        id: searchFocus
        interval: 40
        repeat: false
        onTriggered: searchField.forceActiveFocus()
    }

    function reload() {
        notes.allNotes = []
        listModel.clear()
        notes.totalCount = 0
        listProc.running = true
    }

    Process {
        id: listProc
        command: ["python3", notes.notesScript, "list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: notes.ingest(this.text)
        }
    }

    function ingest(raw) {
        var arr = []
        if (raw) {
            var lines = raw.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                if (!line) continue
                try {
                    var o = JSON.parse(line)
                    if (o && o.id) arr.push({ id: o.id, ts: o.ts || "", text: o.text || "" })
                } catch (e) {}
            }
        }
        notes.allNotes = arr
        notes.totalCount = arr.length
        notes.applyFilter(searchField.text)
    }

    function applyFilter(text) {
        var q = (text || "").toLowerCase()
        var src = notes.allNotes
        listModel.clear()
        for (var i = 0; i < src.length; i++) {
            var e = src[i]
            if (q.length > 0 && e.text.toLowerCase().indexOf(q) < 0) continue
            listModel.append({ noteId: e.id, ts: e.ts, note: e.text })
        }
        listView.currentIndex = 0
    }

    function saveNote() {
        var raw = notesField.text
        if (addProc.running || !raw || raw.trim().length === 0) return
        addProc.command = ["python3", notes.notesScript, "add", raw.trim()]
        addProc.running = true
    }

    Process {
        id: addProc
        onExited: code => {
            if (code === 0) {
                notesField.text = ""
                notes.reload()
            }
            addFocus.restart()
        }
    }

    function copyNote(nid) {
        copyProc.command = ["python3", notes.notesScript, "copy", nid]
        copyProc.running = true
    }

    Process {
        id: copyProc
        onExited: code => {
            if (code === 0) notes.requestClose()
        }
    }

    function deleteNote(nid) {
        delProc.command = ["python3", notes.notesScript, "delete", nid]
        delProc.running = true
    }

    Process {
        id: delProc
        onExited: code => {
            if (code === 0) {
                var src = notes.allNotes
                for (var i = 0; i < src.length; i++) {
                    if (src[i].id === delNoteId) { src.splice(i, 1); break }
                }
                notes.totalCount = src.length
                notes.applyFilter(searchField.text)
                if (listView.currentIndex >= listModel.count)
                    listView.currentIndex = Math.max(0, listModel.count - 1)
            }
        }
    }
    property string delNoteId: ""

    function deleteSelected() {
        if (listModel.count === 0) return
        var idx = listView.currentIndex
        if (idx < 0 || idx >= listModel.count) return
        notes.delNoteId = listModel.get(idx).noteId
        notes.deleteNote(notes.delNoteId)
    }

    function activate() {
        if (listModel.count === 0) return
        var idx = listView.currentIndex
        if (idx < 0 || idx >= listModel.count) return
        notes.copyNote(listModel.get(idx).noteId)
    }

    function wipeAll() {
        wipeProc.command = ["python3", notes.notesScript, "clear"]
        wipeProc.running = true
    }

    Process {
        id: wipeProc
        onExited: code => {
            if (code === 0) {
                notes.allNotes = []
                notes.totalCount = 0
                notes.applyFilter(searchField.text)
            }
        }
    }

    function wipeArm() { notes.wipeArmed = true }
    function wipeDisarm() { notes.wipeArmed = false }

    property bool wipeArmed: false
    Timer {
        id: wipeDisarmTimer
        interval: 2600
        repeat: false
        onTriggered: notes.wipeArmed = false
    }
    onWipeArmedChanged: {
        if (notes.wipeArmed) {
            wipeDisarmTimer.restart()
            notes.wipeStateText = "Confirm clear"
        } else {
            notes.wipeStateText = "Clear all"
        }
    }
    property string wipeStateText: "Clear all"

    Rectangle {
        z: 0
        anchors.fill: parent
        color: "transparent"
        MouseArea {
            anchors.fill: parent
            onClicked: notes.requestClose()
        }
    }
    Rectangle {
        id: card


        z: 1
        width: notes.cardWidth
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.floor(parent.height - card.height - notes.bottomMargin)
        height: contentColumn.implicitHeight + notes.pad * 2
        radius: notes.cornerRadius
        color: notes.cardColor
        border.width: 1
        border.color: notes.cardBorder
        clip: true


        transform: Translate {
            y: (1.0 - notes.animProgress) * 8
        }

        Column {
            id: contentColumn
            x: notes.pad
            y: notes.pad
            width: notes.cardWidth - notes.pad * 2
            spacing: 8

            RowLayout {
                width: parent.width
                spacing: 6

                Text {
                    text: "󰎚"
                    color: notes.accent
                    font.family: notes.iconFont
                    font.pixelSize: notes.fontSize + 2
                    Layout.preferredWidth: 22
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Notes"
                    color: notes.fg
                    font.family: notes.fontFamily
                    font.pixelSize: notes.fontSize + 1
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text: notes.totalCount + (notes.totalCount === 1 ? " note" : " notes")
                    color: notes.alpha(notes.fg, 0.5)
                    font.family: notes.uiFont
                    font.pixelSize: notes.fontSize - 2
                    verticalAlignment: Text.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: wipeBtn
                    Layout.preferredWidth: wipeText.implicitWidth + 20
                    Layout.preferredHeight: 24
                    radius: 7
                    color: notes.wipeArmed
                        ? (wipeHover.containsMouse ? notes.alpha(notes.errorColor, 0.7) : notes.errorColor)
                        : (wipeHover.containsMouse ? notes.alpha(notes.fg, 0.25) : notes.alpha(notes.fg, 0.1))
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: wipeText
                        anchors.centerIn: parent
                        text: notes.wipeArmed ? "Confirm clear" : "󰆴 Clear all"
                        color: notes.wipeArmed ? "#ffffff" : notes.fg
                        font.family: notes.uiFont
                        font.pixelSize: notes.fontSize - 1
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: wipeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (notes.wipeArmed) {
                                notes.wipeAll()
                                notes.wipeDisarm()
                            } else {
                                notes.wipeArm()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 6
                    color: closeHover.containsMouse
                        ? notes.alpha(notes.fg, 0.2)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: notes.fg
                        font.family: notes.iconFont
                        font.pixelSize: notes.fontSize
                    }

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notes.requestClose()
                    }
                }
            }

            Rectangle {
                id: addBox
                width: parent.width
                height: notes.searchHeight
                radius: 8
                color: notes.alpha(notes.accent, 0.18)
                border.width: 1
                border.color: notesField.activeFocus
                    ? notes.alpha(notes.accent, 0.7)
                    : notes.alpha(notes.fg, 0.12)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 6
                    spacing: 8

                    Text {
                        text: "󰏫"
                        color: notes.alpha(notes.accent, 0.9)
                        font.family: notes.iconFont
                        font.pixelSize: notes.fontSize + 1
                    }

                    TextField {
                        id: notesField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: notes.fg
                        font.family: notes.uiFont
                        font.pixelSize: notes.fontSize + 1
                        font.weight: Font.Medium
                        placeholderText: "Jot a note and press Enter"
                        placeholderTextColor: notes.alpha(notes.fg, 0.4)
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter
                        background: Item {}

                        onAccepted: notes.saveNote()

                        Keys.onDownPressed: event => {
                            if (listModel.count > 0 && listView.currentIndex < listModel.count - 1)
                                listView.currentIndex++
                            event.accepted = true
                        }
                        Keys.onUpPressed: event => {
                            if (listView.currentIndex > 0) listView.currentIndex--
                            event.accepted = true
                        }
                        Keys.onEscapePressed: event => {
                            if (notesField.text.length > 0)
                                notesField.text = ""
                            else
                                notes.requestClose()
                            event.accepted = true
                        }
                    }

                    Rectangle {
                        id: saveBtn
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: saveHover.containsMouse
                            ? notes.accent
                            : notes.alpha(notes.accent, 0.6)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰐕"
                            color: notes.accentText
                            font.family: notes.iconFont
                            font.pixelSize: notes.fontSize
                        }

                        MouseArea {
                            id: saveHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notes.saveNote()
                        }
                    }
                }
            }

            Rectangle {
                id: searchBox
                width: parent.width
                height: notes.searchHeight
                radius: 8
                color: notes.alpha(notes.fg, 0.08)
                border.width: 1
                border.color: searchField.activeFocus
                    ? notes.alpha(notes.fg, 0.4)
                    : notes.alpha(notes.fg, 0.12)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 6
                    spacing: 8

                    Text {
                        text: "󰍉"
                        color: notes.alpha(notes.fg, 0.55)
                        font.family: notes.iconFont
                        font.pixelSize: notes.fontSize + 1
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: notes.fg
                        font.family: notes.uiFont
                        font.pixelSize: notes.fontSize + 1
                        font.weight: Font.Medium
                        placeholderText: "Search notes"
                        placeholderTextColor: notes.alpha(notes.fg, 0.4)
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter
                        background: Item {}

                        onTextEdited: notes.applyFilter(searchField.text)

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
                            notes.activate()
                            event.accepted = true
                        }
                        Keys.onDeletePressed: event => {
                            notes.deleteSelected()
                            event.accepted = true
                        }
                        Keys.onEscapePressed: event => {
                            notes.requestClose()
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
                            ? notes.alpha(notes.fg, 0.25)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: notes.fg
                            font.family: notes.iconFont
                            font.pixelSize: notes.fontSize
                        }

                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = ""
                                searchField.forceActiveFocus()
                                notes.applyFilter("")
                            }
                        }
                    }
                }
            }

            Item {
                id: listContainer
                width: parent.width
                height: listModel.count === 0
                    ? 120
                    : Math.min(notes.maxRows, listModel.count) * notes.rowHeight
                        + Math.max(0, Math.min(notes.maxRows, listModel.count) - 1) * 8
                clip: true

                ListView {
                    id: listView
                    anchors.fill: parent
                    model: listModel
                    spacing: 8
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Rectangle {
                        id: morphHighlight
                        parent: listView.contentItem
                        z: 0
                        visible: listModel.count > 0 && listView.currentIndex >= 0 && listView.currentItem !== null
                        width: listView.width
                        height: notes.rowHeight
                        radius: 9
                        color: notes.accent

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
                        required property string noteId
                        required property string ts
                        required property string note

                        readonly property bool isSelected: listView.currentIndex === index

                        width: listView.width
                        height: notes.rowHeight
                        z: 1

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: rowHover.containsMouse && !isSelected
                                ? notes.alpha(notes.fg, 0.08)
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
                                        ? notes.alpha(notes.accent, 0.30)
                                        : notes.alpha(notes.fg, 0.10)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰎞"
                                    color: isSelected ? notes.selectedFg : notes.fg
                                    font.family: notes.iconFont
                                    font.pixelSize: notes.fontSize
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: note.length === 0 ? "(empty)" : note
                                    color: isSelected ? notes.selectedFg : notes.fg
                                    font.family: notes.fontFamily
                                    font.pixelSize: notes.fontSize
                                    font.weight: Font.Medium
                                    maximumLineCount: 2
                                    clip: true
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Text {
                                    visible: ts.length > 0
                                    width: parent.width
                                    text: ts
                                    elide: Text.ElideRight
                                    font.family: notes.uiFont
                                    font.pixelSize: Math.max(9, notes.fontSize - 2)
                                    color: isSelected
                                        ? notes.alpha(notes.selectedFg, 0.75)
                                        : notes.alpha(notes.fg, 0.55)
                                }
                            }

                            Rectangle {
                                id: copyBtn
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                radius: 6
                                color: copyHover.containsMouse
                                    ? notes.alpha(notes.accent, isSelected ? 0.7 : 0.5)
                                    : notes.alpha(notes.fg, isSelected ? 0.25 : 0.12)
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆏"
                                    color: copyHover.containsMouse ? notes.accentText
                                        : (isSelected ? notes.selectedFg : notes.fg)
                                    font.family: notes.iconFont
                                    font.pixelSize: notes.fontSize
                                }

                                MouseArea {
                                    id: copyHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        listView.currentIndex = index
                                        notes.copyNote(noteId)
                                    }
                                }
                            }

                            Rectangle {
                                id: deleteBtn
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                radius: 6
                                color: deleteHover.containsMouse
                                    ? notes.alpha(notes.errorColor, 0.5)
                                    : notes.alpha(notes.fg, isSelected ? 0.25 : 0.12)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    color: deleteHover.containsMouse ? "#ffffff" : notes.fg
                                    font.family: notes.iconFont
                                    font.pixelSize: notes.fontSize
                                }

                                MouseArea {
                                    id: deleteHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        listView.currentIndex = index
                                        notes.delNoteId = noteId
                                        notes.deleteNote(noteId)
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            anchors.rightMargin: 76
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                listView.currentIndex = index
                                notes.activate()
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: listModel.count === 0

                    MouseArea {
                        anchors.fill: parent
                        onClicked: notesField.forceActiveFocus()
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: searchField.text.length > 0
                                ? "No matching notes"
                                : "No notes yet — type one above"
                            color: notes.alpha(notes.fg, 0.55)
                            font.family: notes.uiFont
                            font.pixelSize: notes.fontSize
                        }
                    }
            }
        }
    }
}
}