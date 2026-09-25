import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Professional sticky-notes board.
// Same public contract as before: rootRef, active, requestClose().
Item {
    id: notes

    property var rootRef: null
    property bool active: false

    signal requestClose()

    readonly property int cardWidth: 720
    readonly property int pad: 16
    readonly property int cornerRadius: 0
    readonly property int searchHeight: 38

    // YtX-style Android roles: flat surface card, theme text tokens.
    readonly property color cardColor: rootRef ? Qt.color(rootRef.colorOf("surface_container")) : "#1f2c34"
    readonly property color fieldColor: rootRef ? Qt.color(rootRef.colorOf("surface_container_high")) : "#2a3942"
    readonly property color cardBorder: rootRef
        ? rootRef.withAlpha(Qt.color(rootRef.colorOf("outline_variant")), 0.5)
        : "#222d34"

    readonly property color fg: rootRef ? Qt.color(rootRef.colorOf("on_surface")) : "#e9edef"
    readonly property color muted: rootRef ? Qt.color(rootRef.colorOf("on_surface_variant")) : "#8696a0"
    readonly property color accent: rootRef
        ? Qt.color(rootRef.colorOf("secondary_container"))
        : "#ebcb8b"
    readonly property color accentText: rootRef ? rootRef.contrastColor(notes.accent) : "#000000"
    readonly property color errorColor: rootRef ? Qt.color(rootRef.colorOf("widget_error")) : "#e30000"

    readonly property string fontFamily: uiFont
    readonly property string uiFont: rootRef && rootRef.uiFont ? rootRef.uiFont : "Geist"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13
    readonly property string notesScript: Quickshell.shellDir + "/scripts/notes.py"

    // Sticky paper palette — pastel backgrounds, always dark ink.
    readonly property var stickyNames: ["yellow", "pink", "mint", "sky", "lilac", "peach"]
    readonly property color stickyInk: "#2b2517"

    function stickyBg(name) {
        switch (name) {
        case "pink": return "#f6bdd0"
        case "mint": return "#b3e3c3"
        case "sky": return "#b8d9f5"
        case "lilac": return "#d9c2ec"
        case "peach": return "#fbd9a4"
        default: return "#f8e08a"
        }
    }

    property real animProgress: notes.active ? 1.0 : 0.0
    Behavior on animProgress {
        Anim { type: Anim.Bouncy; easing.overshoot: 3.2 }
    }

    // Smooth opacity ramp decoupled from the bouncy slide: OutBack
    // finishes ~95% in the first 150ms, which reads as a pop.
    property real fadeProgress: notes.active ? 1.0 : 0.0
    Behavior on fadeProgress { Anim { type: Anim.SlowEffects } }

    readonly property int bottomMargin: 24
    opacity: notes.fadeProgress

    property var allNotes: []
    ListModel { id: gridModel }
    property int totalCount: 0
    property int pinnedCount: 0

    // Composer state.
    property string editingId: ""
    property string editingTitle: ""
    property string composerColor: "yellow"
    property bool composerDirty: bodyArea.text.length > 0

    onActiveChanged: {
        if (notes.active) {
            notes.cancelEdit()
            searchField.text = ""
            notes.reload()
            addFocus.restart()
        }
    }

    Timer {
        id: addFocus
        interval: 40
        repeat: false
        onTriggered: bodyArea.forceActiveFocus()
    }

    // ---- data ----
    function reload() {
        notes.allNotes = []
        gridModel.clear()
        notes.totalCount = 0
        notes.pinnedCount = 0
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
                    if (o && o.id) {
                        var c = o.color || "yellow"
                        if (notes.stickyNames.indexOf(c) < 0) c = "yellow"
                        arr.push({
                            noteId: o.id,
                            title: o.title || "",
                            note: o.text || "",
                            color: c,
                            pinned: o.pinned === true,
                            ts: o.ts || "",
                            updated: o.updated || o.ts || "",
                            updatedMs: o.updated_ms || o.created_ms || 0
                        })
                    }
                } catch (e) {}
            }
        }
        // Pinned first, newest first.
        arr.sort(function(a, b) {
            if (a.pinned !== b.pinned) return a.pinned ? -1 : 1
            return (b.updatedMs || 0) - (a.updatedMs || 0)
        })
        var pins = 0
        for (var k = 0; k < arr.length; k++) if (arr[k].pinned) pins++
        notes.allNotes = arr
        notes.totalCount = arr.length
        notes.pinnedCount = pins
        notes.applyFilter(searchField.text)
    }

    function applyFilter(text) {
        var q = (text || "").toLowerCase()
        var src = notes.allNotes
        gridModel.clear()
        for (var i = 0; i < src.length; i++) {
            var e = src[i]
            if (q.length > 0) {
                var hay = (e.title + "\n" + e.note).toLowerCase()
                if (hay.indexOf(q) < 0) continue
            }
            gridModel.append({
                noteId: e.noteId, title: e.title, note: e.note,
                stickyColor: e.color, pinned: e.pinned,
                ts: e.ts, updated: e.updated
            })
        }
    }

    function runMut(args) {
        if (mutProc.running) return
        mutProc.command = ["python3", notes.notesScript].concat(args)
        mutProc.running = true
    }

    Process {
        id: mutProc
        onExited: code => { if (code === 0) notes.reload() }
    }

    Process {
        id: copyProc
        onExited: code => { if (code === 0) notes.requestClose() }
    }

    // ---- composer actions ----
    function saveComposer() {
        var body = bodyArea.text.trim()
        if (mutProc.running || body.length === 0) return
        if (notes.editingId.length > 0)
            notes.runMut(["update", notes.editingId, bodyArea.text, notes.editingTitle, notes.composerColor])
        else
            notes.runMut(["add", bodyArea.text, "", notes.composerColor])
        notes.cancelEdit()
    }

    function startEdit(noteId) {
        for (var i = 0; i < notes.allNotes.length; i++) {
            var e = notes.allNotes[i]
            if (e.noteId === noteId) {
                notes.editingId = noteId
                notes.editingTitle = e.title
                bodyArea.text = e.note
                notes.composerColor = e.color
                bodyArea.forceActiveFocus()
                return
            }
        }
    }

    function cancelEdit() {
        notes.editingId = ""
        notes.editingTitle = ""
        bodyArea.text = ""
        notes.composerColor = "yellow"
    }

    function togglePin(nid) { notes.runMut(["toggle-pin", nid]) }
    function setColor(nid, c) { notes.runMut(["set-color", nid, c]) }
    function duplicateNote(nid) { notes.runMut(["duplicate", nid]) }
    function copyNote(nid) {
        if (copyProc.running) return
        copyProc.command = ["python3", notes.notesScript, "copy", nid]
        copyProc.running = true
    }
    function deleteNote(nid) { notes.runMut(["delete", nid]) }

    function wipeAll() { notes.runMut(["clear"]) }

    property bool wipeArmed: false
    Timer {
        id: wipeDisarmTimer
        interval: 2600
        repeat: false
        onTriggered: notes.wipeArmed = false
    }
    onWipeArmedChanged: { if (notes.wipeArmed) wipeDisarmTimer.restart() }

    function headerStats() {
        var t = notes.totalCount + (notes.totalCount === 1 ? " note" : " notes")
        if (notes.pinnedCount > 0) t += "  •  " + notes.pinnedCount + " pinned"
        return t
    }

    // ---- chrome ----
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
        height: Math.min(contentColumn.implicitHeight + notes.pad * 2, parent.height - 60)
        radius: notes.cornerRadius
        color: notes.cardColor
        border.width: 1
        border.color: notes.cardBorder
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

        transform: Translate {
            y: (1.0 - notes.animProgress) * 8
        }

        Column {
            id: contentColumn
            x: notes.pad
            y: notes.pad
            width: notes.cardWidth - notes.pad * 2
            spacing: 10

            // Header
            RowLayout {
                width: parent.width
                spacing: 6

                QIcon {
                    source: Qt.resolvedUrl("../assets/icons/notes.svg")
                    color: notes.accent
                    iconSize: notes.fontSize + 4
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "Sticky Notes"
                    color: notes.fg
                    font.family: notes.fontFamily
                    font.pixelSize: notes.fontSize + 1
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                }
                QIcon {
                    source: Qt.resolvedUrl("../assets/icons/y2k-star-4.svg")
                    color: rootRef.withAlpha(notes.accent, 0.8)
                    iconSize: notes.fontSize + 1
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: notes.headerStats()
                    color: notes.muted
                    font.family: notes.uiFont
                    font.pixelSize: notes.fontSize - 2
                    verticalAlignment: Text.AlignVCenter
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    id: wipeBtn
                    Layout.preferredWidth: wipeText.implicitWidth + 20
                    Layout.preferredHeight: 24
                    radius: 0
                    color: notes.wipeArmed
                        ? (wipeHover.containsMouse ? rootRef.withAlpha(notes.errorColor, 0.7) : notes.errorColor)
                        : (wipeHover.containsMouse ? rootRef.withAlpha(notes.fg, 0.25) : rootRef.withAlpha(notes.fg, 0.1))
                    Behavior on color { CAnim { type: CAnim.FastEffects } }
                    Row {
                        id: wipeText
                        anchors.centerIn: parent
                        spacing: 5
                        QIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: Qt.resolvedUrl("../assets/icons/trash.svg")
                            color: notes.wipeArmed ? "#ffffff" : notes.fg
                            iconSize: notes.fontSize
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: notes.wipeArmed ? "Confirm clear" : "Clear all"
                            color: notes.wipeArmed ? "#ffffff" : notes.fg
                            font.family: notes.uiFont
                            font.pixelSize: notes.fontSize - 1
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: wipeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (notes.wipeArmed) {
                                notes.wipeAll()
                                notes.wipeArmed = false
                            } else {
                                notes.wipeArmed = true
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 0
                    color: closeHover.containsMouse ? rootRef.withAlpha(notes.fg, 0.2) : "transparent"
                    Behavior on color { CAnim { type: CAnim.FastEffects } }
                    QIcon {
                        anchors.centerIn: parent
                        source: Qt.resolvedUrl("../assets/icons/close.svg")
                        color: notes.fg
                        iconSize: notes.fontSize + 2
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

            // Composer
            Rectangle {
                width: parent.width
                height: composerCol.implicitHeight + 20
                radius: 0
                color: rootRef.withAlpha(notes.stickyBg(notes.composerColor), 0.16)
                border.width: 1
                border.color: bodyArea.activeFocus
                    ? rootRef.withAlpha(notes.stickyBg(notes.composerColor), 0.8)
                    : rootRef.withAlpha(notes.fg, 0.12)
                Behavior on border.color { CAnim { type: CAnim.FastEffects } }

                Column {
                    id: composerCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        width: parent.width
                        spacing: 8
                        Text {
                            text: notes.editingId.length > 0 ? "Editing note" : "New note"
                            color: notes.muted
                            font.family: notes.uiFont
                            font.pixelSize: notes.fontSize - 1
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: notes.editingId.length > 0
                            text: "Cancel"
                            color: notes.muted
                            font.family: notes.uiFont
                            font.pixelSize: notes.fontSize - 1
                            font.underline: true
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notes.cancelEdit()
                            }
                        }
                    }

                    TextArea {
                        id: bodyArea
                        width: parent.width
                        height: 56
                        color: notes.fg
                        font.family: notes.uiFont
                        font.pixelSize: notes.fontSize
                        wrapMode: Text.Wrap
                        selectByMouse: true
                        placeholderText: "Write it down…  (Ctrl+Enter to pin it to the board)"
                        placeholderTextColor: rootRef.withAlpha(notes.fg, 0.45)
                        background: Item {}
                        Keys.onEscapePressed: event => {
                            if (notes.editingId.length > 0) notes.cancelEdit()
                            else if (bodyArea.text.length > 0) bodyArea.text = ""
                            else notes.requestClose()
                            event.accepted = true
                        }
                        Keys.onReturnPressed: event => {
                            if (event.modifiers & Qt.ControlModifier) {
                                notes.saveComposer()
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: 6
                        Row {
                            spacing: 6
                            Layout.alignment: Qt.AlignVCenter
                            Repeater {
                                model: notes.stickyNames
                                Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: 18
                                    height: 18
                                    radius: 0
                                    color: notes.stickyBg(modelData)
                                    border.width: notes.composerColor === modelData ? 2 : 1
                                    border.color: notes.composerColor === modelData ? notes.fg : Qt.rgba(0, 0, 0, 0.25)
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notes.composerColor = parent.modelData
                                    }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: {
                                var n = bodyArea.text.length
                                return n > 0 ? n + (n === 1 ? " char" : " chars") : ""
                            }
                            color: notes.muted
                            font.family: notes.uiFont
                            font.pixelSize: notes.fontSize - 2
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Rectangle {
                            id: saveBtn
                            Layout.preferredWidth: saveLabel.implicitWidth + 22
                            Layout.preferredHeight: 26
                            radius: 0
                            color: saveHover.containsMouse ? notes.accent : rootRef.withAlpha(notes.accent, 0.65)
                            Behavior on color { CAnim { type: CAnim.FastEffects } }
                            Row {
                                id: saveLabel
                                anchors.centerIn: parent
                                spacing: 6
                                QIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: Qt.resolvedUrl(notes.editingId.length > 0
                                        ? "../assets/icons/check.svg" : "../assets/icons/plus.svg")
                                    color: notes.accentText
                                    iconSize: notes.fontSize + 1
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: notes.editingId.length > 0 ? "Save" : "Stick it"
                                    color: notes.accentText
                                    font.family: notes.uiFont
                                    font.pixelSize: notes.fontSize
                                    font.weight: Font.DemiBold
                                }
                            }
                            MouseArea {
                                id: saveHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notes.saveComposer()
                            }
                        }
                    }
                }
            }

            // Search
            Rectangle {
                width: parent.width
                height: notes.searchHeight
                radius: 0
                color: notes.fieldColor
                border.width: 1
                border.color: searchField.inputFocus
                    ? rootRef.withAlpha(notes.fg, 0.6)
                    : notes.cardBorder
                Behavior on border.color { CAnim { type: CAnim.FastEffects } }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 6
                    spacing: 8
                    QIcon {
                        source: Qt.resolvedUrl("../assets/icons/search.svg")
                        color: notes.muted
                        iconSize: notes.fontSize + 3
                        Layout.alignment: Qt.AlignVCenter
                    }
                    CharField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        textColor: notes.fg
                        font.family: notes.uiFont
                        font.pixelSize: notes.fontSize
                        font.weight: Font.Medium
                        placeholderText: "Search notes"
                        placeholderTextColor: notes.muted
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter
                        onTextEdited: notes.applyFilter(searchField.text)
                        Keys.onEscapePressed: event => {
                            if (searchField.text.length > 0) {
                                searchField.text = ""
                                notes.applyFilter("")
                            } else {
                                notes.requestClose()
                            }
                            event.accepted = true
                        }
                        Keys.onReturnPressed: event => {
                            if (gridModel.count > 0) notes.startEdit(gridModel.get(0).noteId)
                            event.accepted = true
                        }
                    }
                    Rectangle {
                        visible: searchField.text.length > 0
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 0
                        color: clearHover.containsMouse ? rootRef.withAlpha(notes.fg, 0.25) : "transparent"
                        QIcon {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../assets/icons/close.svg")
                            color: notes.fg
                            iconSize: notes.fontSize + 2
                        }
                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = ""
                                notes.applyFilter("")
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // Sticky grid
            Item {
                width: parent.width
                height: gridModel.count === 0 ? 110 : Math.min(2, Math.ceil(gridModel.count / 2)) * 184
                clip: true

                GridView {
                    id: gridView
                    anchors.fill: parent
                    model: gridModel
                    cellWidth: Math.floor(width / 2)
                    cellHeight: 184
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    move: Transition {
                        Anim { property: "x"; type: Anim.BouncyFast; easing.overshoot: 3.0 }
                        Anim { property: "y"; type: Anim.BouncyFast; easing.overshoot: 3.0 }
                        Anim { property: "opacity"; to: 1; type: Anim.DefaultEffects }
                    }
                    displaced: Transition {
                        Anim { property: "x"; type: Anim.BouncyFast; easing.overshoot: 3.0 }
                        Anim { property: "y"; type: Anim.BouncyFast; easing.overshoot: 3.0 }
                    }
                    add: Transition {
                        Anim { property: "opacity"; from: 0; to: 1; type: Anim.DefaultEffects }
                        Anim { property: "scale"; from: 0.85; to: 1; type: Anim.BouncyFast; easing.overshoot: 3.5 }
                        Anim { property: "y"; from: 18; to: 0; type: Anim.BouncyFast; easing.overshoot: 3.0 }
                    }

                    delegate: Item {
                        required property int index
                        required property string noteId
                        required property string title
                        required property string note
                        required property string stickyColor
                        required property bool pinned
                        required property string ts
                        required property string updated

                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        Rectangle {
                            id: sticky
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 0
                            color: notes.stickyBg(stickyColor)
                            border.width: pinned ? 2 : 1
                            border.color: pinned
                                ? Qt.tint(notes.stickyBg(stickyColor), Qt.rgba(0, 0, 0, 0.35))
                                : Qt.rgba(0, 0, 0, 0.18)

                            // Click on empty paper edits the note.
                            // Declared first so the action buttons on top still get their clicks.
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onDoubleClicked: notes.startEdit(noteId)
                                onClicked: notes.startEdit(noteId)
                            }

                            // Tape strip
                            Rectangle {
                                anchors.top: parent.top
                                anchors.topMargin: -4
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 64
                                height: 15
                                radius: 0
                                rotation: index % 2 === 0 ? -3 : 3
                                color: Qt.rgba(1, 1, 1, 0.4)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.5)
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 10
                                anchors.topMargin: 14
                                spacing: 4

                                RowLayout {
                                    width: parent.width
                                    visible: title.length > 0 || pinned
                                    spacing: 6
                                    Text {
                                        visible: title.length > 0
                                        Layout.fillWidth: true
                                        text: title
                                        color: notes.stickyInk
                                        font.family: notes.fontFamily
                                        font.pixelSize: notes.fontSize
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                    Item {
                                        visible: title.length === 0
                                        Layout.fillWidth: true
                                        implicitHeight: 1
                                    }
                                    QIcon {
                                        visible: pinned
                                        source: Qt.resolvedUrl("../assets/icons/y2k-star-4.svg")
                                        color: notes.stickyInk
                                        iconSize: notes.fontSize + 2
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }

                                Text {
                                    width: parent.width
                                    height: 52
                                    text: note.length === 0 ? "—" : note
                                    color: Qt.rgba(notes.stickyInk.r, notes.stickyInk.g, notes.stickyInk.b, 0.88)
                                    font.family: notes.uiFont
                                    font.pixelSize: notes.fontSize - 1
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 3
                                }

                                // Recolor dots — each sticky recolors individually.
                                Row {
                                    spacing: 5
                                    Repeater {
                                        model: notes.stickyNames
                                        Rectangle {
                                            required property string modelData
                                            width: 12
                                            height: 12
                                            radius: 0
                                            color: notes.stickyBg(modelData)
                                            border.width: 1
                                            border.color: modelData === stickyColor
                                                ? notes.stickyInk : Qt.rgba(0, 0, 0, 0.3)
                                            opacity: hoverDot.containsMouse || modelData === stickyColor ? 1.0 : 0.55
                                            Behavior on opacity { CAnim { type: CAnim.FastEffects } }
                                            MouseArea {
                                                id: hoverDot
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: notes.setColor(noteId, parent.modelData)
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    width: parent.width
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: updated.length > 0 ? updated : ts
                                        color: Qt.rgba(notes.stickyInk.r, notes.stickyInk.g, notes.stickyInk.b, 0.6)
                                        font.family: notes.uiFont
                                        font.pixelSize: Math.max(9, notes.fontSize - 3)
                                        elide: Text.ElideRight
                                    }
                                    Repeater {
                                        model: [
                                            { "icon": "pencil.svg", "tip": "edit" },
                                            { "icon": "copy.svg", "tip": "copy" },
                                            { "icon": "plus.svg", "tip": "duplicate" },
                                            { "icon": "trash.svg", "tip": "delete" }
                                        ]
                                        Rectangle {
                                            required property var modelData
                                            required property int index
                                            Layout.preferredWidth: 22
                                            Layout.preferredHeight: 22
                                            radius: 0
                                            color: btnHover.containsMouse
                                                ? Qt.rgba(0, 0, 0, 0.18)
                                                : "transparent"
                                            Behavior on color { CAnim { type: CAnim.FastEffects } }
                                            QIcon {
                                                anchors.centerIn: parent
                                                source: Qt.resolvedUrl("../assets/icons/" + parent.modelData.icon)
                                                color: notes.stickyInk
                                                iconSize: notes.fontSize
                                            }
                                            MouseArea {
                                                id: btnHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (parent.modelData.tip === "edit") notes.startEdit(noteId)
                                                    else if (parent.modelData.tip === "copy") notes.copyNote(noteId)
                                                    else if (parent.modelData.tip === "duplicate") notes.duplicateNote(noteId)
                                                    else if (parent.modelData.tip === "delete") notes.deleteNote(noteId)
                                                }
                                            }
                                        }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        radius: 0
                                        color: pinHover.containsMouse
                                            ? Qt.rgba(0, 0, 0, 0.18)
                                            : (pinned ? Qt.rgba(0, 0, 0, 0.14) : "transparent")
                                        QIcon {
                                            anchors.centerIn: parent
                                            source: Qt.resolvedUrl("../assets/icons/y2k-star-4.svg")
                                            color: notes.stickyInk
                                            iconSize: notes.fontSize
                                        }
                                        MouseArea {
                                            id: pinHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: notes.togglePin(noteId)
                                        }
                                    }
                                }
                            }

                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: gridModel.count === 0
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        QIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: Qt.resolvedUrl("../assets/icons/y2k-star-4.svg")
                            color: notes.muted
                            iconSize: notes.fontSize + 14
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: searchField.text.length > 0
                                ? "No matching stickies"
                                : "Board is empty — write the first one above"
                            color: notes.muted
                            font.family: notes.uiFont
                            font.pixelSize: notes.fontSize
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: gridModel.count > 0
                text: "Click a sticky to edit  •  dots recolor it  •  star to pin  •  Ctrl+Enter saves"
                color: notes.muted
                font.family: notes.uiFont
                font.pixelSize: notes.fontSize - 3
            }
        }
    }
}
