import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

PanelWindow {
    id: calPopup
    visible: false
    focusable: calPopup.visible
    color: "transparent"

    WlrLayershell.namespace: "calendar-card"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    property var rootRef: null
    property var anchorItem: null
    property var anchorWin: null

    readonly property color calColor: {
        var base = rootRef
            ? (rootRef.qsLight ? rootRef.pillColor("tertiary_container") : rootRef.colorOf("tertiary_container"))
            : Qt.rgba(0.08, 0.08, 0.08, 0.85)
        return Qt.darker(base, 1.1)
    }
    readonly property color popupFg: rootRef
        ? (rootRef.luminance(Qt.color(calColor)) > 0.45 ? "#000000" : "#ffffff")
        : "#ffffff"

    readonly property color accentCol: rootRef
        ? (rootRef.pillColor ? rootRef.pillColor("primary") : (rootRef.primary || "#4a9eff"))
        : "#4a9eff"
    readonly property color accentFg: rootRef
        ? (rootRef.luminance(Qt.color(accentCol)) > 0.45 ? "#000000" : "#ffffff")
        : "#ffffff"

    property bool closingBySelf: false
    property int shownYear: new Date().getFullYear()
    property int shownMonth: new Date().getMonth()

    property var notes: ({})
    property string selectedKey: ""

    property var entries: []
    property int selectedEntryId: -1
    property int newEntryId: -1
    property int entrySeq: 0

    readonly property int editorHeight: 164

    property real popProgress: 0
    property real baseTop: 0

    property real editorProgress: calPopup.selectedKey.length > 0 ? 1 : 0
    Behavior on editorProgress {
        Anim { type: Anim.BouncyFast }
    }

    readonly property int timerHeight: 56

    FileView {
        id: notesFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/calendar-notes.json"
        preload: true
        printErrors: false

        onLoaded: {

            var raw = notesAdapter.notes || {}
            var converted = {}
            var maxId = 0
            for (var k in raw) {
                var v = raw[k]
                if (typeof v === "string")
                    converted[k] = [{ id: ++maxId, text: v, saved: true, done: false }]
                else
                    converted[k] = calPopup.toEntryList(v)
            }
            for (var d in converted) {
                var list = converted[d]
                for (var i = 0; i < list.length; i++)
                    if (list[i].id > maxId) maxId = list[i].id
            }
            calPopup.entrySeq = maxId
            calPopup.notes = converted
        }

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) notesFile.writeAdapter()
        }

        onAdapterUpdated: notesFile.writeAdapter()
        onSaveFailed: error => console.log("[cal] notesFile saveFailed error=" + error)

        JsonAdapter {
            id: notesAdapter
            property var notes: ({})
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"])
        visible = false
    }

    // Same open/close animation as the notification center.
    Behavior on popProgress {
        Anim { type: Anim.Bouncy }
    }

    onPopProgressChanged: {
        if (popProgress <= 0.001 && closingBySelf) calPopup.visible = false
    }

    function open() {
        if (calPopup.visible) {
            calPopup.close()
            return
        }
        calPopup.shownYear = new Date().getFullYear()
        calPopup.shownMonth = new Date().getMonth()
        calPopup.visible = true
    }

    function close() {
        calPopup.closingBySelf = true
        timerSection.playCloseAnim()
        calPopup.popProgress = 0
    }

    // Pill position is computed analytically: cross-window
    // mapToGlobal/mapFromGlobal is unreliable between layer-shell surfaces
    // on Wayland (clients never learn global surface positions), so we
    // chain same-window x/y reads and add the bar window's known offset
    // (top-anchored at margins.top, centered on the unanchored axis).
    function updateCalPosition() {
        var anchor = calPopup.anchorItem
        var win = calPopup.anchorWin
        if (!anchor || !win || !calPopupContent) return false
        if (calPopupContent.width <= 0 || calPopupContent.height <= 0) return false
        var scr = calPopup.screen
        if (!scr || !(scr.width > 0)) return false
        var winW = win.width
        if (!(winW > 0)) return false
        var row = anchor.parent
        var content = row ? row.parent : null
        if (!row || !content) return false
        var pillWinX = (content.x || 0) + row.x + anchor.x
        var pillWinY = (content.y || 0) + row.y + anchor.y
        var barWinX = (scr.width - winW) / 2
        var barWinY = (win.margins ? win.margins.top : 0) || 0
        var pillX = barWinX + pillWinX
        var pillY = barWinY + pillWinY
        var centerX = pillX + anchor.width / 2
        // niri pushes top-anchored overlay surfaces below the bar's reserved
        // area (bar margins.top + bar exclusiveZone); compensate so the card
        // lands exactly under the pill. Derived live so bar tweaks follow.
        var reservedTop = ((win.margins ? win.margins.top : 0) || 0) + (win.exclusiveZone || 0)
        calPopup.baseTop = Math.round(pillY + anchor.height + 14 - reservedTop)
        calPopupBody.anchors.topMargin = calPopup.baseTop
        // Center the card on the pill body (clamped to stay on screen).
        var halfBody = calPopupBody.width / 2
        var clamped = Math.max(halfBody + 8, Math.min(calPopupContent.width - halfBody - 8, centerX))
        calPopupBody.anchors.rightMargin = Math.round(calPopupContent.width - (clamped + halfBody))
        return true
    }

    function monthName(m) {
        var names = ["January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"]
        return names[m]
    }

    function rebuildModel() {
        calDays.clear()
        var first = new Date(calPopup.shownYear, calPopup.shownMonth, 1).getDay()
        var days = new Date(calPopup.shownYear, calPopup.shownMonth + 1, 0).getDate()
        for (var i = 0; i < first; i++) calDays.append({ day: 0 })
        for (var d = 1; d <= days; d++) calDays.append({ day: d })
    }

    function shiftMonth(amount) {
        calPopup.shownMonth += amount
        if (calPopup.shownMonth < 0) {
            calPopup.shownMonth = 11
            calPopup.shownYear--
        } else if (calPopup.shownMonth > 11) {
            calPopup.shownMonth = 0
            calPopup.shownYear++
        }
        calPopup.rebuildModel()
    }

    function dateKey(y, m, d) {
        function pad(n) { return n < 10 ? "0" + n : "" + n }
        return y + "-" + pad(m + 1) + "-" + pad(d)
    }

    function toEntryList(v) {
        var out = []
        if (v === null || v === undefined) return out
        if (typeof v === "string") {
            out.push({ id: 0, text: v, saved: true, done: false })
            return out
        }
        var n = typeof v.length === "number" ? v.length : 0
        for (var i = 0; i < n; i++) {
            var e = v[i]
            if (e === null || e === undefined) continue
            out.push({
                id: typeof e.id === "number" ? e.id : 0,
                text: e.text !== undefined && e.text !== null ? String(e.text) : "",
                saved: !!e.saved,
                done: !!e.done
            })
        }
        return out
    }

    function selectDay(key) {

        if (calPopup.selectedKey === key) {
            calPopup.selectedKey = ""
            calPopup.selectedEntryId = -1
            calPopup.newEntryId = -1
            calPopup.entries = []
            entriesModel.clear()
            return
        }
        calPopup.selectedKey = key
        calPopup.selectedEntryId = -1
        calPopup.newEntryId = -1
        calPopup.entries = calPopup.toEntryList(calPopup.notes[key])
        calPopup.syncNotes()
    }

    function syncNotes() {
        var copy = Object.assign({}, calPopup.notes || {})
        if ((calPopup.entries || []).length === 0)
            delete copy[calPopup.selectedKey]
        else
            copy[calPopup.selectedKey] = calPopup.entries.slice()
        calPopup.notes = copy
        notesAdapter.notes = JSON.parse(JSON.stringify(copy))
        entriesModel.clear()
        var list = calPopup.entries || []
        for (var i = 0; i < list.length; i++)
            entriesModel.append({ entryId: list[i].id, entryText: list[i].text, saved: list[i].saved, entryDone: list[i].done })
    }

    function selectEntry(eid) {
        if (calPopup.selectedEntryId !== eid) calPopup.selectedEntryId = eid
    }

    function addEntry() {
        if (calPopup.selectedKey.length === 0) return
        var entry = { id: ++calPopup.entrySeq, text: "", saved: false, done: false }
        calPopup.entries = calPopup.entries.concat([entry])
        calPopup.selectedEntryId = entry.id
        calPopup.newEntryId = entry.id
        calPopup.syncNotes()
    }

    function saveEntry(eid, text) {
        var list = calPopup.entries || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== eid) continue
            var trimmed = (text || "").trim()
            if (trimmed.length === 0) return
            var updated = list.slice()
            updated[i] = { id: eid, text: trimmed, saved: true, done: list[i].done }
            calPopup.entries = updated
            calPopup.selectedEntryId = eid
            calPopup.syncNotes()
            return
        }
    }

    function toggleEntryDone(eid) {
        var list = calPopup.entries || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== eid) continue
            var updated = list.slice()
            updated[i] = { id: eid, text: list[i].text, saved: true, done: !list[i].done }
            calPopup.entries = updated
            calPopup.syncNotes()
            return
        }
    }

    function removeSelectedEntry() {
        if (calPopup.selectedEntryId < 0) return
        var list = calPopup.entries || []
        var out = []
        var removed = false
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === calPopup.selectedEntryId) { removed = true; continue }
            out.push(list[i])
        }
        if (!removed) return
        calPopup.selectedEntryId = -1
        calPopup.newEntryId = -1
        calPopup.entries = out
        calPopup.syncNotes()
    }

    function selectedDateLabel() {
        if (calPopup.selectedKey.length === 0) return ""
        var parts = calPopup.selectedKey.split("-")
        var y = parseInt(parts[0], 10)
        var m = parseInt(parts[1], 10) - 1
        var d = parseInt(parts[2], 10)
        return Qt.formatDate(new Date(y, m, d), "ddd, MMM d")
    }

    Timer {
        id: positionTimer
        interval: 16
        repeat: false
        property int attempts: 0
        onTriggered: {
            if (!calPopup.updateCalPosition() && attempts < 60) {
                attempts++
                positionTimer.restart()
            }
        }
    }

    // Debounced follower: pill metrics jitter constantly (network/memory
    // labels, animated pill widths), so coalesce repositioning instead of
    // re-laying out the popup every frame.
    Timer {
        id: followTimer
        interval: 150
        repeat: false
        onTriggered: { if (calPopup.visible) calPopup.updateCalPosition() }
    }

    // Keep the card glued under the clock pill if the popup window resizes.
    Connections {
        target: calPopupContent
        function onWidthChanged() { if (calPopup.visible) followTimer.restart() }
        function onHeightChanged() { if (calPopup.visible) followTimer.restart() }
    }

    // Keep the card glued under the clock pill if the pill moves/resizes
    // (e.g. clock text width changes each minute).
    Connections {
        target: calPopup.anchorItem
        function onXChanged() { if (calPopup.visible) followTimer.restart() }
        function onYChanged() { if (calPopup.visible) followTimer.restart() }
        function onWidthChanged() { if (calPopup.visible) followTimer.restart() }
        function onHeightChanged() { if (calPopup.visible) followTimer.restart() }
    }

    onVisibleChanged: {
        if (visible) {
            calPopup.rebuildModel()
            timerBody.opacity = 0
            positionTimer.attempts = 0
            positionTimer.restart()
            timerPopupOut.stop()
            Qt.callLater(() => {
                if (calPopup.visible && !calPopup.closingBySelf) timerPopupIn.restart()
            })
            calPopup.popProgress = 1
        } else {
            timerPopupIn.stop()
            calPopup.closingBySelf = false
            calPopup.selectedKey = ""
            calPopup.selectedEntryId = -1
            calPopup.newEntryId = -1
            calPopup.entries = []
            entriesModel.clear()
            timerBody.opacity = 1
            calPopup.popProgress = 0
        }
    }

    Item {
        id: calPopupContent
        focus: true
        anchors.fill: parent
        Keys.onEscapePressed: calPopup.close()

        MouseArea {
            id: calDismiss
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            onClicked: calPopup.close()
        }

        Rectangle {
            id: calPopupBody
            width: 320
            anchors.top: calPopupContent.top
            anchors.right: calPopupContent.right
            // Size follows content like the other popup cards (no hardcoded override).
            height: bodyColumn.implicitHeight + 24

            MouseArea {
                id: calCardGuard
                anchors.fill: parent
            }

        Behavior on height {
            Anim { type: Anim.BouncyFast }
        }

        radius: 12
        color: calPopup.calColor
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
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

        opacity: calPopup.popProgress
        transform: Translate { y: (1 - calPopup.popProgress) * 8 }

        ColumnLayout {
            id: bodyColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 8
                    color: calPrevHover.containsMouse ? rootRef.withAlpha(calPopup.popupFg, 0.15) : "transparent"

                    QIcon {
                        anchors.centerIn: parent
                        source: Qt.resolvedUrl("../assets/icons/chev-left.svg")
                        color: calPopup.popupFg
                        iconSize: rootRef.fontSize + 4
                    }

                    MouseArea {
                        id: calPrevHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calPopup.shiftMonth(-1)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: calPopup.monthName(calPopup.shownMonth) + " " + calPopup.shownYear
                    color: calPopup.popupFg
                    font.family: rootRef.uiFont
                    font.pixelSize: rootRef.fontSize + 1
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 8
                    color: calNextHover.containsMouse ? rootRef.withAlpha(calPopup.popupFg, 0.15) : "transparent"

                    QIcon {
                        anchors.centerIn: parent
                        source: Qt.resolvedUrl("../assets/icons/chev-right.svg")
                        color: calPopup.popupFg
                        iconSize: rootRef.fontSize + 4
                    }

                    MouseArea {
                        id: calNextHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calPopup.shiftMonth(1)
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 8
                    color: calCloseHover.containsMouse ? rootRef.withAlpha(rootRef.error, 0.25) : "transparent"

                    QIcon {
                        anchors.centerIn: parent
                        source: Qt.resolvedUrl("../assets/icons/close.svg")
                        color: calCloseHover.containsMouse ? rootRef.error : calPopup.popupFg
                        iconSize: rootRef.fontSize + 3
                    }

                    MouseArea {
                        id: calCloseHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calPopup.close()
                    }
                }
            }

            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                Layout.bottomMargin: 16
                spacing: 6

                QIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl("../assets/icons/history.svg")
                    color: calPopup.popupFg
                    iconSize: rootRef.fontSize + 5
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")
                    color: calPopup.popupFg
                    font.family: rootRef.uiFont
                    font.pixelSize: rootRef.fontSize
                    font.weight: Font.Medium
                }
            }

            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 18

                Repeater {
                    model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                    delegate: Text {
                        width: (calPopupBody.width - 24) / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: calPopup.popupFg
                        font.family: rootRef.uiFont
                        font.pixelSize: rootRef.fontSize - 2
                        font.weight: Font.Bold
                        opacity: 0.6
                    }
                }
            }

            Grid {
                id: calGrid
                Layout.fillWidth: true
                Layout.preferredHeight: 190
                columns: 7
                columnSpacing: 0
                rowSpacing: 2

                Repeater {
                    model: ListModel { id: calDays }

                    delegate: Item {
                        required property int day

                        readonly property string key: day > 0
                            ? calPopup.dateKey(calPopup.shownYear, calPopup.shownMonth, day)
                            : ""
                        readonly property bool isToday: {
                            if (day === 0) return false
                            var t = new Date(calPopup.shownYear, calPopup.shownMonth, day)
                            var n = new Date()
                            return t.getFullYear() === n.getFullYear()
                                && t.getMonth() === n.getMonth()
                                && t.getDate() === n.getDate()
                        }
                        readonly property bool isSelected: key.length > 0 && calPopup.selectedKey === key
                        readonly property bool hasNote: key.length > 0 && calPopup.notes[key] !== undefined

                        width: (calPopupBody.width - 24) / 7
                        height: 30

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 8
                            visible: day > 0
                            border.width: isToday && !isSelected ? 1 : 0
                            border.color: rootRef ? rootRef.withAlpha(calPopup.accentCol, 0.55) : "transparent"
                            color: isSelected
                                ? calPopup.accentCol
                                : dayHover.containsMouse
                                    ? rootRef.withAlpha(calPopup.popupFg, 0.18)
                                    : isToday ? (rootRef ? rootRef.withAlpha(calPopup.accentCol, 0.35) : "transparent") : "transparent"

                            Text {
                                anchors.centerIn: parent
                                visible: day > 0
                                text: day
                                color: isSelected ? calPopup.accentFg : calPopup.popupFg
                                font.family: rootRef.uiFont
                                font.pixelSize: rootRef.fontSize
                                font.weight: isToday || isSelected ? Font.Bold : Font.Normal
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                visible: hasNote
                                width: 4
                                height: 4
                                radius: 2
                                color: isSelected ? calPopup.accentFg : calPopup.accentCol
                            }

                            MouseArea {
                                id: dayHover
                                anchors.fill: parent
                                visible: day > 0
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calPopup.selectDay(key)
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: calPopup.editorHeight * calPopup.editorProgress
                visible: calPopup.editorProgress > 0
                opacity: calPopup.editorProgress
                clip: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    spacing: 8

                    QIcon {
                        source: Qt.resolvedUrl("../assets/icons/calendar.svg")
                        color: calPopup.popupFg
                        iconSize: rootRef.fontSize + 3
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: calPopup.selectedDateLabel()
                        color: calPopup.popupFg
                        font.family: rootRef.uiFont
                        font.pixelSize: rootRef.fontSize + 1
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        text: (calPopup.entries || []).length === 0
                            ? "0 tasks"
                            : (function () {
                                var list = calPopup.entries || []
                                var done = 0
                                for (var i = 0; i < list.length; i++)
                                    if (list[i].done) done++
                                return done + "/" + list.length + " tasks"
                            })()
                        color: calPopup.popupFg
                        font.family: rootRef.uiFont
                        font.pixelSize: rootRef.fontSize - 2
                        verticalAlignment: Text.AlignVCenter
                    }

                    Item {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 22

                        QIcon {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../assets/icons/close.svg")
                            color: calPopup.popupFg
                            iconSize: rootRef.fontSize + 3
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calPopup.close()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    spacing: 6

                    Rectangle {
                        id: addBtn
                        Layout.preferredWidth: 26
                        Layout.fillHeight: true
                        radius: 8
                        color: addHover.containsMouse
                            ? rootRef.withAlpha(calPopup.popupFg, 0.35)
                            : rootRef.withAlpha(calPopup.popupFg, 0.22)

                        QIcon {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../assets/icons/plus.svg")
                            color: calPopup.popupFg
                            iconSize: rootRef.fontSize + 4
                        }

                        MouseArea {
                            id: addHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calPopup.addEntry()
                        }
                    }

                    Rectangle {
                        id: minusBtn
                        Layout.preferredWidth: 26
                        Layout.fillHeight: true
                        radius: 8
                        color: minusHover.containsMouse && calPopup.selectedEntryId >= 0
                            ? rootRef.withAlpha(rootRef.error, 0.35)
                            : rootRef.withAlpha(calPopup.popupFg, calPopup.selectedEntryId >= 0 ? 0.12 : 0.05)
                        enabled: calPopup.selectedEntryId >= 0

                        QIcon {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../assets/icons/minus.svg")
                            color: calPopup.selectedEntryId >= 0 ? rootRef.error : rootRef.withAlpha(calPopup.popupFg, 0.3)
                            iconSize: rootRef.fontSize + 4
                        }

                        MouseArea {
                            id: minusHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calPopup.removeSelectedEntry()
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Flickable {
                    id: entriesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 100
                    clip: true
                    contentWidth: width
                    contentHeight: entriesCol.height
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        width: 3
                        policy: ScrollBar.AsNeeded
                        background: Item {}
                        contentItem: Rectangle {
                            implicitWidth: 3
                            radius: 2
                            color: rootRef.withAlpha(calPopup.popupFg, 0.3)
                        }
                    }

                    Column {
                        id: entriesCol
                        width: entriesList.width
                        spacing: 6

                        Repeater {
                            id: entriesRepeater
                            model: ListModel { id: entriesModel }

                            delegate: Rectangle {
                                required property int entryId
                                required property string entryText
                                required property bool saved
                                required property bool entryDone

                                readonly property bool isSelected: calPopup.selectedEntryId === entryId

                                width: entriesCol.width
                                height: 30
                                radius: 8
                                color: rootRef.withAlpha(calPopup.popupFg, saved ? 0.05 : 0.08)
                                border.width: 1
                                border.color: isSelected
                                    ? calPopup.accentCol
                                    : saved ? "transparent" : rootRef.withAlpha(calPopup.popupFg, 0.15)

                                RowLayout {
                                    z: 1
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 4
                                    spacing: 6

                                    Rectangle {
                                        visible: saved
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18
                                        radius: 8
                                        color: entryDone
                                            ? (todoCheckArea.containsMouse ? rootRef.withAlpha(calPopup.accentCol, 0.8) : calPopup.accentCol)
                                            : (todoCheckArea.containsMouse ? rootRef.withAlpha(calPopup.popupFg, 0.08) : "transparent")
                                        border.width: 1
                                        border.color: entryDone ? calPopup.accentCol : rootRef.withAlpha(calPopup.popupFg, 0.35)

                                        Behavior on color { CAnim { type: CAnim.FastEffects } }

                                        QIcon {
                                            visible: entryDone
                                            anchors.centerIn: parent
                                            source: Qt.resolvedUrl("../assets/icons/check.svg")
                                            color: calPopup.accentFg
                                            iconSize: rootRef.fontSize
                                        }

                                        MouseArea {
                                            id: todoCheckArea
                                            z: 2
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: calPopup.toggleEntryDone(entryId)
                                        }
                                    }

                                    CharField {
                                        id: entryInput
                                        visible: !saved
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: entryText
                                        textColor: calPopup.popupFg
                                        font.family: rootRef.uiFont
                                        font.pixelSize: rootRef.fontSize
                                        selectByMouse: true
                                        onInputFocusChanged: {
                                            if (inputFocus) calPopup.selectEntry(entryId)
                                        }
                                        onAccepted: calPopup.saveEntry(entryId, entryInput.text)
                                    }

                                    Text {
                                        visible: saved
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: entryText
                                        color: calPopup.popupFg
                                        font.family: rootRef.uiFont
                                        font.pixelSize: rootRef.fontSize
                                        font.strikeout: entryDone
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Rectangle {
                                        visible: !saved
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        radius: 8
                                        color: saveHover.containsMouse ? rootRef.withAlpha(calPopup.popupFg, 0.25) : "transparent"

                                        QIcon {
                                            anchors.centerIn: parent
                                            source: Qt.resolvedUrl("../assets/icons/check.svg")
                                            color: calPopup.popupFg
                                            iconSize: rootRef.fontSize + 2
                                        }

                                        MouseArea {
                                            id: saveHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: calPopup.saveEntry(entryId, entryInput.text)
                                        }
                                    }
                                }

                                MouseArea {
                                    visible: saved
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calPopup.selectEntry(entryId)
                                }

                                Component.onCompleted: {
                                    if (entryId === calPopup.newEntryId && !saved) {
                                        Qt.callLater(() => entryInput.forceActiveFocus())
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 10
                Layout.bottomMargin: 6
                radius: 1
                color: rootRef ? rootRef.withAlpha(calPopup.popupFg, 0.12) : Qt.rgba(1, 1, 1, 0.1)
            }

            Item {
                Layout.fillHeight: true
            }

            Item {
                id: timerSection
                Layout.fillWidth: true
                Layout.preferredHeight: calPopup.timerHeight

                ParallelAnimation {
                    id: timerPopupIn
                    running: false
                    Anim { target: timerBody; property: "opacity"; to: 1; type: Anim.DefaultEffects }
                }

                SequentialAnimation {
                    id: timerPopupOut
                    running: false
                    ParallelAnimation {
                        Anim { target: timerBody; property: "opacity"; to: 0; type: Anim.FastEffects }
                    }
                }

                function playCloseAnim() {
                    timerPopupIn.stop()
                    timerPopupOut.restart()
                }

                Item {
                    id: timerBody
                    anchors.fill: parent
                    opacity: 0

                    RowLayout {
                        anchors.fill: parent
                        spacing: 6

                        QIcon {
                            source: Qt.resolvedUrl("../assets/icons/timer.svg")
                            color: calPopup.popupFg
                            iconSize: rootRef.fontSize + 4
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: rootRef.fmtTimer(rootRef.timerRemainingMs)
                            color: rootRef.timerRemainingMs <= 0 ? rootRef.error : calPopup.popupFg
                            font.family: rootRef.uiFont
                            font.pixelSize: rootRef.fontSize + 8
                            font.weight: Font.Normal
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                        }

                        Rectangle {
                            id: timerMinusBtn
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: timerMinusHover.containsMouse
                                ? rootRef.withAlpha(calPopup.popupFg, 0.35)
                                : rootRef.withAlpha(calPopup.popupFg, 0.18)

                            QIcon {
                                anchors.centerIn: parent
                                source: Qt.resolvedUrl("../assets/icons/minus.svg")
                                color: calPopup.popupFg
                                iconSize: rootRef.fontSize + 4
                            }

                            MouseArea {
                                id: timerMinusHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootRef.adjustTimerMinutes(-5)
                            }
                        }

                        Rectangle {
                            id: timerPlusBtn
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: timerPlusHover.containsMouse
                                ? rootRef.withAlpha(calPopup.popupFg, 0.35)
                                : rootRef.withAlpha(calPopup.popupFg, 0.18)

                            QIcon {
                                anchors.centerIn: parent
                                source: Qt.resolvedUrl("../assets/icons/plus.svg")
                                color: calPopup.popupFg
                                iconSize: rootRef.fontSize + 4
                            }

                            MouseArea {
                                id: timerPlusHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootRef.adjustTimerMinutes(5)
                            }
                        }

                        Rectangle {
                            id: timerToggleBtn
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: rootRef.timerRunning
                                ? (timerToggleHover.containsMouse ? rootRef.withAlpha(calPopup.accentCol, 0.85) : calPopup.accentCol)
                                : (timerToggleHover.containsMouse ? rootRef.withAlpha(calPopup.popupFg, 0.45) : rootRef.withAlpha(calPopup.popupFg, 0.28))

                            QIcon {
                                anchors.centerIn: parent
                                source: rootRef.timerRunning ? Qt.resolvedUrl("../assets/icons/pause.svg") : Qt.resolvedUrl("../assets/icons/play.svg")
                                color: rootRef.timerRunning ? calPopup.accentFg : calPopup.popupFg
                                iconSize: rootRef.fontSize + 4
                            }

                            MouseArea {
                                id: timerToggleHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootRef.toggleTimer()
                            }
                        }

                        Rectangle {
                            id: timerResetBtn
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: timerResetHover.containsMouse
                                ? rootRef.withAlpha(rootRef.error, 0.35)
                                : rootRef.withAlpha(calPopup.popupFg, 0.08)

                            QIcon {
                                anchors.centerIn: parent
                                source: Qt.resolvedUrl("../assets/icons/refresh.svg")
                                color: rootRef.error
                                iconSize: rootRef.fontSize + 2
                            }

                            MouseArea {
                                id: timerResetHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootRef.resetTimer()
                            }
                        }
                    }
                }
            }
        }
    }
}
}
