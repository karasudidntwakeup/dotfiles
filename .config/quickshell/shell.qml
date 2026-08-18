import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "colors.js" as Matugen

// Waybar-style bar for niri.
// Mirrors ~/.config/waybar (modules + Material You pill styling).
// Palette comes from matugen via colors.js (regenerated on wallpaper change).

// matugen 1787095194

ShellRoot {
    id: root

    // Palette (matugen, via colors.js)
    readonly property color primary: Matugen.primary
    readonly property color primaryContainer: Matugen.primary_container
    readonly property color secondary: Matugen.secondary
    readonly property color secondaryContainer: Matugen.secondary_container
    readonly property color tertiary: Matugen.tertiary
    readonly property color tertiaryContainer: Matugen.tertiary_container
    readonly property color error: Matugen.error
    readonly property color errorContainer: Matugen.error_container
    readonly property color surface: Matugen.surface

    // Typography (matches waybar style.css)
    readonly property string fontFamily: "Ndot 57"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int fontSize: 13

    // Layout (matches waybar config.jsonc)
    readonly property int barHeight: 44
    readonly property int pillHeight: 29
    readonly property int groupSpacing: 25

    readonly property color textColor: "#000000"
    readonly property color darkText: Matugen.shadow
    readonly property real pillAlpha: 0.25

    function luminance(color) {
        return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
    }

    function withAlpha(color, a) {
        return Qt.rgba(color.r, color.g, color.b, a)
    }

    // Script-driven modules
    property string weatherText: ""
    property string prayerText: ""
    property string memText: ""

    Process {
        id: weatherProc
        command: ["sh", "-c", "~/.config/waybar/scripts/weather.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (data) weatherText = data.trim()
            }
        }
    }

    Process {
        id: prayerProc
        command: ["sh", "-c", "~/.config/waybar/scripts/prayer.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (data) prayerText = data.trim()
            }
        }
    }

    Process {
        id: memProc
        command: ["sh", "-c", "~/.config/waybar/scripts/memory.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (data) memText = data.trim().replace(/^󰍛\s+/, "")
            }
        }
    }

    Timer {
        interval: 1740000
        running: true
        repeat: true
        onTriggered: weatherProc.running = true
    }

    Timer {
        interval: 80000
        running: true
        repeat: true
        onTriggered: prayerProc.running = true
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: memProc.running = true
    }

    // PulseAudio (Pipewire) — read/controlled via pactl (waybar-style, avoids
    // quickshell's Pipewire node never binding properly in this environment)
    property int volumePercent: 0
    property bool muted: false
    readonly property string volumeIcon: muted ? "󰝟" : (volumePercent <= 33 ? "󰕿" : volumePercent <= 66 ? "󰖀" : "󰕾")

    Process {
        id: volProc
        command: ["sh", "-c", "~/.config/quickshell/scripts/volume.sh"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|")
                root.volumePercent = parseInt(parts[0], 10) || 0
                root.muted = parts[1] === "yes"
            }
        }
    }

    Process {
        id: volCmd
        command: ["true"]
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: volProc.running = true
    }

    // Battery (UPower)
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercent: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: battery && (battery.state === UPowerDeviceState.Charging
        || battery.state === UPowerDeviceState.FullyCharged
        || battery.state === UPowerDeviceState.PendingCharge)

    function batteryIcon(cap) {
        var icons = [
            "󱢠 󱢠 󱢠 ", "󱢠 󱢠 󰛞 ", "󱢠 󱢠 󰛞 ", "󱢠 󱢠 󰋑 ", "󱢠 󰛞 󰋑 ",
            "󱢠 󰛞 󰋑 ", "󱢠 󰋑 󰋑 ", "󰛞 󰋑 󰋑 ", "󰛞 󰋑 󰋑 ", "󰋑 󰋑 󰋑 "
        ]
        var i = Math.floor(cap / 10)
        if (i < 0) i = 0
        if (i > 9) i = 9
        return icons[i]
    }

    // Keyboard layout (niri) — show short codes like waybar's kblayout script
    function shortLayout(name) {
        if (name.indexOf("Arabic") >= 0) return "AR"
        if (name.indexOf("English") >= 0) return "US"
        return name
    }

    // Network (iwd)
    property string networkText: ""
    property bool networkConnected: false

    Process {
        id: netProc
        command: ["sh", "-c", "~/.config/quickshell/scripts/network.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    var t = data.trim()
                    root.networkConnected = t.indexOf("󰖩") >= 0
                    t = t.replace(/^󰖩\s*/, "").replace(/^󰖪\s*/, "")
                    root.networkText = t
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }

    // Clock (updates every second, like waybar)
    property string clockText: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.clockText = Qt.formatDateTime(new Date(), "hh:mm AP")
        }
    }

    Component.onCompleted: {
        weatherProc.running = true
        prayerProc.running = true
        memProc.running = true
        netProc.running = true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            var s = "vol=" + root.volumePercent + "% muted=" + root.muted
                + "\nkblayout='" + root.shortLayout(niriIpc.keyboardLayoutName) + "'"
                + " mem='" + root.memText + "' net='" + root.networkText + "' conn=" + root.networkConnected
                + " bat=" + root.batteryPercent + " charging=" + root.charging
                + " weather='" + root.weatherText + "' prayer='" + root.prayerText + "'"
            debugProc.command = ["sh", "-c", "cat > /tmp/qs-state.txt <<'QSEOF'\n" + s + "\nQSEOF"]
            debugProc.running = true
        }
    }

    Process {
        id: debugProc
        command: ["true"]
    }

    // niri IPC — raw JSON over the $NIRI_SOCKET unix socket (quickshell's
    // built-in Niri module was removed). Subscribes to the event stream, which
    // delivers the full current state up-front, then incremental updates.
    component NiriIpc: Item {
        id: niri

        readonly property string socketPath: (function() {
            var p = Quickshell.env("NIRI_SOCKET")
            if (p) return p
            var rt = Quickshell.env("XDG_RUNTIME_DIR")
            var wd = Quickshell.env("WAYLAND_DISPLAY")
            return rt && wd ? rt + "/niri-ipc-" + wd + ".sock" : ""
        })()

        // Keyboard layout: XKB names + index of the active one.
        property var layoutNames: []
        property int layoutIdx: -1
        property string keyboardLayoutName: ""

        // Workspaces as {id, idx, name, output, active, focused, urgent}.
        property var workspaces: []

        signal workspacesUpdated()
        signal outputsUpdated()

        function refreshLayoutName() {
            var name = ""
            if (niri.layoutIdx >= 0 && niri.layoutIdx < niri.layoutNames.length)
                name = niri.layoutNames[niri.layoutIdx]
            if (name !== niri.keyboardLayoutName)
                niri.keyboardLayoutName = name
        }

        function setWorkspaces(list) {
            var out = []
            for (var i = 0; i < list.length; i++) {
                var w = list[i]
                out.push({
                    id: w.id,
                    idx: w.idx,
                    name: w.name,
                    output: w.output,
                    active: w.is_active,
                    focused: w.is_focused,
                    urgent: w.is_urgent
                })
            }
            niri.workspaces = out
            niri.workspacesUpdated()
            niri.outputsUpdated()
        }

        function patchWorkspace(id, patch) {
            var list = niri.workspaces
            for (var i = 0; i < list.length; i++) {
                if (list[i].id !== id) continue
                var w = list[i]
                var changed = false
                for (var k in patch) {
                    if (w[k] !== patch[k]) { w[k] = patch[k]; changed = true }
                }
                if (changed) {
                    niri.workspaces = list.slice()
                    niri.workspacesUpdated()
                }
                return
            }
        }

        function handleMessage(obj) {
            if (obj.Ok === "Handled" || obj.Err !== undefined) return
            if (obj.WorkspacesChanged) {
                niri.setWorkspaces(obj.WorkspacesChanged.workspaces || [])
            } else if (obj.WorkspaceActivated) {
                var act = obj.WorkspaceActivated
                if (act.focused) {
                    var list = niri.workspaces
                    var out = []
                    for (var i = 0; i < list.length; i++) {
                        var w = list[i]
                        out.push({
                            id: w.id, idx: w.idx, name: w.name, output: w.output,
                            active: w.active || w.id === act.id,
                            focused: w.id === act.id,
                            urgent: w.urgent
                        })
                    }
                    niri.workspaces = out
                    niri.workspacesUpdated()
                } else {
                    niri.patchWorkspace(act.id, { active: true })
                }
            } else if (obj.WorkspaceUrgencyChanged) {
                var urg = obj.WorkspaceUrgencyChanged
                niri.patchWorkspace(urg.id, { urgent: urg.urgent })
            } else if (obj.KeyboardLayoutsChanged) {
                var layouts = obj.KeyboardLayoutsChanged.keyboard_layouts
                niri.layoutNames = layouts && layouts.names ? layouts.names : []
                niri.layoutIdx = layouts && layouts.current_idx !== undefined ? layouts.current_idx : -1
                niri.refreshLayoutName()
            } else if (obj.KeyboardLayoutSwitched) {
                niri.layoutIdx = obj.KeyboardLayoutSwitched.idx
                niri.refreshLayoutName()
            }
        }

        function focusWorkspace(idx) {
            var msg = '{"Action":{"FocusWorkspace":{"reference":{"Index":' + idx + '}}}}\n'
            if (actionSock.connected) {
                actionSock.write(msg)
                actionSock.flush()
            } else if (niri.socketPath.length > 0) {
                niri.pendingAction = msg
                actionSock.path = niri.socketPath
                actionSock.connected = true
            }
        }

        property string pendingAction: ""

        // Event stream: emits full state, then one-line JSON events.
        Socket {
            id: streamSock
            path: niri.socketPath
            connected: niri.socketPath.length > 0
            parser: SplitParser {
                onRead: data => {
                    if (!data) return
                    var obj
                    try { obj = JSON.parse(data) } catch (e) { return }
                    niri.handleMessage(obj)
                }
            }
            onConnectionStateChanged: {
                if (connected) {
                    streamSock.write('"EventStream"\n')
                    streamSock.flush()
                }
            }
            onError: error => console.log("[niri] event stream error:", error)
        }

        // Separate socket for one-off requests (event stream stops reading requests).
        Socket {
            id: actionSock
            parser: SplitParser {
                onRead: data => {
                    if (data && data.indexOf('"Err"') >= 0) console.log("[niri] action error:", data)
                }
            }
            onConnectionStateChanged: {
                if (connected && niri.pendingAction.length > 0) {
                    actionSock.write(niri.pendingAction)
                    actionSock.flush()
                    niri.pendingAction = ""
                }
            }
            onError: error => console.log("[niri] action socket error:", error)
        }
    }

    NiriIpc {
        id: niriIpc
    }

    // A pill-shaped module, styled like the waybar modules.
    // Icons are rendered in a separate Text so Nerd Font glyphs keep full size
    // (Ndot 57's dot-matrix advance squashes fallback glyphs).
    component Module: Rectangle {
        id: pill
        property string label: ""
        property string icon: ""
        property color tint: root.primary
        property bool whiteText: false
        property alias clickArea: pillArea
        property alias wheelArea: pillArea

        readonly property color pillTextColor: pill.whiteText
            ? root.textColor : (root.luminance(tint) > 0.5 ? root.darkText : root.textColor)

        implicitWidth: pillRow.implicitWidth + 25
        implicitHeight: root.pillHeight - 2
        radius: 25
        border.width: 0
        color: root.withAlpha(tint, 1.0)
        opacity: 0.9

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 3

            Text {
                id: pillIcon
                visible: pill.icon.length > 0
                text: pill.icon
                color: pill.pillTextColor
                font.family: root.iconFont
                font.pixelSize: root.fontSize + 1
                font.weight: Font.Normal
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: pillText
                text: pill.label
                color: pill.pillTextColor
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.weight: Font.Black
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: pillArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }
    }

    // Workspace button, styled like #workspaces button
    component WorkspaceBtn: Rectangle {
        id: wsBtn
        property var ws: null
        readonly property bool focused: ws ? ws.focused : false
        readonly property bool urgent: ws ? ws.urgent : false

        width: 30
        height: root.pillHeight  + 0
        radius: 30
        border.width: 0
        color: focused ? root.withAlpha(root.primary, 1.0)
            : urgent ? root.withAlpha(root.error, 1.0) : "transparent"

        Text {
            text: wsBtn.ws ? wsBtn.ws.idx : ""
            color: wsBtn.focused ? "#000000" : "#ffffff"
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.weight: Font.Black
            anchors.centerIn: parent
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (wsBtn.ws) niriIpc.focusWorkspace(wsBtn.ws.idx)
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            property var modelData
            screen: modelData
            focusable: true

            anchors.top: true
            margins.top: 10
            implicitWidth: barContent.width
            implicitHeight: root.barHeight
            color: "transparent"
            exclusiveZone: root.barHeight


            readonly property string outputName: modelData ? modelData.name : ""
            property var workspaceList: []

            function refreshWorkspaces() {
                var list = []
                for (const ws of niriIpc.workspaces) {
                    if (ws.output === outputName) list.push(ws)
                }
                list.sort((a, b) => a.idx - b.idx)
                workspaceList = list
            }

            Connections {
                target: niriIpc
                function onWorkspacesUpdated() { bar.refreshWorkspaces() }
                function onOutputsUpdated() { bar.refreshWorkspaces() }
            }

            Component.onCompleted: refreshWorkspaces()

            Item {
                id: barContent
                width: leftGroup.width + centerGroup.width + rightGroup.width + root.groupSpacing + 7
                height: root.barHeight
                anchors.horizontalCenter: parent.horizontalCenter

                // modules-left: niri/workspaces
                Row {
                    id: leftGroup
                    x: 7
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.groupSpacing

                    Repeater {
                        model: bar.workspaceList
                        delegate: WorkspaceBtn {
                            ws: modelData
                        }
                    }
                }

                // modules-center: weather, prayer
                Row {
                    id: centerGroup
                    x: leftGroup.width + root.groupSpacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.groupSpacing

                    Module {
                        id: weatherPill
                        label: root.weatherText
                        tint: root.primary
                    }

                    Module {
                        id: prayerPill
                        label: root.prayerText
                        tint: root.error
                    }
                }

                // modules-right: spacer, kblayout, pulseaudio, memory, network, battery, clock
                Row {
                    id: rightGroup
                    x: barContent.width - rightGroup.width - 7
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.groupSpacing

                    Item { width: 3; height: 2 }

                    Module {
                        id: kbPill
                        label: root.shortLayout(niriIpc.keyboardLayoutName)
                        tint: root.tertiary
                    }

                    Module {
                        id: volPill
                        icon: root.volumeIcon
                        label: root.muted ? "MUTE" : root.volumePercent + "%"
                        tint: root.secondary

                        clickArea.onClicked: {
                            volCmd.command = ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
                            volCmd.running = true
                            volProc.running = true
                        }
                        wheelArea.onWheel: event => {
                            var delta = event.angleDelta.y > 0 ? "+5%" : "-5%"
                            volCmd.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", delta]
                            volCmd.running = true
                            volProc.running = true
                            event.accepted = true
                        }
                    }

                    Module {
                        id: memPill
                        icon: "󰍛"
                        label: root.memText
                        tint: root.error
                        whiteText: true
                    }

                    Module {
                        id: netPill
                        icon: root.networkConnected ? "󰖩" : "󰖪"
                        label: root.networkText
                        tint: root.tertiary
                        whiteText: true
                    }

                    Module {
                        id: batPill
                        icon: root.charging
                            ? "󰋠 󰛞 󰋑 󰋑"
                            : root.batteryIcon(root.batteryPercent)
                        label: root.batteryPercent
                        tint: root.secondary
                        whiteText: true
                    }

                    Module {
                        id: clockPill
                        icon: "󰥔"
                        label: root.clockText
                        tint: root.primary
                        whiteText: true

                        clickArea.onClicked: calPopup.open()
                    }
                }
            }

            // Calendar popup, opens above the clock pill
            PopupWindow {
                id: calPopup
                visible: false
                grabFocus: true
                implicitWidth: 250
                color: "transparent"

                BackgroundEffect.blurRegion: Region {
                    item: calPopupBody
                    radius: 16
                }

                property bool dismissedByOutside: false
                property bool closingBySelf: false
                property int shownYear: new Date().getFullYear()
                property int shownMonth: new Date().getMonth()

                // Date -> reminder list, keyed by "YYYY-MM-DD". Each entry is
                // { id, text, saved }. Reassigned on every change (never mutated
                // in place) so day-delegate bindings refresh.
                property var notes: ({})
                property string selectedKey: ""

                // Reminder entries of the currently selected date.
                property var entries: []
                property int selectedEntryId: -1
                property int newEntryId: -1
                property int entrySeq: 0

                readonly property int editorHeight: 164

                FileView {
                    id: notesFile
                    path: Quickshell.env("HOME") + "/.cache/quickshell/calendar-notes.json"
                    preload: true
                    printErrors: false

                    onLoaded: {
                        // Migrate the old "date -> string" format to entry lists.
                        var raw = notesAdapter.notes || {}
                        var converted = {}
                        var maxId = 0
                        for (var k in raw) {
                            var v = raw[k]
                            if (typeof v === "string")
                                converted[k] = [{ id: ++maxId, text: v, saved: true }]
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
                        console.log("[cal] notesFile loaded, keys=" + Object.keys(converted).length)
                    }

                    onLoadFailed: error => {
                        console.log("[cal] notesFile loadFailed error=" + error)
                        if (error === FileViewError.FileNotFound) notesFile.writeAdapter()
                    }

                    onAdapterUpdated: notesFile.writeAdapter()

                    onSaved: console.log("[cal] notesFile saved")
                    onSaveFailed: error => console.log("[cal] notesFile saveFailed error=" + error)

                    JsonAdapter {
                        id: notesAdapter
                        property var notes: ({})
                    }
                }

                Component.onCompleted: {
                    Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"])
                }

                function open() {
                    if (calPopup.dismissedByOutside) {
                        calPopup.dismissedByOutside = false
                        return
                    }
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
                    calPopupOut.restart()
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
                        out.push({ id: 0, text: v, saved: true })
                        return out
                    }
                    var n = typeof v.length === "number" ? v.length : 0
                    for (var i = 0; i < n; i++) {
                        var e = v[i]
                        if (e === null || e === undefined) continue
                        out.push({
                            id: typeof e.id === "number" ? e.id : 0,
                            text: e.text !== undefined && e.text !== null ? String(e.text) : "",
                            saved: !!e.saved
                        })
                    }
                    return out
                }

                function selectDay(key) {
                    console.log("[cal] selectDay key=" + key)
                    calPopup.selectedKey = key
                    calPopup.selectedEntryId = -1
                    calPopup.newEntryId = -1
                    calPopup.entries = calPopup.toEntryList(calPopup.notes[key])
                    calPopup.rebuildEntries()
                }

                function syncNotes() {
                    var copy = Object.assign({}, calPopup.notes || {})
                    if ((calPopup.entries || []).length === 0)
                        delete copy[calPopup.selectedKey]
                    else
                        copy[calPopup.selectedKey] = calPopup.entries.slice()
                    calPopup.notes = copy
                    notesAdapter.notes = JSON.parse(JSON.stringify(copy))
                }

                function rebuildEntries() {
                    entriesModel.clear()
                    var list = calPopup.entries || []
                    for (var i = 0; i < list.length; i++) {
                        entriesModel.append({ entryId: list[i].id, entryText: list[i].text, saved: list[i].saved })
                    }
                }

                function selectEntry(eid) {
                    if (calPopup.selectedEntryId !== eid) calPopup.selectedEntryId = eid
                }

                function addEntry() {
                    if (calPopup.selectedKey.length === 0) return
                    var entry = { id: ++calPopup.entrySeq, text: "", saved: false }
                    calPopup.entries = calPopup.entries.concat([entry])
                    calPopup.selectedEntryId = entry.id
                    calPopup.newEntryId = entry.id
                    calPopup.syncNotes()
                    calPopup.rebuildEntries()
                }

                function saveEntry(eid, text) {
                    var list = calPopup.entries || []
                    for (var i = 0; i < list.length; i++) {
                        if (list[i].id !== eid) continue
                        var trimmed = (text || "").trim()
                        if (trimmed.length === 0) return
                        var updated = list.slice()
                        updated[i] = { id: eid, text: trimmed, saved: true }
                        calPopup.entries = updated
                        calPopup.selectedEntryId = eid
                        calPopup.syncNotes()
                        calPopup.rebuildEntries()
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
                    calPopup.rebuildEntries()
                }

                function selectedDateLabel() {
                    if (calPopup.selectedKey.length === 0) return ""
                    var parts = calPopup.selectedKey.split("-")
                    var y = parseInt(parts[0], 10)
                    var m = parseInt(parts[1], 10) - 1
                    var d = parseInt(parts[2], 10)
                    return Qt.formatDate(new Date(y, m, d), "ddd, MMM d")
                }

                implicitHeight: 294 + (calPopup.selectedKey.length > 0 ? calPopup.editorHeight + 6 : 0)

                onVisibleChanged: {
                    if (visible) {
                        calPopup.rebuildModel()
                        calPopupBody.opacity = 0
                        calPopupSlide.y = 14
                        calPopupScale.xScale = 0.92
                        calPopupScale.yScale = 0.92
                        calPopupIn.restart()
                    } else {
                        calPopup.dismissedByOutside = !calPopup.closingBySelf
                        calPopup.closingBySelf = false
                        calPopup.selectedKey = ""
                        calPopup.selectedEntryId = -1
                        calPopup.newEntryId = -1
                        calPopup.entries = []
                        entriesModel.clear()
                    }
                }

                anchor {
                    item: clockPill
                    edges: Edges.Top
                    gravity: Edges.Top
                    adjustment: PopupAdjustment.All
                    rect.x: 0
                    rect.y: -10
                    rect.w: clockPill.width
                    rect.h: clockPill.height + 10
                }

                ParallelAnimation {
                    id: calPopupIn
                    running: false
                    NumberAnimation { target: calPopupBody; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: calPopupSlide; property: "y"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: calPopupScale; property: "xScale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: calPopupScale; property: "yScale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                }

                ParallelAnimation {
                    id: calPopupOut
                    running: false
                    NumberAnimation { target: calPopupBody; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InCubic }
                    NumberAnimation { target: calPopupSlide; property: "y"; to: 14; duration: 140; easing.type: Easing.InCubic }
                    NumberAnimation { target: calPopupScale; property: "xScale"; to: 0.92; duration: 140; easing.type: Easing.InCubic }
                    NumberAnimation { target: calPopupScale; property: "yScale"; to: 0.92; duration: 140; easing.type: Easing.InCubic }
                    onFinished: calPopup.visible = false
                }

                Rectangle {
                    id: calPopupBody
                    anchors.fill: parent
                    radius: 16
                    color: root.withAlpha(root.surface, 0.55)
                    border.width: 1
                    border.color: root.withAlpha(root.textColor, 0.08)
                    clip: true
                    opacity: 0

                    transform: [
                        Translate { id: calPopupSlide; y: 14 },
                        Scale {
                            id: calPopupScale
                            xScale: 0.92
                            yScale: 0.92
                            origin.x: width / 2
                            origin.y: height
                        }
                    ]

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            spacing: 8

                            Text {
                                text: "󰁍"
                                color: "#ffffff"
                                font.family: root.iconFont
                                font.pixelSize: root.fontSize + 1
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 26
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calPopup.shiftMonth(-1)
                                }
                            }

                            Text {
                                text: calPopup.monthName(calPopup.shownMonth) + " " + calPopup.shownYear
                                color: "#ffffff"
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize
                                font.weight: Font.Black
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "󰁔"
                                color: "#ffffff"
                                font.family: root.iconFont
                                font.pixelSize: root.fontSize + 1
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 26
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calPopup.shiftMonth(1)
                                }
                            }

                            Text {
                                text: "󰅖"
                                color: "#ffffff"
                                font.family: root.iconFont
                                font.pixelSize: root.fontSize + 1
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 26
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calPopup.close()
                                }
                            }
                        }

                        Row {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰥔"
                                color: "#ffffff"
                                font.family: root.iconFont
                                font.pixelSize: root.fontSize + 1
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")
                                color: "#ffffff"
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize - 1
                                font.weight: Font.Black
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
                                    color: "#ffffff"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 2
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
                                        color: isSelected
                                            ? root.primary
                                            : dayHover.containsMouse
                                                ? root.withAlpha(root.primary, 0.18)
                                                : isToday ? root.withAlpha(root.primary, 0.4) : "transparent"

                                        Text {
                                            id: dayNum
                                            anchors.centerIn: parent
                                            visible: day > 0
                                            text: day
                                            color: isSelected ? "#000000" : "#ffffff"
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fontSize
                                            font.weight: isSelected || isToday ? Font.Black : Font.Normal
                                        }

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 3
                                            visible: hasNote
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: isSelected
                                                ? (root.luminance(root.primary) > 0.5 ? root.darkText : root.textColor)
                                                : root.primary
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
                            Layout.preferredHeight: calPopup.editorHeight
                            visible: calPopup.selectedKey.length > 0
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                spacing: 8

                                Text {
                                    text: "󰃭"
                                    color: root.primary
                                    font.family: root.iconFont
                                    font.pixelSize: root.fontSize + 1
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: calPopup.selectedDateLabel()
                                    color: "#ffffff"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: Font.Black
                                    Layout.fillWidth: true
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: (calPopup.entries || []).length === 1
                                        ? "1 reminder"
                                        : (calPopup.entries || []).length + " reminders"
                                    color: "#ffffff"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 2
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: "󰅖"
                                    color: "#ffffff"
                                    font.family: root.iconFont
                                    font.pixelSize: root.fontSize + 1
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 22
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter

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
                                    radius: 7
                                    color: addHover.containsMouse
                                        ? root.withAlpha(root.primary, 0.35)
                                        : root.withAlpha(root.primary, 0.22)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: root.luminance(root.primary) > 0.5 ? root.darkText : root.textColor
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 2
                                        font.weight: Font.Black
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
                                    radius: 7
                                    color: minusHover.containsMouse && calPopup.selectedEntryId >= 0
                                        ? root.withAlpha(root.error, 0.35)
                                        : root.withAlpha(root.textColor, calPopup.selectedEntryId >= 0 ? 0.12 : 0.05)
                                    enabled: calPopup.selectedEntryId >= 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: "-"
                                        color: calPopup.selectedEntryId >= 0 ? root.error : root.withAlpha(root.textColor, 0.3)
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 2
                                        font.weight: Font.Black
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

                                Text {
                                    text: "Enter to save"
                                    color: "#ffffff"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 2
                                    verticalAlignment: Text.AlignVCenter
                                }
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
                                        color: root.withAlpha(root.textColor, 0.3)
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

                                            readonly property bool isSelected: calPopup.selectedEntryId === entryId

                                            width: entriesCol.width
                                            height: 30
                                            radius: 8
                                            color: root.withAlpha(root.textColor, saved ? 0.05 : 0.08)
                                            border.width: 1
                                            border.color: isSelected
                                                ? root.primary
                                                : saved ? "transparent" : root.withAlpha(root.textColor, 0.15)

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 4
                                                spacing: 6

                                                TextField {
                                                    id: entryInput
                                                    visible: !saved
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    text: entryText
                                                    color: "#ffffff"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: root.fontSize
                                                    selectByMouse: true
                                                    background: Item {}
                                                    onActiveFocusChanged: {
                                                        if (activeFocus) calPopup.selectEntry(entryId)
                                                    }
                                                    onAccepted: calPopup.saveEntry(entryId, entryInput.text)
                                                }

                                                Text {
                                                    visible: saved
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    text: entryText
                                                    color: "#ffffff"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: root.fontSize
                                                    font.italic: true
                                                    elide: Text.ElideRight
                                                    verticalAlignment: Text.AlignVCenter
                                                }

                                                Rectangle {
                                                    visible: !saved
                                                    Layout.preferredWidth: 22
                                                    Layout.preferredHeight: 22
                                                    radius: 6
                                                    color: saveHover.containsMouse ? root.withAlpha(root.primary, 0.25) : "transparent"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰄴"
                                                        color: root.primary
                                                        font.family: root.iconFont
                                                        font.pixelSize: root.fontSize
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

                                Text {
                                    anchors.centerIn: parent
                                    visible: entriesModel.count === 0
                                    text: "No reminders yet — press + to add"
                                    color: "#ffffff"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

