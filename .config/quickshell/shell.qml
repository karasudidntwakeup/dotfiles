import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

// Waybar-style bar for niri.
// Mirrors ~/.config/waybar (modules + Material You pill styling).
// Palette comes from matugen via colors.js (regenerated on wallpaper change).

// matugen 1787526211

ShellRoot {
    id: root

    // Palette (matugen). colors.js is parsed at runtime and watched for
    // changes, so regenerating it (wallpaper / scheme style change) recolors
    // the bar live. A static JS import would be cached by the QML engine and
    // never pick up new values.
    FileView {
        id: colorFile
        property var paletteMap: ({})
        path: Quickshell.shellDir + "/colors.js"
        watchChanges: true
        blockLoading: true
        onFileChanged: colorFile.reload()
        onLoadFailed: error => console.log("[colors] failed to load colors.js:", error)
        onLoaded: {
            var map = {}
            var re = /var\s+(\w+)\s+=\s+"([^"]*)"/g
            var m
            var content = String(colorFile.text())
            while ((m = re.exec(content)) !== null) map[m[1]] = m[2]
            colorFile.paletteMap = map
        }
    }

    function colorOf(name) {
        var v = colorFile.paletteMap[name]
        return v === undefined ? "#808080" : v
    }

    // Quick Shell-only light/dark mode, written by the rofi wallpaper changer
    // into qs-theme.json. Does NOT touch GTK/Qt/terminal or any other app.
    // mode "dark" = current look (matugen light pills + dark text).
    // mode "light" = matugen dark pills + white text, Quick Shell only.
    FileView {
        id: qsThemeFile
        property var qsTheme: ({})
        path: Quickshell.shellDir + "/qs-theme.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: qsThemeFile.reload()
        onLoadFailed: error => console.log("[qs-theme] failed to load qs-theme.json:", error)
        onLoaded: {
            var map = {}
            try {
                map = JSON.parse(String(qsThemeFile.text())) || {}
            } catch (e) {
                console.log("[qs-theme] parse error:", e)
            }
            qsThemeFile.qsTheme = map
        }
    }

    readonly property bool qsLight: qsThemeFile.qsTheme["mode"] === "light"

    // Quick Shell-only "Light" mode uses matugen's genuine `_light` scheme
    // colors for the pill backgrounds. matugen always emits both `_light`
    // and `_dark` for every palette entry, so choosing Light in the wallpaper
    // changer gives Quick Shell the matugen light-scheme (dark) pills without
    // ever re-running matugen in light mode, i.e. the rest of the system is
    // untouched.
    readonly property color qsPillFg: "#ffffff"
    readonly property color qsPillFallbackBg: "#1a1b1e"

    // Pill background: Light mode -> matugen `_light` variant (dark pill on
    // these wallpapers), with a dark fallback if a color has no `_light`
    // variant (e.g. prayer, battery). Dark mode -> normal palette (current look).
    function pillColor(name) {
        if (!root.qsLight) return colorOf(name)
        var v = colorFile.paletteMap[name + "_light"]
        return v === undefined ? root.qsPillFallbackBg : v
    }

    // Palette (matugen, via colors.js)
    readonly property color primary: colorOf("primary")
    readonly property color error: colorOf("error")
    readonly property color outlineVariant: colorOf("outline_variant")

    // Typography (matches waybar style.css)
    readonly property string fontFamily: "Ndot 57"
    readonly property string uiFont: "Inter"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int fontSize: 13

    // Layout (matches waybar config.jsonc)
    readonly property int barHeight: 48
    readonly property int pillHeight: 32
    readonly property int groupSpacing: 5

    readonly property color textColor: "#000000"
    readonly property color darkText: colorOf("shadow")

    function luminance(color) {
        return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
    }

    function withAlpha(color, a) {
        return Qt.rgba(color.r, color.g, color.b, a)
    }

    // Script-driven modules
    property string weatherText: ""
    property string prayerText: ""
    property string prayerName: ""
    property date prayerTarget: new Date(0)

    function fmtCountdown(ms) {
        var m = Math.max(0, Math.round(ms / 60000))
        var h = Math.floor(m / 60)
        return h > 0 ? h + "h " + (m % 60) + "m" : m + "m"
    }

    function updatePrayerCountdown() {
        if (prayerName.length > 0)
            prayerText = prayerName + " in " + fmtCountdown(prayerTarget.getTime() - Date.now())
    }
    property string memText: ""

    Process {
        id: weatherProc
        command: ["sh", "-c", "~/.config/waybar/scripts/weather.sh"]
        stdout: SplitParser {
            onRead: data => {
                var t = data ? data.trim() : ""
                if (t && !/error|unavailable|failed|not available|⚠/i.test(t))
                    weatherText = t
                else
                    weatherText = ""
            }
        }
        onExited: code => { if (code !== 0) weatherText = "" }
    }

    Process {
        id: prayerProc
        command: ["sh", "-c", "~/.config/waybar/scripts/prayer.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split("|")
                if (parts.length !== 2 || /error|unavailable|failed/i.test(parts[0])) {
                    prayerText = ""
                    prayerName = ""
                    return
                }
                var p = parts[1].split(/[\s:-]/)
                var d = new Date(parseInt(p[2]), parseInt(p[1]) - 1, parseInt(p[0]),
                                 parseInt(p[3]), parseInt(p[4]))
                if (isNaN(d.getTime())) {
                    prayerText = ""
                    prayerName = ""
                    return
                }
                prayerTarget = d
                prayerName = parts[0]
                updatePrayerCountdown()
            }
        }
        onExited: code => { if (code !== 0) { prayerText = ""; prayerName = "" } }
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
        interval: 600000
        running: true
        repeat: true
        onTriggered: prayerProc.running = true
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: updatePrayerCountdown()
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
    }

    // pactl subscribe streams audio-server events, so the pill refreshes only
    // when a sink or server property actually changes instead of polling.
    Process {
        id: volWatch
        command: ["sh", "-c", "exec pactl subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var t = data.toLowerCase()
                if ((t.indexOf("sink") >= 0 || t.indexOf("server") >= 0) && !volProc.running)
                    volProc.running = true
            }
        }
        onExited: volRestart.restart()
    }

    Timer {
        id: volRestart
        interval: 5000
        repeat: false
        onTriggered: volWatch.running = true
    }

    // Battery (UPower)
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercent: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: battery && (battery.state === UPowerDeviceState.Charging
        || battery.state === UPowerDeviceState.FullyCharged
        || battery.state === UPowerDeviceState.PendingCharge)

    readonly property var batteryIcons: [
        "󱢠 󱢠 󱢠  ", "󱢠 󱢠 󰛞  ", "󱢠 󱢠 󰛞  ", "󱢠 󱢠 󰋑  ", "󱢠 󰛞 󰋑  ",
        "󱢠 󰛞 󰋑  ", "󱢠 󰋑 󰋑  ", "󰛞 󰋑 󰋑  ", "󰛞 󰋑 󰋑  ", "󰋑 󰋑 󰋑  "
    ]

    function batteryIcon(cap) {
        var i = Math.floor(cap / 10)
        if (i < 0) i = 0
        if (i > 9) i = 9
        return root.batteryIcons[i]
    }

    // Keyboard layout (niri) — show short codes like waybar's kblayout script
    function shortLayout(name) {
        if (name.indexOf("Arabic") >= 0) return "AR"
        if (name.indexOf("English") >= 0) return "US"
        return name
    }

    // Network (iwd)
    property string networkText: ""
    property string networkIp: ""
    property bool networkConnected: false
    property int networkSignal: 0

    // strength tint for pills: strong->primary, mid->tertiary, weak->error
    function signalTint(sig) {
        var s = sig || 0
        if (s >= 60) return root.colorOf("primary_container")
        if (s >= 30) return root.colorOf("tertiary_container")
        return root.colorOf("error_container")
    }

    Process {
        id: netProc
        command: ["sh", "-c", "sh ~/.config/quickshell/scripts/wifi.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    try {
                        var d = JSON.parse(data.trim())
                        root.networkConnected = d.connected === true
                        root.networkText = d.ssid || ""
                        root.networkIp = d.ip || ""
                        root.networkSignal = parseInt(d.signal) || 0
                    } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }

    // Bluetooth (bluetoothctl)
    property string bluetoothText: ""
    property string bluetoothStatus: "off"

    Process {
        id: btProc
        command: ["sh", "-c", "~/.config/quickshell/scripts/bluetooth.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    var t = data.trim()
                    if (t.indexOf("󰂲") >= 0) {
                        root.bluetoothStatus = "off"
                        root.bluetoothText = "OFF"
                    } else if (t.indexOf("󰂱") >= 0) {
                        root.bluetoothStatus = "connected"
                        root.bluetoothText = t.replace(/^󰂱\s*/, "")
                    } else {
                        root.bluetoothStatus = "on"
                        root.bluetoothText = "ON"
                    }
                }
            }
        }
    }

    Process {
        id: btCmd
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: btProc.running = true
    }

    // Media (playerctl)
    property string mediaStatus: "none"
    property string mediaText: ""
    property real mediaPos: 0
    property real mediaLen: 0
    property string mediaArt: ""
    readonly property real mediaProgress: mediaLen > 0
        ? (mediaPos * 1000000) / mediaLen : 0
    readonly property string mediaIcon: mediaStatus === "Playing" ? "󰎆" : mediaStatus === "Paused" ? "󰏤" : "󰎇"

    Process {
        id: mediaProc
        command: ["sh", "-c", "~/.config/quickshell/scripts/media.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split("|")
                root.mediaStatus = parts[0] || "none"
                root.mediaText = parts.length > 1 ? parts[1] : ""
                root.mediaPos = parseFloat(parts[2]) || 0
                root.mediaLen = parseFloat(parts[3]) || 0
                root.mediaArt = parts.length > 4 ? parts[4] : ""
            }
        }
    }

    Process {
        id: mediaCmd
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: mediaProc.running = true
    }

    // Countdown timer (controlled from the clock popup)
    readonly property int defaultTimerMs: 25 * 60000
    property real timerRemainingMs: defaultTimerMs
    property bool timerRunning: false
    property real timerTarget: 0

    function fmtTimer(ms) {
        var s = Math.max(0, Math.ceil(ms / 1000))
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        var pad = n => n < 10 ? "0" + n : "" + n
        return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : pad(m) + ":" + pad(sec)
    }

    function adjustTimerMinutes(delta) {
        var next = Math.round(timerRemainingMs / 60000) + delta
        next = Math.max(1, Math.min(next, 3599))
        timerRemainingMs = next * 60000
        if (timerRunning) timerTarget = Date.now() + timerRemainingMs
    }

    function toggleTimer() {
        if (timerRunning) {
            timerRemainingMs = Math.max(0, timerTarget - Date.now())
            timerRunning = false
        } else {
            if (timerRemainingMs <= 0) timerRemainingMs = defaultTimerMs
            timerTarget = Date.now() + timerRemainingMs
            timerRunning = true
        }
    }

    function resetTimer() {
        timerRunning = false
        timerRemainingMs = defaultTimerMs
    }

    Timer {
        interval: 500
        running: root.timerRunning
        repeat: true
        onTriggered: {
            var left = root.timerTarget - Date.now()
            if (left <= 0) {
                root.timerRunning = false
                root.timerRemainingMs = 0
                Quickshell.execDetached(["sh", "-c",
                    "{ sleep 1; paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga; } &\n" +
                    "resp=$(notify-send -u critical -i alarm-clock -t 10000 -A 'default=Stop' 'Timer' 'Time is up! 󰄉');\n" +
                    "[ \"$resp\" = \"default\" ] && pkill -f 'paplay .*alarm-clock-elapsed\\.oga'"])
            } else {
                root.timerRemainingMs = left
            }
        }
    }

    // Clock (checks every second, only repaints when the minute changes)
    property string clockText: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var t = Qt.formatDateTime(new Date(), "hh:mm AP")
            if (t !== root.clockText) root.clockText = t
        }
    }

    Component.onCompleted: {
        weatherProc.running = true
        prayerProc.running = true
        memProc.running = true
        netProc.running = true
        btProc.running = true
        mediaProc.running = true
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
            var occMap = {}
            for (var k = 0; k < niri.workspaces.length; k++)
                if (niri.workspaces[k].occupied) occMap[niri.workspaces[k].id] = true
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
                    urgent: w.is_urgent,
                    occupied: !!occMap[w.id]
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
                var copy = list.slice()
                copy[i] = Object.assign({}, copy[i], patch)
                niri.workspaces = copy
                niri.workspacesUpdated()
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
                            active: w.id === act.id,
                            focused: w.id === act.id,
                            urgent: w.urgent,
                            occupied: w.occupied
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

        function refreshOccupied() {
            var occ = {}
            var wins = ocProc.queue
            for (var i = 0; i < wins.length; i++) {
                var win = wins[i]
                if (win.workspace_id !== undefined && win.workspace_id !== null)
                    occ[win.workspace_id] = true
            }
            var list = niri.workspaces
            var out = list.slice()
            for (var j = 0; j < out.length; j++) {
                out[j].occupied = !!occ[out[j].id]
            }
            niri.workspaces = out
            niri.workspacesUpdated()
        }

        // Poll open windows so workspace dots show as occupied/empty.
        Process {
            id: ocProc
            property var queue: []
            command: ["sh", "-c", "niri msg -j windows 2>/dev/null"]
            stdout: SplitParser {
                onRead: data => {
                    if (!data) return
                    try { ocProc.queue = JSON.parse(data) } catch (e) { ocProc.queue = [] }
                    niri.refreshOccupied()
                }
            }
            onExited: {}
        }

        Timer {
            id: ocPoller
            interval: 4000
            running: true
            repeat: true
            onTriggered: ocProc.running = true
        }

        Component.onCompleted: Qt.callLater(() => ocProc.running = true)
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
        property int padX: 14
        property color tint: root.primary
        property bool whiteText: false
        property alias clickArea: pillArea
        property alias wheelArea: pillArea

        // Light mode: Quick Shell forces white font on its dark pills.
        // Otherwise: white font on dark pills, black on light pills.
        readonly property color pillTextColor: root.qsLight
            ? root.qsPillFg
            : (root.luminance(tint) > 0.5 ? root.darkText : "#ffffff")

        implicitWidth: pillRow.implicitWidth + pill.padX
        implicitHeight: root.pillHeight - 2
        radius: 8
        color: tint
        scale: (pillArea.pressed ? 0.96 : (pillArea.containsMouse ? 1.03 : 1.0)) * pill.popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        property real popScale: 1.0
        SequentialAnimation {
            id: pillPopAnim
            NumberAnimation { target: pill; property: "popScale"; to: 1.06; duration: 100; easing.type: Easing.OutQuad }
            NumberAnimation { target: pill; property: "popScale"; to: 1.0; duration: 300; easing.type: Easing.OutQuint }
        }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 4

            Text {
                id: pillIcon
                visible: pill.icon.length > 0
                text: pill.icon
                color: pill.pillTextColor
                font.family: root.iconFont
                font.pixelSize: root.fontSize + 2
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
            onClicked: pillPopAnim.start()
        }
    }

    // Media control button, serpantinum IconButton style (Nerd Font glyph).
    component MediaBtn: Rectangle {
        id: mbtn
        property string icon: "play"
        property color fore: "#000000"
        property color back: "#00000000"
        property real radiusPx: 10
        signal activated()

        readonly property string glyph: mbtn.icon === "prev" ? "󰒮"
            : mbtn.icon === "next" ? "󰒭"
            : mbtn.icon === "pause" ? "󰏤"
            : "󰐊"

        radius: radiusPx
        color: !mbtn.enabled ? back
            : (mbtnArea.pressed ? Qt.darker(back, 1.12)
            : (mbtnArea.containsMouse ? Qt.lighter(back, 1.12) : back))
        Behavior on color { ColorAnimation { duration: 180 } }

        scale: (!mbtn.enabled ? 1.0
            : (mbtnArea.pressed ? 1.06 : (mbtnArea.containsMouse ? 1.04 : 1.0))) * mbtn.popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        property real popScale: 1.0
        SequentialAnimation {
            id: mbtnPopAnim
            running: false
            NumberAnimation { target: mbtn; property: "popScale"; to: 1.1; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: mbtn; property: "popScale"; to: 1.0; duration: 420; easing.type: Easing.OutQuint }
        }

        Text {
            anchors.centerIn: parent
            text: mbtn.glyph
            font.family: root.iconFont
            font.pixelSize: Math.min(mbtn.width, mbtn.height) * 0.5
            color: mbtn.fore
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: mbtnArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                mbtn.activated()
                mbtnPopAnim.start()
            }
        }
    }

    // Workspace dots with a sliding active highlight, wrapped in a pill
    // container (serpantinum WorkspacesWidget style).
    component Workspaces: Rectangle {
        id: wsWidget
        property var workspaces: []
        readonly property int count: workspaces.length
        readonly property int activeIndex: (function() {
            for (var i = 0; i < workspaces.length; i++)
                if (workspaces[i].focused) return i
            for (var j = 0; j < workspaces.length; j++)
                if (workspaces[j].active) return j
            return -1
        })()
        readonly property real dotW: 18
        readonly property real activeW: 36
        readonly property real dotH: 18
        readonly property real dotSpacing: 8
        readonly property real pillPad: 11
        readonly property real dotRadius: 8

        function contentWidth() {
            return (count - 1) * dotW + activeW + dotSpacing * (count - 1)
        }

        width: contentWidth() + pillPad * 2
        height: root.pillHeight
        radius: 8
        color: root.pillColor("primary_container")
        border.width: 0

        Row {
            id: wsDotRow
            x: wsWidget.pillPad
            anchors.verticalCenter: parent.verticalCenter
            spacing: wsWidget.dotSpacing

            Repeater {
                model: wsWidget.workspaces
                delegate: Item {
                    readonly property int idx: index
                    readonly property bool focused: wsWidget.activeIndex === idx
                    readonly property bool occupied: !!modelData.occupied

                    width: focused ? wsWidget.activeW : wsWidget.dotW
                    height: wsWidget.dotH
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                    Rectangle {
                        anchors.fill: parent
                        radius: wsWidget.dotRadius
                        color: root.qsLight ? "#ffffff" : root.colorOf("on_primary_container")
                        opacity: focused ? 0.7 : (occupied ? 0.45 : 0.18)
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData) niriIpc.focusWorkspace(modelData.idx)
                        }
                    }
                }
            }
        }
    }

    // ── LOCKSCREEN ──
    property bool lockActive: false

    Process {
        id: lockListener
        command: ["sh", "-c", "mkdir -p ~/.cache/quickshell && mkfifo ~/.cache/quickshell/lock-fifo 2>/dev/null; while true; do cat ~/.cache/quickshell/lock-fifo; done"]
        running: true
        stdout: SplitParser {
            onRead: data => { if (data) lockActive = true }
        }
    }

    WlSessionLock {
        id: wLock
        locked: lockActive
        onLockedChanged: {
            if (locked) passSurface.forceActiveFocus()
        }

        WlSessionLockSurface {
            color: "#000000"
            Item {
                anchors.fill: parent
                clip: true
                LockSurface {
                    id: passSurface
                    anchors.fill: parent
                    onUnlocked: lockActive = false
                }
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
            }

            Component.onCompleted: refreshWorkspaces()

            Item {
                id: barContent
                width: barRow.implicitWidth + 10
                height: root.barHeight
                anchors.horizontalCenter: parent.horizontalCenter


                Row {
                    id: barRow
                    anchors.centerIn: parent
                    spacing: root.groupSpacing

                    Module {
                        id: weatherPill
                        label: root.weatherText
                        tint: root.pillColor("primary_fixed_dim")
                        visible: root.weatherText.length > 0
                    }

                    Module {
                        id: prayerPill
                        label: root.prayerText
                        tint: root.pillColor("prayer")
                        visible: root.prayerText.length > 0
                    }

                    Module {
                        id: btPill
                        icon: root.bluetoothStatus === "off" ? "󰂲" : root.bluetoothStatus === "connected" ? "󰂱" : "󰂯"
                        label: root.bluetoothText
                        tint: root.pillColor("tertiary_container")
                        visible: root.bluetoothStatus === "connected"

                        clickArea.onClicked: {
                            btCmd.command = ["sh", "-c", "bluetoothctl disconnect"]
                            btCmd.running = true
                            btProc.running = true
                        }
                    }

                    Workspaces {
                        id: wsWidget
                        workspaces: bar.workspaceList
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Module {
                        id: kbPill
                        label: root.shortLayout(niriIpc.keyboardLayoutName)
                        tint: root.pillColor("tertiary_fixed_dim")
                    }

                    Module {
                        id: mediaPill
                        icon: root.mediaIcon
                        tint: root.pillColor("primary_fixed_dim")
                        visible: root.mediaStatus === "Playing"

                        clickArea.onClicked: {
                            calPopup.forceClose()
                            wifiPopup.wifiForceClose()
                            if (mediaPopup.visible) mediaPopup.mediaClose()
                            else mediaPopup.mediaOpen()
                        }
                    }

                    Module {
                        id: volPill
                        icon: root.volumeIcon
                        label: root.muted ? "MUTE" : root.volumePercent + "%"
                        tint: root.pillColor("secondary_fixed_dim")

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
                        tint: root.pillColor("primary_container")
                    }

                    Module {
                        id: netPill
                        icon: root.networkConnected ? "󰖩" : "󰖪"
                        label: root.networkConnected ? (root.networkIp + (root.networkSignal ? "  •  " + root.networkSignal + "%" : "") || root.networkText) : "No net"
                        tint: root.pillColor("secondary_container")
                        visible: true

                        clickArea.onClicked: {
                            calPopup.forceClose()
                            mediaPopup.mediaForceClose()
                            if (wifiPopup.visible) wifiPopup.wifiClose()
                            else wifiPopup.wifiOpen()
                        }
                    }

                    Module {
                        id: batPill
                        icon: root.charging
                            ? "󰋠 󰛞 󰋑 󰋑"
                            : root.batteryIcon(root.batteryPercent)
                        label: root.batteryPercent + " %"
                        tint: root.pillColor("battery")
                        color: root.pillColor("battery")
                    }

                    Module {
                        id: clockPill
                        icon: "󰥔"
                        label: root.clockText
                        tint: root.pillColor("secondary_fixed")

                        clickArea.onClicked: {
                            mediaPopup.mediaForceClose()
                            wifiPopup.wifiForceClose()
                            calPopup.open()
                        }
                    }
                }
            }

            // Music popup, opens above the media pill
            PopupWindow {
            id: mediaPopup
            visible: false
            grabFocus: true
            implicitWidth: 300
            implicitHeight: 160
            color: "transparent"

            BackgroundEffect.blurRegion: Region {
                item: mediaPopupBody
                radius: 20
            }
            mask: Region {
                Region { item: mediaPopupBody; radius: 20 }
            }

            // Body fills the whole surface; dismiss via outside click.
            Rectangle {
                id: mediaPopupBody
                width: parent.width
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: mediaPopup.animProgress < 1 ? 16 * (1.0 - mediaPopup.animProgress) : 0
                radius: 20
                color: root.colorOf("primary_fixed_dim")
                border.width: 1
                border.color: root.withAlpha(root.outlineVariant, 0.35)
                opacity: mediaPopup.animProgress
                scale: 0.92 + (0.08 * mediaPopup.animProgress)
                transformOrigin: Item.Top

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Row {
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            width: 52
                            height: 52
                            radius: 8
                            color: root.withAlpha(root.textColor, 0.1)
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: root.mediaArt
                                fillMode: Image.PreserveAspectCrop
                                visible: root.mediaArt.length > 0
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.mediaIcon
                                color: root.textColor
                                font.family: root.iconFont
                                font.pixelSize: root.fontSize + 4
                            }
                        }

                        Text {
                            id: mediaPopupTitle
                            width: parent.width - 52 - 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.mediaText
                            wrapMode: Text.Wrap
                            color: root.textColor
                            font.family: root.uiFont
                            font.pixelSize: root.fontSize + 1
                            font.weight: Font.Bold
                        }
                    }

                    // Seek slider
                    Item {
                        width: parent.width
                        height: 18

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 5
                            radius: 3
                            color: root.withAlpha(root.textColor, 0.2)
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * root.mediaProgress
                            height: 5
                            radius: 3
                            color: root.textColor
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                var frac = mouse.x / parent.width
                                mediaCmd.command = ["playerctl", "position",
                                    String(frac * root.mediaLen / 1000000)]
                                mediaCmd.running = true
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        MediaBtn {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            icon: "prev"
                            fore: root.textColor
                            back: root.withAlpha(root.textColor, 0.08)
                            onActivated: { mediaCmd.command = ["playerctl", "previous"]; mediaCmd.running = true }
                        }
                        MediaBtn {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 40
                            icon: root.mediaStatus === "Playing" ? "pause" : "play"
                            fore: root.textColor
                            back: root.primary
                            onActivated: { mediaCmd.command = ["playerctl", "play-pause"]; mediaCmd.running = true }
                        }
                        MediaBtn {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            icon: "next"
                            fore: root.textColor
                            back: root.withAlpha(root.textColor, 0.08)
                            onActivated: { mediaCmd.command = ["playerctl", "next"]; mediaCmd.running = true }
                        }
                    }
                }
            }

            property bool mediaClosing: false
            property real animProgress: 0

            Behavior on animProgress {
                NumberAnimation {
                    duration: mediaPopup.visible ? 280 : 220
                    easing.type: Easing.OutCubic
                }
            }

            function mediaOpen() {
                if (mediaClosing) return
                mediaPopup.visible = true
                mediaPopup.animProgress = 0
                Qt.callLater(() => mediaPopup.animProgress = 1)
            }
            function mediaClose() {
                if (mediaClosing) return
                mediaClosing = true
                mediaPopup.animProgress = 0
            }
            function mediaForceClose() {
                mediaPopup.visible = false
                mediaPopup.mediaClosing = false
                mediaPopup.animProgress = 0
            }

            onAnimProgressChanged: {
                if (mediaClosing && animProgress <= 0.01) {
                    mediaPopup.visible = false
                    mediaClosing = false
                }
            }

            anchor {
                item: mediaPill
                edges: Edges.Top
                gravity: Edges.Top
                adjustment: PopupAdjustment.All
                rect.x: 0
                rect.y: -14
                rect.w: mediaPill.width
                rect.h: mediaPill.height + 28
            }
            }

            // Wifi popup, opens above the network pill
            PopupWindow {
            id: wifiPopup
            visible: false
            grabFocus: true
            implicitWidth: 360
            implicitHeight: Math.min(wifiPopupBody.implicitHeight, 640) + 32
            color: "transparent"
            property bool wifiClosing: false
            property real animProgress: 0

            WifiPopup {
                id: wifiPopupBody
                anchors.fill: parent
                rootRef: root
                popupColor: root.colorOf("secondary_container")
                anchors.topMargin: wifiPopup.animProgress < 1 ? 16 * (1.0 - wifiPopup.animProgress) : 0
                opacity: wifiPopup.animProgress
                transform: Scale {
                    xScale: 0.92 + 0.08 * wifiPopup.animProgress
                    yScale: 0.92 + 0.08 * wifiPopup.animProgress
                }
            }

            Behavior on animProgress {
                NumberAnimation {
                    duration: wifiPopup.visible ? 280 : 220
                    easing.type: Easing.OutCubic
                }
            }

            function wifiOpen() {
                if (wifiClosing) return
                wifiPopup.visible = true
                wifiPopup.animProgress = 0
                wifiPopupBody.reloadNetworks()
                Qt.callLater(() => wifiPopup.animProgress = 1)
            }
            function wifiClose() {
                if (wifiClosing) return
                wifiClosing = true
                wifiPopup.animProgress = 0
            }
            function wifiForceClose() {
                wifiPopup.visible = false
                wifiPopup.wifiClosing = false
                wifiPopup.animProgress = 0
            }
            onAnimProgressChanged: {
                if (wifiClosing && animProgress <= 0.01) {
                    wifiPopup.visible = false
                    wifiClosing = false
                }
            }

            anchor {
                item: netPill
                edges: Edges.Top
                gravity: Edges.Top
                adjustment: PopupAdjustment.All
                rect.x: 0
                rect.y: -14
                rect.w: netPill.width
                rect.h: netPill.height + 28
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
                radius: 25
                }

            // Input only where content actually is, so the empty area of the
            // fixed-size window passes clicks through.
            mask: Region {
                Region { item: calPopupBody; radius: 25 }
                Region { item: timerSection }
            }

                property bool dismissedByOutside: false
                property bool closingBySelf: false
                property int shownYear: new Date().getFullYear()
                property int shownMonth: new Date().getMonth()

                // Date -> todo list, keyed by "YYYY-MM-DD". Each entry is
                // { id, text, saved, done }. Reassigned on every change
                // (never mutated in place) so day-delegate bindings refresh.
                property var notes: ({})
                property string selectedKey: ""

                // Todo entries of the currently selected date.
                property var entries: []
                property int selectedEntryId: -1
                property int newEntryId: -1
                property int entrySeq: 0

                readonly property int editorHeight: 164

                // Whether the todo list section is expanded (animated).
                property bool expanded: false

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
                    timerSection.playCloseAnim()
                    calPopup.animProgress = 0
                }

                // Immediate close (no animation) used when switching to the
                // media popup, so the two never overlap or double-close.
                function forceClose() {
                    calPopup.closingBySelf = true
                    calPopup.visible = false
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
                    // Clicking the selected date again collapses the todo list.
                    if (calPopup.selectedKey === key && calPopup.expanded) {
                        calPopup.expanded = false
                        return
                    }
                    console.log("[cal] selectDay key=" + key)
                    calPopup.selectedKey = key
                    calPopup.selectedEntryId = -1
                    calPopup.newEntryId = -1
                    calPopup.entries = calPopup.toEntryList(calPopup.notes[key])
                    calPopup.syncNotes()
                    calPopup.expanded = true
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

                // Window is a FIXED full size: resizing a Wayland surface per
                // frame is laggy, so the body animates inside this constant
                // surface and the timer section rides below it.
                readonly property int collapsedHeight: 312
                readonly property int timerGap: 8
                readonly property int timerHeight: 64
                implicitHeight: collapsedHeight + calPopup.editorHeight + 6
                    + calPopup.timerGap + calPopup.timerHeight

                property real animProgress: 0

                Behavior on animProgress {
                    NumberAnimation {
                        duration: calPopup.visible ? 280 : 220
                        easing.type: Easing.OutCubic
                    }
                }

                onAnimProgressChanged: {
                    if (animProgress <= 0.01 && calPopup.closingBySelf) {
                        calPopup.visible = false
                        calPopup.closingBySelf = false
                        calPopup.dismissedByOutside = false
                        calPopup.expanded = false
                        calPopup.selectedKey = ""
                        calPopup.selectedEntryId = -1
                        calPopup.newEntryId = -1
                        calPopup.entries = []
                        entriesModel.clear()
                    }
                }

                onVisibleChanged: {
                    if (visible) {
                        calPopup.rebuildModel()
                        calPopup.animProgress = 0
                        Qt.callLater(() => calPopup.animProgress = 1)
                        timerBody.opacity = 0
                        timerPopupIn.restart()
                    } else {
                        calPopup.dismissedByOutside = !calPopup.closingBySelf
                        calPopup.closingBySelf = false
                        calPopup.expanded = false
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
                    rect.y: -14
                    rect.w: clockPill.width
                    rect.h: clockPill.height + 28
                }

                Rectangle {
                    id: calPopupBody
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: calPopup.expanded ? parent.height : calPopup.collapsedHeight
                    anchors.topMargin: calPopup.animProgress < 1 ? 16 * (1.0 - calPopup.animProgress) : 0

                    Behavior on height {
                        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                    }

                    radius: 25
                    color: root.colorOf("secondary_fixed")
                    border.width: 1
                    border.color: root.withAlpha(root.outlineVariant, 0.35)
                    clip: true
                    opacity: calPopup.animProgress
                    scale: 0.92 + (0.08 * calPopup.animProgress)
                    transformOrigin: Item.Top

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

                            Item { Layout.fillWidth: true }

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
                            Layout.preferredHeight: 22
                            Layout.bottomMargin: 16
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰥔"
                                color: root.textColor
                                font.family: root.iconFont
                                font.pixelSize: root.fontSize + 3
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")
                                color: root.textColor
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize + 2
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
                                    color: root.textColor
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
                                            ? root.textColor
                                            : dayHover.containsMouse
                                                ? root.withAlpha(root.textColor, 0.18)
                                                : isToday ? root.withAlpha(root.textColor, 0.4) : "transparent"

                                        Text {
                                            id: dayNum
                                            anchors.centerIn: parent
                                            visible: day > 0
                                            text: day
                                            color: isSelected ? "#ffffff" : root.textColor
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
                                            color: isSelected ? "#ffffff" : root.textColor
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
                                    color: root.textColor
                                    font.family: root.iconFont
                                    font.pixelSize: root.fontSize + 1
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: calPopup.selectedDateLabel()
                                    color: root.textColor
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: Font.Black
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
                                    color: root.textColor
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 2
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: "󰅖"
                                    color: root.textColor
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
                                        ? root.withAlpha(root.textColor, 0.35)
                                        : root.withAlpha(root.textColor, 0.22)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: root.textColor
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
                                    color: root.textColor
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
                                            required property bool entryDone

                                            readonly property bool isSelected: calPopup.selectedEntryId === entryId

                                            width: entriesCol.width
                                            height: 30
                                            radius: 8
                                            color: root.withAlpha(root.textColor, saved ? 0.05 : 0.08)
                    border.width: 0
                                            border.color: isSelected
                                                ? root.textColor
                                                : saved ? "transparent" : root.withAlpha(root.textColor, 0.15)

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
                                                    radius: 5
                                                    color: entryDone
                                                        ? (todoCheckArea.containsMouse ? root.withAlpha(root.textColor, 0.8) : root.textColor)
                                                        : (todoCheckArea.containsMouse ? root.withAlpha(root.textColor, 0.08) : "transparent")
                                                    border.width: 1
                                                    border.color: entryDone ? root.textColor : root.withAlpha(root.textColor, 0.35)

                                                    Behavior on color { ColorAnimation { duration: 120 } }

                                                    Text {
                                                        visible: entryDone
                                                        anchors.centerIn: parent
                                                        text: "󰄲"
                                                        color: "#ffffff"
                                                        font.family: root.iconFont
                                                        font.pixelSize: root.fontSize - 2
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

                                                TextField {
                                                    id: entryInput
                                                    visible: !saved
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    text: entryText
                                                    color: root.textColor
                                                    font.family: root.uiFont
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
                                                    color: root.textColor
                                                    font.family: root.uiFont
                                                    font.pixelSize: root.fontSize
                                                    font.strikeout: entryDone
                                                    elide: Text.ElideRight
                                                    verticalAlignment: Text.AlignVCenter
                                                }

                                                Rectangle {
                                                    visible: !saved
                                                    Layout.preferredWidth: 22
                                                    Layout.preferredHeight: 22
                                                    radius: 6
                                                    color: saveHover.containsMouse ? root.withAlpha(root.textColor, 0.25) : "transparent"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰄴"
                                                        color: root.textColor
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

                            }
                        }
                    }
                }

                // Timer section — lives in the same window as the calendar so
                // it just rides along with the animated body height (no second
                // Wayland surface being repositioned every frame).
                Item {
                    id: timerSection
                    anchors.top: calPopupBody.bottom
                    anchors.topMargin: calPopup.timerGap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: calPopup.timerHeight

                    ParallelAnimation {
                        id: timerPopupIn
                        running: false
                        NumberAnimation { target: timerBody; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutQuad }
                    }

                    SequentialAnimation {
                        id: timerPopupOut
                        running: false
                        ParallelAnimation {
                            NumberAnimation { target: timerBody; property: "opacity"; to: 0; duration: 100; easing.type: Easing.InQuad }
                        }
                    }

                    function playCloseAnim() {
                        timerPopupIn.stop()
                        timerPopupOut.restart()
                    }

                    Rectangle {
                        id: timerBody
                        anchors.fill: parent
                        radius: 25
                        color: root.colorOf("secondary_fixed")
                        border.width: 1
                        border.color: root.withAlpha(root.outlineVariant, 0.35)
                        opacity: 0

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                spacing: 6

                                Text {
                                    text: "󰄉"
                                    color: root.textColor
                                    font.family: root.iconFont
                                    font.pixelSize: root.fontSize + 2
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 40
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: root.fmtTimer(root.timerRemainingMs)
                                    color: root.timerRemainingMs <= 0 ? root.error : root.textColor
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize + 8
                                    font.weight: Font.Black
                                    Layout.fillWidth: true
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Rectangle {
                                    id: timerMinusBtn
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 7
                                    color: timerMinusHover.containsMouse
                                        ? root.withAlpha(root.textColor, 0.35)
                                        : root.withAlpha(root.textColor, 0.18)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "-"
                                        color: root.textColor
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 2
                                        font.weight: Font.Black
                                    }

                                    MouseArea {
                                        id: timerMinusHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.adjustTimerMinutes(-5)
                                    }
                                }

                                Rectangle {
                                    id: timerPlusBtn
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 7
                                    color: timerPlusHover.containsMouse
                                        ? root.withAlpha(root.textColor, 0.35)
                                        : root.withAlpha(root.textColor, 0.18)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: root.textColor
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 2
                                        font.weight: Font.Black
                                    }

                                    MouseArea {
                                        id: timerPlusHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.adjustTimerMinutes(5)
                                    }
                                }

                                Rectangle {
                                    id: timerToggleBtn
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 26
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 7
                                    color: timerToggleHover.containsMouse
                                        ? root.withAlpha(root.textColor, 0.45)
                                        : root.withAlpha(root.textColor, 0.28)

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.timerRunning ? "󰏤" : "󰐊"
                                        color: root.textColor
                                        font.family: root.iconFont
                                        font.pixelSize: root.fontSize + 2
                                    }

                                    MouseArea {
                                        id: timerToggleHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleTimer()
                                    }
                                }

                                Rectangle {
                                    id: timerResetBtn
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 7
                                    color: timerResetHover.containsMouse
                                        ? root.withAlpha(root.error, 0.35)
                                        : root.withAlpha(root.textColor, 0.08)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰃢"
                                        color: root.error
                                        font.family: root.iconFont
                                        font.pixelSize: root.fontSize
                                    }

                                    MouseArea {
                                        id: timerResetHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.resetTimer()
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

