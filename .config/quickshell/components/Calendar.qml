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
    // NOTE: no `focusable:` here on purpose. PanelWindow.focusable and
    // WlrLayershell.keyboardFocus write the same underlying property, so
    // setting both fights and Exclusive loses nondeterministically. mango
    // only auto-focuses Exclusive layers (niri focuses OnDemand too).
    WlrLayershell.keyboardFocus: calPopup.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

    // Same shading as the bar pills: soft tint instead of saturated red.
    readonly property color calColor: rootRef
        ? (rootRef.tonalPillColor ? rootRef.tonalPillColor(rootRef.pillColor("tertiary_container")) : rootRef.colorOf("tertiary_container"))
        : Qt.rgba(0.08, 0.08, 0.08, 0.85)
    readonly property color popupFg: rootRef
        ? rootRef.contrastColor(calColor)
        : "#ffffff"

    readonly property color accentCol: rootRef
        ? (rootRef.pillColor ? rootRef.pillColor("primary") : (rootRef.primary || "#4a9eff"))
        : "#4a9eff"

    // Done-task green: theme's green token pulled 60% toward black.
    // The raw token is neon (≈2:1 on the light card); this lands near
    // #296629, ≈7:1 against the pastel popup, so dots and text stay
    // legible instead of washing out.
    readonly property color doneGreen: rootRef && rootRef.mixColor
        ? rootRef.mixColor(rootRef.colorOf("green"), "#000000", 0.6)
        : "#2e7d32"
    readonly property color accentFg: rootRef
        ? (rootRef.luminance(Qt.color(accentCol)) > 0.45 ? "#000000" : "#ffffff")
        : "#ffffff"

    property bool closingBySelf: false
    property int shownYear: new Date().getFullYear()
    property int shownMonth: new Date().getMonth()

    property var notes: ({})
    property string selectedKey: ""

    // tmn73.calendar ideas: Monday-first grid with Sunday toggle,
    // ISO week numbers, always-6-row fixed grid.
    // 1 = Monday, 0 = Sunday (JS Date.getDay() convention).
    property int weekStart: 1
    // Real events from ~/.local/state/omarchy/calendar-events.json
    // (written by tmn73.calendar sync or any writer following the
    // same contract: {version:1, events:[{id,dateKey,start,end,
    // allDay,title,color,meetingUrl,eventUrl,responseStatus,...}]}).
    property var realEvents: ({})
    property var realEventList: []
    property string eventsSyncInfo: ""
    property date nowTick: new Date()
    // True while the grid shows the current month — the top date shows
    // today then, otherwise it shows the month being browsed.
    readonly property bool viewingCurrentMonth: {
        var n = calPopup.nowTick
        return calPopup.shownYear === n.getFullYear() && calPopup.shownMonth === n.getMonth()
    }

    property var entries: []
    property int selectedEntryId: -1
    property int newEntryId: -1
    property int entrySeq: 0

    readonly property int editorHeight: 164

    property real popProgress: 0
    property real baseTop: 0

    // Smooth opacity ramp decoupled from the bouncy pop: OutBack
    // finishes ~95% in the first 150ms, which reads as a pop.
    property real fadeProgress: 0
    Behavior on fadeProgress { Anim { type: Anim.SlowEffects } }

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

    // Watches the tmn73.calendar events file; any writer following the
    // contract (Google sync, khal, vdirsyncer, ICS script) lights up here.
    FileView {
        id: realEventsFile
        path: (Quickshell.env("HOME") || "") + "/.local/state/omarchy/calendar-events.json"
        watchChanges: true
        printErrors: false
        onLoaded: calPopup.applyRealEvents(text())
        onLoadFailed: calPopup.applyRealEvents("")
        onFileChanged: realEventsFile.reload()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: calPopup.nowTick = new Date()
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"])
        visible = false
    }

    // Same open/close animation as the notification center.
    Behavior on popProgress {
        Anim { type: Anim.Bouncy }
    }

    onFadeProgressChanged: {
        if (fadeProgress <= 0.001 && closingBySelf) calPopup.visible = false
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
        calPopup.fadeProgress = 0
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

    // Always 42 cells (6x7) so the popup never jumps height between
    // months. Out-of-month days are kept dimmed but selectable.
    function rebuildModel() {
        calDays.clear()
        var y = calPopup.shownYear
        var m = calPopup.shownMonth
        var leading = (new Date(y, m, 1).getDay() - calPopup.weekStart + 7) % 7
        for (var i = 0; i < 42; i++) {
            var dt = new Date(y, m, 1 - leading + i)
            var cy = dt.getFullYear()
            var cm = dt.getMonth()
            var cd = dt.getDate()
            calDays.append({
                day: cd,
                inMonth: (cm === m && cy === y) ? 1 : 0,
                cellY: cy,
                cellM: cm,
                week: calPopup.isoWeekFor(new Date(cy, cm, cd))
            })
        }
    }

    function toggleWeekStart() {
        calPopup.weekStart = calPopup.weekStart === 1 ? 0 : 1
        calPopup.rebuildModel()
    }

    function goToToday() {
        var n = new Date()
        calPopup.shownYear = n.getFullYear()
        calPopup.shownMonth = n.getMonth()
        calPopup.rebuildModel()
    }

    function weekdayOrder() {
        var names = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        var out = []
        for (var i = 0; i < 7; i++) out.push(names[(calPopup.weekStart + i) % 7])
        return out
    }

    // ISO-8601 week number: week owning the Thursday.
    function isoWeekFor(dt) {
        var d = new Date(Date.UTC(dt.getFullYear(), dt.getMonth(), dt.getDate()))
        var wd = d.getUTCDay() || 7
        d.setUTCDate(d.getUTCDate() + 4 - wd)
        var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
        return Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7)
    }

    function rowWeekNumber(row) {
        // Thursday of this grid row defines the ISO week.
        var thursdayIdx = (4 - calPopup.weekStart + 7) % 7
        var idx = row * 7 + thursdayIdx
        if (idx < 0 || idx >= calDays.count) return ""
        var c = calDays.get(idx)
        return calPopup.isoWeekFor(new Date(c.cellY, c.cellM, c.day))
    }

    // True while a text field owns focus, so month-step keys never fire
    // mid-edit (a single-line field lets Up/Down propagate).
    function navGuard() {
        var f = calPopup.activeFocusItem
        return !(f instanceof TextField) && !(f instanceof TextInput) && !(f instanceof TextArea)
    }

    function shiftMonth(amount) {
        // Total-months math so ±12 (year steps) lands on the same month.
        var total = calPopup.shownYear * 12 + calPopup.shownMonth + amount
        var m = total % 12
        if (m < 0) m += 12
        calPopup.shownYear = Math.floor((total - m) / 12)
        calPopup.shownMonth = m
        calPopup.rebuildModel()
    }

    function dateKey(y, m, d) {
        function pad(n) { return n < 10 ? "0" + n : "" + n }
        return y + "-" + pad(m + 1) + "-" + pad(d)
    }

    // ---- Real events (tmn73.calendar contract) ----
    function applyRealEvents(raw) {
        var index = {}
        var list = []
        var info = ""
        if (raw) {
            try {
                var doc = JSON.parse(raw)
                if (doc && doc.version === 1 && doc.events instanceof Array) {
                    var evs = doc.events
                    for (var i = 0; i < evs.length; i++) {
                        var e = evs[i]
                        if (!e || !e.dateKey) continue
                        // Hide working-location markers + declined, like the plugin.
                        if (String(e.eventType || "") === "workingLocation") continue
                        if (String(e.responseStatus || "") === "declined") continue
                        list.push(e)
                        if (!index[e.dateKey]) index[e.dateKey] = []
                        index[e.dateKey].push(e)
                    }
                    for (var k in index) {
                        index[k].sort((a, b) => {
                            var as = a.allDay ? "1" : "0"
                            var bs = b.allDay ? "1" : "0"
                            if (as !== bs) return as < bs ? -1 : 1
                            return String(a.start || "") < String(b.start || "") ? -1 : 1
                        })
                    }
                    var n = evs.length
                    var when = ""
                    if (doc.syncedAt) {
                        var mins = Math.max(0, Math.round((Date.now() - Date.parse(doc.syncedAt)) / 60000))
                        when = mins < 1 ? "just now" : mins < 60 ? mins + "m ago" : Math.floor(mins / 60) + "h ago"
                    }
                    info = n + (n === 1 ? " event" : " events") + (when ? " · " + when : "")
                } else if (doc && doc.version !== undefined) {
                    info = "events file v" + doc.version + " unsupported"
                }
            } catch (e2) { info = "" }
        }
        calPopup.realEvents = index
        calPopup.realEventList = list
        calPopup.eventsSyncInfo = info
    }

    function eventDots(key) {
        var arr = calPopup.realEvents[key]
        if (!arr) return []
        var colors = []
        for (var i = 0; i < arr.length && colors.length < 3; i++) {
            var c = arr[i].color || ""
            if (c && colors.indexOf(c) < 0) colors.push(c)
        }
        return colors
    }

    // One entry per task (max 3): true = done (green dot), false = open.
    function taskDots(key) {
        var arr = calPopup.notes[key]
        if (!arr || !arr.length) return []
        var out = []
        for (var i = 0; i < arr.length && out.length < 3; i++)
            out.push(!!arr[i].done)
        return out
    }

    function fmtClock(iso) {
        var ms = Date.parse(iso)
        if (isNaN(ms)) return ""
        return Qt.formatDateTime(new Date(ms), "HH:mm")
    }

    function eventPhase(e) {
        if (!e || e.allDay) return "later"
        var now = calPopup.nowTick.getTime()
        var s = Date.parse(e.start)
        var en = Date.parse(e.end)
        if (isNaN(s)) return "later"
        if (isNaN(en) || en < s) en = s
        if (en <= now) return "past"
        if (s <= now) return "now"
        return "later"
    }

    function formatCountdown(ms) {
        if (ms === null || ms === undefined || isNaN(ms) || ms < 0) return ""
        if (ms >= 86400000) return ""
        if (ms < 60000) return "now"
        var mins = Math.floor(ms / 60000)
        if (mins < 60) return "in " + mins + "min"
        var h = Math.floor(mins / 60)
        var r = mins % 60
        return r === 0 ? "in " + h + "h" : "in " + h + "h " + r + "min"
    }

    function nextCountdownToday() {
        var key = calPopup.dateKey(new Date().getFullYear(), new Date().getMonth(), new Date().getDate())
        var arr = calPopup.realEvents[key] || []
        var now = calPopup.nowTick.getTime()
        var best = -1
        var bestMs = 0
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].allDay) continue
            var s = Date.parse(arr[i].start)
            if (isNaN(s) || s < now) continue
            if (best < 0 || s < bestMs) { best = i; bestMs = s }
        }
        if (best < 0) return ""
        return calPopup.formatCountdown(bestMs - now)
    }

    function safeHttps(url) {
        var t = String(url || "").trim()
        if (t.indexOf("https://") !== 0) return ""
        if (/[\s"'<>]/.test(t)) return ""
        return t
    }

    function isJoinable(e) {
        var m = calPopup.safeHttps(e && e.meetingUrl)
        if (!m) return false
        if (e.allDay) {
            var k = calPopup.dateKey(new Date().getFullYear(), new Date().getMonth(), new Date().getDate())
            return e.dateKey === k
        }
        var now = calPopup.nowTick.getTime()
        var s = Date.parse(e.start)
        var en = Date.parse(e.end)
        if (isNaN(s)) return false
        if (isNaN(en) || en < s) en = s
        return now >= s - 15 * 60000 && now <= en + 15 * 60000
    }

    function openRealEvent(e) {
        var u = calPopup.safeHttps(e && (e.eventUrl || e.meetingUrl))
        if (u) Quickshell.execDetached(["xdg-open", u])
    }

    function joinMeeting(e) {
        var u = calPopup.safeHttps(e && e.meetingUrl)
        if (u) Quickshell.execDetached(["xdg-open", u])
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
            calPopup.fadeProgress = 1
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
        Keys.onEscapePressed: {
            if (calPopup.rootRef && calPopup.rootRef.closeCalendar) calPopup.rootRef.closeCalendar()
            else calPopup.close()
        }
        // Keyboard month stepping, like the plugin: arrows move months
        // (up/down = year), t = today, w = week start, [ ] = month.
        Keys.onLeftPressed: event => { if (calPopup.navGuard()) calPopup.shiftMonth(-1) }
        Keys.onRightPressed: event => { if (calPopup.navGuard()) calPopup.shiftMonth(1) }
        Keys.onUpPressed: event => { if (calPopup.navGuard()) calPopup.shiftMonth(-12) }
        Keys.onDownPressed: event => { if (calPopup.navGuard()) calPopup.shiftMonth(12) }
        Keys.onPressed: event => {
            if (!calPopup.navGuard()) return
            var t = event.text || ""
            if (t === "[") { calPopup.shiftMonth(-1); event.accepted = true }
            else if (t === "]") { calPopup.shiftMonth(1); event.accepted = true }
            else if (t === "t" || t === "T") { calPopup.goToToday(); event.accepted = true }
            else if (t === "w" || t === "W") { calPopup.toggleWeekStart(); event.accepted = true }
        }

        MouseArea {
            id: calDismiss
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            onClicked: {
                if (calPopup.rootRef && calPopup.rootRef.closeCalendar) calPopup.rootRef.closeCalendar()
                else calPopup.close()
            }
        }

        Rectangle {
            id: calPopupBody
            width: 372
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

        radius: 0
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

        opacity: calPopup.fadeProgress
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
                    Layout.alignment: Qt.AlignVCenter
                    radius: 0
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

                // Top-center date, styled like every other popup header:
                // +1 DemiBold title with a dimmed secondary tail.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: calPopup.viewingCurrentMonth
                                ? Qt.formatDate(calPopup.nowTick, "MMM d")
                                : Qt.formatDate(new Date(calPopup.shownYear, calPopup.shownMonth, 1), "MMM yyyy")
                            color: heroMouse.containsMouse ? calPopup.accentCol : calPopup.popupFg
                            font.family: rootRef.uiFont
                            font.pixelSize: rootRef.fontSize + 1
                            font.weight: Font.DemiBold
                        }

                        Text {
                            visible: calPopup.viewingCurrentMonth
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                var s = Qt.formatDate(calPopup.nowTick, "dddd")
                                var cd = calPopup.nextCountdownToday()
                                return "·  " + (cd ? s + "  ·  " + cd : s)
                            }
                            color: calPopup.popupFg
                            opacity: 0.62
                            font.family: rootRef.uiFont
                            font.pixelSize: rootRef.fontSize - 1
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: heroMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calPopup.goToToday()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 0
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
                    radius: 0
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
                Layout.preferredHeight: 18
                spacing: 0

                // "W" toggles Monday/Sunday week start.
                Text {
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "W"
                    color: wToggleHover.containsMouse ? calPopup.accentCol : calPopup.popupFg
                    opacity: wToggleHover.containsMouse ? 1.0 : 0.45
                    font.family: rootRef.uiFont
                    font.pixelSize: rootRef.fontSize - 2
                    font.weight: Font.Bold

                    MouseArea {
                        id: wToggleHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calPopup.toggleWeekStart()
                    }
                }

                Item { width: 8; height: 1 }

                Repeater {
                    model: calPopup.weekdayOrder()
                    delegate: Text {
                        required property string modelData
                        width: (calPopupBody.width - 24 - 36) / 7
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

            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 192
                spacing: 0

                // Scroll on the grid steps months, like the plugin.
                WheelHandler {
                    onWheel: function(event) {
                        if (event.angleDelta.y === 0) return
                        calPopup.shiftMonth(event.angleDelta.y > 0 ? -1 : 1)
                        event.accepted = true
                    }
                }

                // ISO week numbers gutter.
                Column {
                    width: 28
                    spacing: 0
                    Repeater {
                        model: 6
                        delegate: Text {
                            required property int index
                            width: 28
                            height: 32
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: calPopup.rowWeekNumber(index)
                            color: calPopup.popupFg
                            opacity: 0.4
                            font.family: rootRef.uiFont
                            font.pixelSize: rootRef.fontSize - 2
                        }
                    }
                }

                Item { width: 8; height: 1 }

                Grid {
                    id: calGrid
                    width: parent.width - 36
                    height: 192
                    columns: 7
                    columnSpacing: 0
                    rowSpacing: 2

                    Repeater {
                        model: ListModel { id: calDays }

                        delegate: Item {
                            required property int day
                            required property int inMonth
                            required property int cellY
                            required property int cellM

                            readonly property string key: calPopup.dateKey(cellY, cellM, day)
                            readonly property bool isToday: {
                                var t = new Date(cellY, cellM, day)
                                var n = new Date()
                                return t.getFullYear() === n.getFullYear()
                                    && t.getMonth() === n.getMonth()
                                    && t.getDate() === n.getDate()
                            }
                            readonly property bool isSelected: calPopup.selectedKey === key
                            readonly property bool hasNote: calPopup.notes[key] !== undefined
                            readonly property var dots: calPopup.eventDots(key)
                            readonly property var taskDots: calPopup.taskDots(key)
                            readonly property bool hasDots: dots.length > 0 || taskDots.length > 0

                            width: (calPopupBody.width - 24 - 36) / 7
                            height: 30

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 0
                                border.width: isToday && !isSelected ? 1 : 0
                                border.color: rootRef ? rootRef.withAlpha(calPopup.accentCol, 0.55) : "transparent"
                                color: isSelected
                                    ? calPopup.accentCol
                                    : dayHover.containsMouse
                                        ? rootRef.withAlpha(calPopup.popupFg, 0.18)
                                        : isToday ? (rootRef ? rootRef.withAlpha(calPopup.accentCol, 0.35) : "transparent") : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: hasDots ? -3 : 0
                                    text: day
                                    color: isSelected ? calPopup.accentFg : calPopup.popupFg
                                    opacity: inMonth ? 1.0 : 0.35
                                    font.family: rootRef.uiFont
                                    font.pixelSize: rootRef.fontSize
                                    font.weight: isToday || isSelected ? Font.Bold : Font.Normal
                                }

                                // Real-event colour dots (max 3) + one dot per
                                // task (max 3): green = done, accent = open.
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 3
                                    spacing: 2
                                    visible: hasDots

                                    Repeater {
                                        model: dots
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: modelData
                                            opacity: inMonth ? 0.9 : 0.4
                                        }
                                    }

                                    Repeater {
                                        model: taskDots
                                        delegate: Rectangle {
                                            required property bool modelData
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: modelData ? calPopup.doneGreen
                                                : (isSelected ? calPopup.accentFg : calPopup.accentCol)
                                            opacity: inMonth ? 0.9 : 0.4
                                        }
                                    }
                                }

                                MouseArea {
                                    id: dayHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calPopup.selectDay(key)
                                }
                            }
                        }
                    }
                }
            }

            // Sync state line (event count + age), like the plugin's
            // Sync row. The next-event countdown lives under the hero.
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: calPopup.eventsSyncInfo
                color: calPopup.popupFg
                opacity: 0.5
                font.family: rootRef.uiFont
                font.pixelSize: rootRef.fontSize - 2
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // Selected day's real agenda (tmn73.calendar): timeline rows with
            // past faded, in-progress highlighted, countdown on the next one,
            // and a Join button while a meeting is live.
            ColumnLayout {
                id: agendaBox
                Layout.fillWidth: true
                visible: (calPopup.realEvents[calPopup.selectedKey.length > 0
                    ? calPopup.selectedKey
                    : calPopup.dateKey(new Date().getFullYear(), new Date().getMonth(), new Date().getDate())] || []).length > 0
                spacing: 4

                readonly property string agendaKey: calPopup.selectedKey.length > 0
                    ? calPopup.selectedKey
                    : calPopup.dateKey(new Date().getFullYear(), new Date().getMonth(), new Date().getDate())
                readonly property var agendaEvents: calPopup.realEvents[agendaBox.agendaKey] || []

                Repeater {
                    model: agendaBox.agendaEvents
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        spacing: 6
                        opacity: calPopup.eventPhase(modelData) === "past" ? 0.45 : 1.0

                        Rectangle {
                            Layout.preferredWidth: 3
                            Layout.fillHeight: true
                            radius: 0
                            color: modelData.color || calPopup.accentCol
                        }

                        Text {
                            Layout.preferredWidth: 44
                            text: modelData.allDay ? "all day" : calPopup.fmtClock(modelData.start)
                            color: calPopup.eventPhase(modelData) === "now" ? calPopup.accentCol : calPopup.popupFg
                            opacity: modelData.allDay ? 0.6 : 1.0
                            font.family: rootRef.uiFont
                            font.pixelSize: rootRef.fontSize - 2
                            font.weight: calPopup.eventPhase(modelData) === "now" ? Font.Bold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                var t = modelData.title || "(no title)"
                                if (calPopup.eventPhase(modelData) !== "now") return t
                                var left = modelData.end ? Date.parse(modelData.end) - calPopup.nowTick.getTime() : NaN
                                if (!isNaN(left) && left > 0 && left < 3600000)
                                    return t + " · " + Math.ceil(left / 60000) + "min left"
                                return t
                            }
                            color: calPopup.eventPhase(modelData) === "now" ? calPopup.accentCol : calPopup.popupFg
                            font.family: rootRef.uiFont
                            font.pixelSize: rootRef.fontSize - 1
                            font.weight: calPopup.eventPhase(modelData) === "now" ? Font.Bold : Font.Normal
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            visible: {
                                if (modelData.allDay || calPopup.eventPhase(modelData) !== "later") return false
                                var s = Date.parse(modelData.start)
                                return !isNaN(s) && s >= calPopup.nowTick.getTime()
                            }
                            text: calPopup.formatCountdown(Date.parse(modelData.start) - calPopup.nowTick.getTime())
                            color: calPopup.popupFg
                            opacity: 0.6
                            font.family: rootRef.uiFont
                            font.pixelSize: rootRef.fontSize - 2
                            verticalAlignment: Text.AlignVCenter
                        }

                        Rectangle {
                            visible: calPopup.isJoinable(modelData)
                            z: 2
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 20
                            radius: 0
                            color: joinHover.containsMouse
                                ? rootRef.withAlpha(calPopup.accentCol, 0.85)
                                : calPopup.accentCol

                            Text {
                                anchors.centerIn: parent
                                text: "Join"
                                color: calPopup.accentFg
                                font.family: rootRef.uiFont
                                font.pixelSize: rootRef.fontSize - 2
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: joinHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calPopup.joinMeeting(modelData)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData.eventUrl || modelData.meetingUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: calPopup.openRealEvent(modelData)
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
                        radius: 0
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
                        radius: 0
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
                            radius: 0
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
                                radius: 0
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
                                        radius: 0
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
                                        color: entryDone ? calPopup.doneGreen : calPopup.popupFg
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
                                        radius: 0
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
                radius: 0
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
                            radius: 0
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
                            radius: 0
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
                            radius: 0
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
                            radius: 0
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
