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

// matugen 1786497656

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
    readonly property int groupSpacing: 15

    readonly property color textColor: "#ffffff"
    readonly property color darkText: Matugen.shadow
    readonly property real pillAlpha: 0.45

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
        property alias clickArea: pillArea
        property alias wheelArea: pillArea

        readonly property color pillTextColor: root.luminance(tint) > 0.5 ? root.darkText : root.textColor

        implicitWidth: pillRow.implicitWidth + 25
        implicitHeight: root.pillHeight - 2
        radius: height / 0
        border.width: 0
        color: root.withAlpha(tint, root.pillAlpha)
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
        color: focused ? root.withAlpha(root.primary, root.pillAlpha)
            : urgent ? root.withAlpha(root.error, root.pillAlpha) : "transparent"

        Text {
            text: wsBtn.ws ? wsBtn.ws.idx : ""
            color: root.luminance(wsBtn.color) > 0.5 ? root.darkText : root.textColor
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

            anchors.bottom: true
            margins.bottom: 10
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
                width: leftGroup.width + centerGroup.width + rightGroup.width + root.groupSpacing * 2
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

                // modules-center: weather, prayer (centered between left and right groups)
                Row {
                    id: centerGroup
                    x: leftGroup.width + root.groupSpacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.groupSpacing

                    Module {
                        id: weatherPill
                        label: root.weatherText
                        tint: root.primaryContainer
                    }

                    Module {
                        id: prayerPill
                        label: root.prayerText
                        tint: root.errorContainer
                    }
                }

                // modules-right: spacer, kblayout, pulseaudio, memory, network, battery, clock
                Row {
                    id: rightGroup
                    x: leftGroup.width + centerGroup.width + root.groupSpacing * 1
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.groupSpacing

                    Item { width: 3; height: 2 }

                    Module {
                        id: kbPill
                        label: root.shortLayout(niriIpc.keyboardLayoutName)
                        tint: root.tertiaryContainer
                    }

                    Module {
                        id: volPill
                        icon: root.volumeIcon
                        label: root.muted ? "MUTE" : root.volumePercent + "%"
                        tint: root.secondaryContainer

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
                    }

                    Module {
                        id: netPill
                        icon: root.networkConnected ? "󰖩" : "󰖪"
                        label: root.networkText
                        tint: root.tertiary
                    }

                    Module {
                        id: batPill
                        icon: root.charging
                            ? "󰋠 󰛞 󰋑 󰋑"
                            : root.batteryIcon(root.batteryPercent)
                        label: root.batteryPercent
                        tint: root.secondary
                    }

                    Module {
                        id: clockPill
                        icon: "󰥔"
                        label: root.clockText
                        tint: root.primary

                        clickArea.onClicked: calPopup.open()
                    }
                }
            }

            // Calendar popup, opens above the clock pill
            PopupWindow {
                id: calPopup
                visible: false
                grabFocus: true
                implicitWidth: 200
                color: "transparent"

                BackgroundEffect.blurRegion: Region {
                    item: calPopupBody
                    radius: 16
                }

                property bool dismissedByOutside: false
                property bool closingBySelf: false
                property int shownYear: new Date().getFullYear()
                property int shownMonth: new Date().getMonth()

                // Date -> note text, keyed by "YYYY-MM-DD". Reassigned on every
                // change (never mutated in place) so day-delegate bindings refresh.
                property var notes: ({})
                property string selectedKey: ""

                readonly property int editorHeight: 140

                FileView {
                    id: notesFile
                    path: Quickshell.env("HOME") + "/.cache/quickshell/calendar-notes.json"
                    preload: true
                    printErrors: false

                    onLoaded: {
                        console.log("[cal] notesFile loaded, adapter keys=" + Object.keys(notesAdapter.notes).length)
                        calPopup.notes = notesAdapter.notes
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

                function selectDay(key) {
                    console.log("[cal] selectDay key=" + key)
                    calPopup.selectedKey = key
                    noteInput.text = calPopup.notes[key] || ""
                    Qt.callLater(() => noteInput.forceActiveFocus())
                }

                function saveCurrent() {
                    console.log("[cal] saveCurrent selectedKey='" + calPopup.selectedKey + "' text='" + (noteInput.text || "") + "'")
                    if (calPopup.selectedKey.length === 0) return
                    var copy = Object.assign({}, calPopup.notes || {})
                    var text = noteInput.text.trim()
                    if (text.length > 0) copy[calPopup.selectedKey] = text
                    else delete copy[calPopup.selectedKey]
                    calPopup.notes = copy
                    notesAdapter.notes = copy
                    console.log("[cal] saveCurrent done, note='" + calPopup.notes[calPopup.selectedKey] + "' keys=" + Object.keys(calPopup.notes).length)
                }

                function clearCurrent() {
                    noteInput.text = ""
                    calPopup.saveCurrent()
                }

                function selectedDateLabel() {
                    if (calPopup.selectedKey.length === 0) return ""
                    var parts = calPopup.selectedKey.split("-")
                    var y = parseInt(parts[0], 10)
                    var m = parseInt(parts[1], 10) - 1
                    var d = parseInt(parts[2], 10)
                    return Qt.formatDate(new Date(y, m, d), "ddd, MMM d")
                }

                implicitHeight: 280 + (calPopup.selectedKey.length > 0 ? calPopup.editorHeight : 0)

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
                        noteInput.text = ""
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
                                color: root.textColor
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
                                color: root.textColor
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize
                                font.weight: Font.Black
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "󰁔"
                                color: root.textColor
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
                                color: root.textColor
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

                            Repeater {
                                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                                delegate: Text {
                                    width: (calPopupBody.width - 24) / 7
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    color: root.withAlpha(root.textColor, 0.5)
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
                                            color: isSelected
                                                ? (root.luminance(root.primary) > 0.5 ? root.darkText : root.textColor)
                                                : root.textColor
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
                            Layout.preferredHeight: 134
                            visible: calPopup.selectedKey.length > 0
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                spacing: 8

                                Text {
                                    text: calPopup.selectedDateLabel()
                                    color: root.textColor
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: Font.Black
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "󰅖"
                                    color: root.withAlpha(root.textColor, 0.7)
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

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 8
                                color: root.withAlpha(root.textColor, 0.08)
                                border.width: 1
                                border.color: noteInput.activeFocus ? root.primary : root.withAlpha(root.textColor, 0.15)

                                TextEdit {
                                    id: noteInput
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    color: root.textColor
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    wrapMode: TextEdit.Wrap
                                    selectByMouse: true
                                }

                                Text {
                                    anchors.fill: noteInput
                                    visible: noteInput.text.length === 0 && !noteInput.activeFocus
                                    text: "What do you plan to do?"
                                    color: root.withAlpha(root.textColor, 0.4)
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                spacing: 6

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredWidth: 64
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: root.withAlpha(root.textColor, 0.08)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Clear"
                                        color: root.textColor
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calPopup.clearCurrent()
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 64
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: root.primary

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Save"
                                        color: root.luminance(root.primary) > 0.5 ? root.darkText : root.textColor
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize
                                        font.weight: Font.Black
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            calPopup.saveCurrent()
                                            calPopup.close()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
