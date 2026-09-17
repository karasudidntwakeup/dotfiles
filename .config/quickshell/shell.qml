import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "components"

ShellRoot {
    id: root

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

    readonly property color qsPillFg: "#ffffff"
    readonly property color qsPillFallbackBg: "#1a1b1e"

    function pillColor(name) {
        if (!root.qsLight) return colorOf(name)
        var v = colorFile.paletteMap[name + "_light"]
        return v === undefined ? root.qsPillFallbackBg : v
    }

    function tonalPillColor(accent) {
        var color = Qt.color(accent)
        var lightness = root.qsLight
            ? Math.min(color.hslLightness, 0.24)
            : Math.max(color.hslLightness, 0.76)
        return Qt.hsla(Math.max(0, color.hslHue), color.hslSaturation, lightness, 1)
    }

    function pillForeground(background) {
        var linear = value => value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
        var light = 0.2126 * linear(background.r) + 0.7152 * linear(background.g) + 0.0722 * linear(background.b)
        return light > 0.179 ? "#000000" : "#ffffff"
    }

    function popupSurface(name) {
        var v = colorFile.paletteMap[name + "_light"]
        return v === undefined ? colorOf(name) : v
    }

    readonly property color primary: colorOf("primary")
    readonly property color error: colorOf("error")
    readonly property color outlineVariant: colorOf("outline_variant")

    readonly property string fontFamily: "Geist"
    readonly property string uiFont: "Geist"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int fontSize: 13

    readonly property int barHeight: 35
    readonly property int pillHeight: 35
    readonly property int pillRadius: 10
    readonly property int groupSpacing: 8

    readonly property color textColor: root.qsLight ? root.qsPillFg : "#000000"
    readonly property color onTextColor: root.qsLight ? "#000000" : "#ffffff"
    readonly property color darkText: colorOf("shadow")

    readonly property string terminalCommand: "kitty"

    function luminance(color) {
        return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
    }

    function withAlpha(color, a) {
        return Qt.rgba(color.r, color.g, color.b, a)
    }

    function mixColor(c1, c2, t) {
        var a = Qt.color(c1)
        var b = Qt.color(c2)
        t = Math.max(0, Math.min(1, t))
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }

    function memTint(p) {
        var g = root.pillColor("secondary_fixed_dim")
        var a = root.pillColor("secondary_container")
        var r = root.pillColor("error")
        if (p <= 50) return root.mixColor(g, a, p / 50)
        return root.mixColor(a, r, (p - 50) / 50)
    }

    function volTint() {
        if (root.muted) return root.pillColor("error")
        return root.mixColor(root.pillColor("secondary_container"),
                             root.pillColor("secondary_fixed_dim"),
                             root.volumePercent / 100)
    }

    property string weatherText: ""
    property string weatherKey: "cloud"
    property string prayerText: ""
    property string prayerName: ""
    property date prayerTarget: new Date(0)
    property bool prayerAlerted: false

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
    property int memPercent: 0

    Process {
        id: weatherProc
        command: ["sh", "-c", "~/.config/waybar/scripts/weather.sh"]
        stdout: SplitParser {
            onRead: data => {
                var t = data ? data.trim() : ""
                if (t && !/error|unavailable|failed|not available|⚠|N\/A/i.test(t)) {
                    var parts = t.split("|")
                    if (parts.length === 2 && parts[1].trim().length > 0) {
                        weatherKey = parts[0].trim()
                        weatherText = parts[1].trim()
                    } else {
                        weatherKey = "cloud"
                        weatherText = ""
                    }
                } else {
                    weatherKey = "cloud"
                    weatherText = ""
                }
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
                prayerAlerted = false
                updatePrayerCountdown()
            }
        }
        onExited: code => { if (code !== 0) { prayerText = ""; prayerName = "" } }
    }

    Process {
        id: memProc
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/mem.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split("|")
                var used = parts[0] || ""
                root.memText = used ? used + "MB" : ""
                root.memPercent = parseInt(parts[1] || "0", 10) || 0
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
        id: prayerAlertTimer
        interval: 30000
        running: root.prayerName.length > 0 && !root.prayerAlerted
        repeat: true
        onTriggered: {
            if (root.prayerTarget.getTime() - Date.now() > 0)
                return
            root.prayerAlerted = true
            Quickshell.execDetached(["sh", "-c",
                "paplay ~/.local/share/sounds/bell.oga &\n" +
                "notify-send -u critical -i appointment-soon -t 15000 '" + root.prayerName + "' 'It is time for " + root.prayerName + " 󰦕'"])
            prayerProc.running = true
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: memProc.running = true
    }

    property int volumePercent: 0
    property bool muted: false
    readonly property string volumeIcon: muted ? "󰝟" : (volumePercent <= 33 ? "󰕿" : volumePercent <= 66 ? "󰖀" : "󰕾")

    Process {
        id: volProc
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/volume.sh"]
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

    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercent: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: battery && (battery.state === UPowerDeviceState.Charging
        || battery.state === UPowerDeviceState.FullyCharged
        || battery.state === UPowerDeviceState.PendingCharge)

    function shortLayout(name) {
        if (name.indexOf("Arabic") >= 0) return "AR"
        if (name.indexOf("English") >= 0) return "US"
        return name
    }

    property string networkText: ""
    property string networkIp: ""
    property bool networkConnected: false
    property int networkSignal: 0
    property int networkDown: 0

    function formatSpeed(bytesPerSec) {
        var b = bytesPerSec || 0
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s"
        return Math.round(b / 1024) + " KB/s"
    }

    function signalTint(sig) {
        var s = sig || 0
        if (s >= 85) return root.pillColor("secondary")
        if (s >= 65) return root.pillColor("tertiary")
        if (s >= 45) return root.pillColor("primary_fixed")
        if (s >= 30) return root.pillColor("secondary_container")
        if (s >= 15) return root.pillColor("tertiary_container")
        return root.pillColor("error")
    }

    function batteryTint(p) {
        if (root.charging) return root.pillColor("primary_fixed")
        if (p >= 80) return root.pillColor("primary")
        if (p >= 50) return root.pillColor("primary_fixed")
        if (p >= 30) return root.pillColor("tertiary")
        if (p >= 15) return root.pillColor("secondary_container")
        return root.pillColor("error")
    }

    Process {
        id: netProc
        command: ["sh", "-c", "sh " + Quickshell.shellDir + "/scripts/wifi.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    try {
                        var d = JSON.parse(data.trim())
                        root.networkConnected = d.connected === true
                        root.networkText = d.ssid || ""
                        root.networkIp = d.ip || ""
                        root.networkSignal = parseInt(d.signal) || 0
                        root.networkDown = parseInt(d.down) || 0
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

    property string bluetoothText: ""
    property string bluetoothStatus: "off"

    Process {
        id: btProc
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/bluetooth.sh"]
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

    property string mediaStatus: "none"
    property real mediaPosMs: 0
    property real mediaLenMs: 0
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaArt: ""
    property string mediaInfo: ""
    property string mediaSig: ""

    Process {
        id: mediaProc
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/media.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var fields = data.trim().split("|")
                if (fields[0]) root.mediaStatus = fields[0]

                var n = fields.length
                var pos = (parseFloat(fields[n - 3]) || 0) / 1000
                var len = parseFloat(fields[n - 2]) / 1000
                var art = fields[n - 1] || ""
                var info = fields.slice(1, n - 3).join("|")

                var title = ""
                var artist = ""
                var sep = info.indexOf("\u001E")
                if (sep >= 0) {
                    artist = info.substring(0, sep).trim()
                    title = info.substring(sep + 1).trim()
                } else {
                    title = info.trim()
                }

                var sig = info + "\u001E" + art
                var trackChanged = sig !== root.mediaSig
                if (trackChanged) {
                    root.mediaSig = sig
                    root.mediaTitle = title
                    root.mediaArtist = artist
                    root.mediaInfo = title + "|" + artist
                    root.mediaArt = art
                }

                root.mediaLenMs =
                    (isFinite(len) && len > 0) ? len
                    : (!trackChanged && root.mediaLenMs > 0) ? root.mediaLenMs
                    : 0

                root.mediaPosMs =
                    trackChanged ? pos
                    : root.mediaStatus === "Playing" ? Math.max(root.mediaPosMs, pos)
                    : pos
            }
        }
    }

    Timer {
        id: mediaSync
        interval: 2000
        running: true
        repeat: true
        onTriggered: mediaProc.running = true
    }

    Timer {
        id: mediaTicker
        interval: 100
        running: root.mediaStatus === "Playing"
        repeat: true
        onTriggered: {
            if (root.mediaStatus === "Playing")
                root.mediaPosMs = Math.min(root.mediaPosMs + 100, root.mediaLenMs)
        }
        onRunningChanged: {

            if (running) mediaProc.running = true
        }
    }

    property var calRegistry: ({})

    function registerCalendarAnchor(outputName, anchor, screen, win) {
        if (!root.calRegistry[outputName]) root.calRegistry[outputName] = {}
        root.calRegistry[outputName].anchor = anchor
        root.calRegistry[outputName].screen = screen
        root.calRegistry[outputName].win = win
    }

    function openCalendarForOutput(outputName) {
        var entry = root.calRegistry[outputName]
        if (!entry) return
        calPopup.anchorItem = entry.anchor || null
        calPopup.anchorScreen = entry.screen || null
        calPopup.anchorWin = entry.win || null
        if (entry.screen) calPopup.screen = entry.screen
        calPopup.open()
    }

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

    Process {
        id: awwwProc
        command: ["awww-daemon"]
        running: true
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"])
        weatherProc.running = true
        prayerProc.running = true
        memProc.running = true
        netProc.running = true
        btProc.running = true
        mediaProc.running = true
    }

    component NiriIpc: Item {
        id: niri

        readonly property string socketPath: (function() {
            var p = Quickshell.env("NIRI_SOCKET")
            if (p) return p
            var rt = Quickshell.env("XDG_RUNTIME_DIR")
            var wd = Quickshell.env("WAYLAND_DISPLAY")
            return rt && wd ? rt + "/niri-ipc-" + wd + ".sock" : ""
        })()

        property var layoutNames: []
        property int layoutIdx: -1
        property string keyboardLayoutName: ""

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

    component Module: Rectangle {
        id: pill
        property string label: ""
        property string icon: ""
        property Component iconSource: null
        property int padX: 20
        property int rowSpacing: 4
        property bool rowClip: false
        property int iconSize: root.fontSize + 5
        property color tint: root.primary
        property alias clickArea: pillArea
        property alias wheelArea: pillArea

        readonly property color pillTextColor: root.pillForeground(pill.color)

        implicitWidth: pillRow.implicitWidth + pill.padX
        implicitHeight: root.pillHeight
        radius: root.pillRadius
        color: root.tonalPillColor(tint)
        border.width: 0

        Behavior on color { ColorAnimation { duration: 250 } }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: pill.rowSpacing
            clip: pill.rowClip

            Loader {
                visible: pill.iconSource != null
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: pill.iconSource
            }

            Text {
                id: pillIcon
                visible: pill.icon.length > 0
                text: pill.icon
                color: pill.pillTextColor
                Layout.alignment: Qt.AlignVCenter
                font.family: root.iconFont
                font.pixelSize: pill.iconSize
                font.weight: Font.Normal
            }

            Text {
                id: pillText
                text: pill.label
                color: pill.pillTextColor
                Layout.alignment: Qt.AlignVCenter
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.weight: Font.Normal
            }
        }

        MouseArea {
            id: pillArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }

        scale: pillArea.containsMouse ? 1.05 : 1.0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    }

    component BoltGlyph: Canvas {
        id: boltG
        property color tintColor: root.primary
        anchors.centerIn: parent
        width: 14
        height: 18

        onTintColorChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.scale(boltG.width / 12, boltG.height / 16)
            ctx.fillStyle = boltG.tintColor
            ctx.beginPath()
            ctx.moveTo(7.5, 0)
            ctx.lineTo(2.3, 9.2)
            ctx.lineTo(5.8, 9.2)
            ctx.lineTo(4.5, 16)
            ctx.lineTo(10, 6)
            ctx.lineTo(6.4, 6)
            ctx.closePath()
            ctx.fill()
        }
    }

    component DynamicPill: Rectangle {
        id: dc
        property int padX: 14
        property int iconSize: root.fontSize + 2
        readonly property color tint: root.networkConnected ? root.signalTint(root.networkSignal) : root.pillColor("error")
        readonly property color pillTextColor: root.pillForeground(dc.color)
        readonly property bool hovering: dcArea.containsMouse || dcArea.pressed

        implicitHeight: root.pillHeight
        radius: root.pillRadius
        color: root.tonalPillColor(dc.tint)
        border.width: 0

        implicitWidth: dcRow.implicitWidth + dc.padX
        Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
        Behavior on color { ColorAnimation { duration: 250 } }

        scale: dcArea.containsMouse ? 1.05 : 1.0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        Row {
            id: dcRow
            anchors.centerIn: parent
            spacing: 8

            Item {
                id: arcSlot
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 40
                implicitHeight: root.pillHeight

                Canvas {
                    id: arcC
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    antialiasing: true
                    property int percent: root.batteryPercent
                    property bool charging: root.charging
                    property color base: dc.pillTextColor

                    onPercentChanged: requestPaint()
                    onChargingChanged: requestPaint()
                    onBaseChanged: requestPaint()

                    onPaint: {
                        var ctx = arcC.getContext("2d")
                        ctx.reset()
                        var w = arcC.width
                        var h = arcC.height
                        if (w <= 0 || h <= 0) return
                        var cx = w / 2
                        var cy = h / 2
                        var r = 13.5
                        var gapRad = Math.PI / 4
                        var maxSweep = 2 * Math.PI - 2 * gapRad
                        var capInset = (ctx.lineWidth / 2) / r
                        var sweepMax = maxSweep - 2 * capInset
                        var frac = Math.max(0, Math.min(1, arcC.percent / 100))
                        var start = Math.PI / 2 + gapRad + capInset

                        ctx.lineCap = "round"
                        ctx.lineWidth = 3
                        ctx.strokeStyle = Qt.rgba(arcC.base.r, arcC.base.g, arcC.base.b, 0.13)
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, start, start + sweepMax)
                        ctx.stroke()

                        ctx.strokeStyle = arcC.base
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, start, start + sweepMax * frac)
                        ctx.stroke()

                        if (arcC.charging) {
                            var bc = arcC.base
                            ctx.fillStyle = Qt.rgba(bc.r, bc.g, bc.b, 1)
                            ctx.beginPath()
                            ctx.arc(cx - 3, cy + 10.5, 1.6, 0, Math.PI * 2)
                            ctx.fill()
                            ctx.beginPath()
                            ctx.arc(cx + 3, cy + 10.5, 1.6, 0, Math.PI * 2)
                            ctx.fill()
                        }

                        var gy = cy + 4
                        ctx.fillStyle = arcC.base
                        ctx.strokeStyle = arcC.base
                        ctx.lineWidth = 2
                        for (var i = 0; i < 3; i++) {
                            ctx.beginPath()
                            ctx.arc(cx, gy, 3 + i * 3.15, Math.PI * 1.25, Math.PI * 1.75)
                            ctx.stroke()
                        }
                        ctx.beginPath()
                        ctx.arc(cx, gy, 1.8, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }

            Text {
                id: infoText
                anchors.verticalCenter: parent.verticalCenter
                text: root.networkConnected ? (root.networkIp + "  ↓  " + root.formatSpeed(root.networkDown) || root.networkText) : "No net"
                color: dc.pillTextColor
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.weight: Font.Normal
            }
        }

        Rectangle {
            id: tip
            anchors.left: dc.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: tipText.implicitWidth + 14
            height: 22
            radius: 11
            color: "#0b0b0e"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            opacity: dc.hovering ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

            Text {
                id: tipText
                anchors.centerIn: parent
                text: root.charging ? "CHARGING" : root.batteryPercent + "%"
                color: !root.charging && root.batteryPercent < 15 ? root.pillColor("error") : "#ffffff"
                font.family: root.fontFamily
                font.pixelSize: root.fontSize - 1
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: dcArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }
    }
    component WifiIcon: Canvas {
        id: wifi
        property color tint: "#ffffff"
        implicitWidth: 22
        implicitHeight: 17

        onTintChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = wifi.tint
            ctx.fillStyle = wifi.tint
            ctx.lineCap = "round"
            var cx = wifi.width / 2
            var baseY = wifi.height - 3
            for (var i = 0; i < 3; i++) {
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.arc(cx, baseY, 3 + i * 3.2, Math.PI * 1.25, Math.PI * 1.75, false)
                ctx.stroke()
            }
            ctx.beginPath()
            ctx.arc(cx, wifi.height - 4, 1.7, 0, Math.PI * 2)
            ctx.fill()
        }
    }

    component VolumeIcon: Canvas {
        id: v
        property color tint: "#ffffff"
        property bool muted: false
        property int percent: 50
        implicitWidth: 18
        implicitHeight: 18

        onTintChanged: requestPaint()
        onMutedChanged: requestPaint()
        onPercentChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.scale(v.width / 24, v.height / 24)
            ctx.strokeStyle = v.tint
            ctx.fillStyle = v.tint
            ctx.lineWidth = 2
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            ctx.beginPath()
            ctx.moveTo(11, 5)
            ctx.lineTo(6, 9)
            ctx.lineTo(2, 9)
            ctx.lineTo(2, 15)
            ctx.lineTo(6, 15)
            ctx.lineTo(11, 19)
            ctx.closePath()
            ctx.stroke()

            if (v.muted) {
                ctx.beginPath()
                ctx.moveTo(16, 9)
                ctx.lineTo(22, 15)
                ctx.moveTo(22, 9)
                ctx.lineTo(16, 15)
                ctx.stroke()
            } else {
                var arcs = v.percent > 66 ? 2 : v.percent > 0 ? 1 : 0
                for (var i = 0; i < arcs; i++) {
                    ctx.beginPath()
                    ctx.arc(12, 12, 5 + i * 5, -Math.PI / 4, Math.PI / 4, false)
                    ctx.stroke()
                }
            }
        }
    }

    component BluetoothIcon: Canvas {
        id: bt
        property color tint: "#ffffff"
        implicitWidth: 18
        implicitHeight: 18

        onTintChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.save()
            ctx.scale(bt.width / 24, bt.height / 24)
            ctx.fillStyle = bt.tint

            ctx.beginPath()
            ctx.moveTo(17.71, 7.71)
            ctx.lineTo(12, 2)
            ctx.lineTo(11, 2)
            ctx.lineTo(11, 9.59)
            ctx.lineTo(6.41, 5)
            ctx.lineTo(5, 6.41)
            ctx.lineTo(10.59, 12)
            ctx.lineTo(5, 17.59)
            ctx.lineTo(6.41, 19)
            ctx.lineTo(11, 14.41)
            ctx.lineTo(11, 22)
            ctx.lineTo(12, 22)
            ctx.lineTo(17.71, 16.29)
            ctx.lineTo(13.41, 12)
            ctx.lineTo(17.71, 7.71)
            ctx.closePath()

            ctx.moveTo(13, 5.83)
            ctx.lineTo(14.88, 7.71)
            ctx.lineTo(13, 9.59)
            ctx.closePath()

            ctx.moveTo(13, 18.17)
            ctx.lineTo(11.12, 16.29)
            ctx.lineTo(13, 14.41)
            ctx.closePath()

            ctx.fill()
            ctx.restore()
        }
    }

    component MemoryIcon: Canvas {
        id: m
        property color tint: "#ffffff"
        implicitWidth: 20
        implicitHeight: 20

        onTintChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = m.tint
            ctx.fillStyle = m.tint
            ctx.lineWidth = 1.6

            var x = 5, y = 6, w = 10, hh = 8
            for (var i = 0; i < 3; i++) {
                var px = x + 2 + i * 3
                ctx.fillRect(px, y - 2.2, 1.8, 2.2)
                ctx.fillRect(px, y + hh, 1.8, 2.2)
            }
            for (var j = 0; j < 2; j++) {
                var py = y + 2 + j * 3
                ctx.fillRect(x - 2.2, py, 2.2, 1.8)
                ctx.fillRect(x + w, py, 2.2, 1.8)
            }

            ctx.beginPath()
            var r = 2.5
            ctx.moveTo(x + r, y)
            ctx.arcTo(x + w, y, x + w, y + hh, r)
            ctx.arcTo(x + w, y + hh, x, y + hh, r)
            ctx.arcTo(x, y + hh, x, y, r)
            ctx.arcTo(x, y, x + w, y, r)
            ctx.closePath()
            ctx.stroke()
        }
    }

    component ClockIcon: Canvas {
        id: cl
        property color tint: "#ffffff"
        implicitWidth: 19
        implicitHeight: 19

        onTintChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var c = cl.width / 2
            ctx.strokeStyle = cl.tint
            ctx.fillStyle = cl.tint
            ctx.lineCap = "round"

            ctx.lineWidth = 1.6
            ctx.beginPath()
            ctx.arc(c, c, 7.4, 0, Math.PI * 2)
            ctx.stroke()

            ctx.lineWidth = 2.4
            ctx.beginPath()
            ctx.moveTo(c, c)
            ctx.lineTo(c, c - 4)
            ctx.stroke()

            ctx.lineWidth = 2.4
            ctx.beginPath()
            ctx.moveTo(c, c)
            ctx.lineTo(c + 3.2, c - 3.2)
            ctx.stroke()

            ctx.lineWidth = 1.1
            for (var i = 0; i < 4; i++) {
                var a = i * Math.PI / 2 - Math.PI / 2
                ctx.beginPath()
                ctx.moveTo(c + Math.cos(a) * 5.6, c + Math.sin(a) * 5.6)
                ctx.lineTo(c + Math.cos(a) * 6.9, c + Math.sin(a) * 6.9)
                ctx.stroke()
            }

            ctx.beginPath()
            ctx.arc(c, c, 1.5, 0, Math.PI * 2)
            ctx.fill()
        }
    }

    component WeatherIcon: Canvas {
        id: wi
        property color tint: "#ffffff"
        property string variant: "cloud"
        implicitWidth: 26
        implicitHeight: 22

        onTintChanged: requestPaint()
        onVariantChanged: requestPaint()

        function cloud(ctx, cx, cy, s) {
            ctx.beginPath()
            ctx.arc(cx - s * 0.55, cy - s * 0.1, s * 0.4, 0, Math.PI * 2)
            ctx.arc(cx, cy - s * 0.32, s * 0.48, 0, Math.PI * 2)
            ctx.arc(cx + s * 0.55, cy - s * 0.1, s * 0.4, 0, Math.PI * 2)
            ctx.fill()
            ctx.fillRect(cx - s * 0.55, cy - s * 0.15, s * 1.1, s * 0.55)
        }

        function sun(ctx, cx, cy, r) {
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.fill()
            ctx.strokeStyle = wi.tint
            ctx.lineCap = "round"
            ctx.lineWidth = 1.5
            for (var i = 0; i < 8; i++) {
                var a = i * Math.PI / 4
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(a) * (r + 2.2), cy + Math.sin(a) * (r + 2.2))
                ctx.lineTo(cx + Math.cos(a) * (r + 3.6), cy + Math.sin(a) * (r + 3.6))
                ctx.stroke()
            }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = wi.tint
            ctx.fillStyle = wi.tint
            ctx.lineCap = "round"

            if (wi.variant === "sun") {
                wi.sun(ctx, wi.width / 2, wi.height / 2 - 1, 3.4)
            } else if (wi.variant === "partly") {
                wi.sun(ctx, 9, 6, 2.6)
                wi.cloud(ctx, 16, 13, 5)
            } else if (wi.variant === "rain" || wi.variant === "snow" || wi.variant === "storm" || wi.variant === "fog") {
                wi.cloud(ctx, 13, 8, 6)
                if (wi.variant === "rain") {
                    ctx.lineWidth = 1.6
                    for (var i = 0; i < 3; i++) {
                        var x = 13 - 3.6 + i * 3.6
                        ctx.beginPath()
                        ctx.moveTo(x, 12.5)
                        ctx.lineTo(x - 1.3, 15.2)
                        ctx.stroke()
                    }
                } else if (wi.variant === "snow") {
                    ctx.lineWidth = 1.4
                    for (var j = 0; j < 3; j++) {
                        var sx = 13 - 3.6 + j * 3.6
                        var sy = 14
                        ctx.beginPath()
                        ctx.moveTo(sx - 1.4, sy); ctx.lineTo(sx + 1.4, sy)
                        ctx.moveTo(sx, sy - 1.4); ctx.lineTo(sx, sy + 1.4)
                        ctx.stroke()
                    }
                } else if (wi.variant === "storm") {
                    ctx.beginPath()
                    ctx.moveTo(15.2, 11)
                    ctx.lineTo(11.6, 14.6)
                    ctx.lineTo(13, 14.6)
                    ctx.lineTo(10.8, 18.6)
                    ctx.lineTo(15.4, 13.4)
                    ctx.lineTo(13.9, 13.4)
                    ctx.closePath()
                    ctx.fill()
                } else {
                    ctx.lineWidth = 1.4
                    for (var k = 0; k < 3; k++) {
                        ctx.beginPath()
                        ctx.moveTo(6.5, 13 + k * 2)
                        ctx.lineTo(19.5, 13 + k * 2)
                        ctx.stroke()
                    }
                }
            } else {
                wi.cloud(ctx, 13, 11, 6)
            }
        }
    }

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
        readonly property real dotW: 11
        readonly property real activeW: 22
        readonly property real dotH: 10
        readonly property real dotSpacing: 4
        readonly property real pillPad: 6
        readonly property real dotRadius: 5
        readonly property color accent: root.pillColor("primary")

        function contentWidth() {
            return (count - 1) * dotW + activeW + dotSpacing * (count - 1)
        }

        width: contentWidth() + pillPad * 2
        height: root.pillHeight
        radius: root.pillRadius
        color: root.tonalPillColor(root.pillColor("primary_container"))
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
                            property bool hovered: false

                            width: focused ? wsWidget.activeW : wsWidget.dotW
                            height: wsWidget.dotH
                            anchors.verticalCenter: parent.verticalCenter
                            scale: hovered ? 1.1 : 1.0
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                            Rectangle {
                                anchors.fill: parent
                                radius: wsWidget.dotRadius
                                color: focused ? wsWidget.accent : root.pillForeground(wsWidget.color)
                                opacity: focused ? 1.0 : (occupied ? 0.5 : 0.18)
                                Behavior on color { ColorAnimation { duration: 250 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: {
                                    if (modelData) niriIpc.focusWorkspace(modelData.idx)
                                }
                            }
                        }
            }
        }

        function switchDelta(delta) {
            if (wsWidget.count === 0) return
            var i = wsWidget.activeIndex
            if (i < 0) i = 0
            var next = (i + delta + wsWidget.count) % wsWidget.count
            var ws = wsWidget.workspaces[next]
            if (ws && niriIpc) niriIpc.focusWorkspace(ws.idx)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: event => {
                wsWidget.switchDelta(event.angleDelta.y > 0 ? -1 : 1)
                event.accepted = true
            }
        }
    }

    property bool lockActive: false

    FileView {
        id: lockReq
        path: Quickshell.env("HOME") + "/.cache/quickshell/lock-request"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: lockReq.reload()
        onLoaded: {
            if (String(lockReq.text()).trim() === "lock") lockActive = true
        }
    }

    WlSessionLock {
        id: wLock
        locked: lockActive

        WlSessionLockSurface {
            color: "#000000"
            Item {
                anchors.fill: parent
                clip: true
                LockSurface {
                    id: passSurface
                    anchors.fill: parent
                    rootRef: root
                    locked: root.lockActive
                    onUnlocked: {
                        lockActive = false
                        Quickshell.execDetached(["sh", "-c", "rm -f '" + Quickshell.env("HOME") + "/.cache/quickshell/lock-request'"])
                    }
                }
            }
        }
    }

    function closeOverlays() {
        notifSvc.closeCenter()
        root.launcherActive = false
        root.ytxActive = false
        root.clipboardActive = false
        root.whatsappActive = false
        root.notesActive = false
        root.closeWallpaperPicker()
    }

    function openWallpaperPicker() {
        if (wallPicker.visible || openAnim.running) return
        root.closeOverlays()
        pickerContent.opacity = 0
        pickerContent.anchors.topMargin = -24
        pickerContent.anchors.bottomMargin = 24
        wallPicker.visible = true
        openAnim.start()
    }
    function closeWallpaperPicker() {
        if (!wallPicker.visible || closeAnim.running) return
        closeAnim.start()
    }
    function toggleWallpaperPicker() {
        if (wallPicker.visible) closeWallpaperPicker()
        else openWallpaperPicker()
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            root.toggleWallpaperPicker()
        }
    }

    property bool launcherActive: false

    function openAppLauncher() { root.closeOverlays(); root.launcherActive = true }
    function closeAppLauncher() { root.launcherActive = false }
    function toggleAppLauncher() {
        if (root.launcherActive) root.closeAppLauncher()
        else root.openAppLauncher()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            root.toggleAppLauncher()
        }
    }

    PanelWindow {
        id: appLauncherWin
        visible: root.launcherActive || appLauncherContent.animProgress > 0.001
        focusable: root.launcherActive
        color: "transparent"
        WlrLayershell.namespace: "app-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        AppLauncher {
            id: appLauncherContent
            anchors.fill: parent
            rootRef: root
            active: root.launcherActive
            onRequestClose: root.launcherActive = false
        }
    }

    property bool ytxActive: false

    function openYtx() { root.closeOverlays(); root.ytxActive = true }
    function closeYtx() { root.ytxActive = false }
    function toggleYtx() {
        if (root.ytxActive) root.closeYtx()
        else root.openYtx()
    }

    IpcHandler {
        target: "ytx"
        function toggle(): void {
            root.toggleYtx()
        }
    }

    PanelWindow {
        id: ytxWin
        visible: root.ytxActive || ytxContent.animProgress > 0.001
        focusable: root.ytxActive
        color: "transparent"
        WlrLayershell.namespace: "ytx-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        YtXLauncher {
            id: ytxContent
            anchors.fill: parent
            rootRef: root
            active: root.ytxActive
            onRequestClose: root.ytxActive = false
        }
    }

    property bool whatsappActive: false

    function openWhatsApp() { root.closeOverlays(); root.whatsappActive = true }
    function closeWhatsApp() { root.whatsappActive = false }
    function toggleWhatsApp() {
        if (root.whatsappActive) root.closeWhatsApp()
        else root.openWhatsApp()
    }

    IpcHandler {
        target: "whatsapp"
        function toggle(): void {
            root.toggleWhatsApp()
        }
    }

    PanelWindow {
        id: whatsappWin
        visible: root.whatsappActive || waContent.animProgress > 0.001
        focusable: root.whatsappActive
        color: "transparent"
        WlrLayershell.namespace: "whatsapp-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        WhatsApp {
            id: waContent
            anchors.fill: parent
            rootRef: root
            active: root.whatsappActive
            onRequestClose: root.whatsappActive = false
        }
    }

    property bool clipboardActive: false

    function openClipboard() { root.closeOverlays(); root.clipboardActive = true }
    function closeClipboard() { root.clipboardActive = false }
    function toggleClipboard() {
        if (root.clipboardActive) root.closeClipboard()
        else root.openClipboard()
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            root.toggleClipboard()
        }
    }

    PanelWindow {
        id: clipWin
        visible: root.clipboardActive || clipContent.animProgress > 0.001
        focusable: root.clipboardActive
        color: "transparent"
        WlrLayershell.namespace: "clipboard-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Clipboard {
            id: clipContent
            anchors.fill: parent
            rootRef: root
            active: root.clipboardActive
            onRequestClose: root.clipboardActive = false
        }
    }

    property bool notesActive: false

    function openNotes() { root.closeOverlays(); root.notesActive = true }
    function closeNotes() { root.notesActive = false }
    function toggleNotes() {
        if (root.notesActive) root.closeNotes()
        else root.openNotes()
    }

    IpcHandler {
        target: "notes"
        function toggle(): void {
            root.toggleNotes()
        }
    }

    PanelWindow {
        id: notesWin
        visible: root.notesActive || notesContent.animProgress > 0.001
        focusable: root.notesActive
        color: "transparent"
        WlrLayershell.namespace: "notes-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Notes {
            id: notesContent
            anchors.fill: parent
            rootRef: root
            active: root.notesActive
            onRequestClose: root.notesActive = false
        }
    }

    PanelWindow {
        id: wallPicker
        visible: false
        focusable: true
        color: "transparent"
        WlrLayershell.namespace: "wallpaper-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        WallpaperPicker {
            id: pickerContent
            anchors.fill: parent
            currentMode: root.qsLight ? "light" : "dark"

            surfaceColor: "#17181c"
            borderColor: Qt.color(root.colorOf("outline_variant"))
            fgColor: "#ffffff"
            accentColor: Qt.color(root.colorOf("primary"))
            iconFont: root.iconFont
            uiFont: root.uiFont
            onRequestClose: root.closeWallpaperPicker()
        }

        onVisibleChanged: {
            pickerContent.visible_ = visible
            if (visible) {
                pickerContent.triggerIndexer()
            }
        }
    }

    SequentialAnimation {
        id: openAnim
        running: false
        ParallelAnimation {
            NumberAnimation {
                target: pickerContent
                property: "opacity"
                from: 0
                to: 1
                duration: 240
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pickerContent
                property: "anchors.topMargin"
                from: -24
                to: 0
                duration: 240
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pickerContent
                property: "anchors.bottomMargin"
                from: 24
                to: 0
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: closeAnim
        running: false
        ParallelAnimation {
            NumberAnimation {
                target: pickerContent
                property: "opacity"
                to: 0
                duration: 220
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pickerContent
                property: "anchors.topMargin"
                to: 24
                duration: 220
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pickerContent
                property: "anchors.bottomMargin"
                to: -24
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        ScriptAction {
            script: {
                wallPicker.visible = false
                pickerContent.anchors.topMargin = 0
                pickerContent.anchors.bottomMargin = 0
                pickerContent.opacity = 1
            }
        }
    }

    NotificationService {
        id: notifSvc
    }

    NotifPopups {
        id: notifPopups
        rootRef: root
        svc: notifSvc
    }

    function toggleNotifCenter() {
        if (notifSvc.centerOpen) {
            notifSvc.closeCenter()
        } else {
            root.closeOverlays()
            notifSvc.openCenter()
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void {
            root.toggleNotifCenter()
        }
    }

    PanelWindow {
        id: notifCenterWin
        visible: notifSvc.centerOpen || notifCenterContent.animProgress > 0.001
        focusable: notifSvc.centerOpen
        color: "transparent"
        WlrLayershell.namespace: "notification-center"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        NotifCenter {
            id: notifCenterContent
            anchors.fill: parent
            rootRef: root
            svc: notifSvc
        }

        onVisibleChanged: {
            if (visible) Qt.callLater(() => notifCenterContent.forceActiveFocus())
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
            margins.top: 12
            implicitWidth: barContent.width
            implicitHeight: barContent.height
            color: "transparent"
            exclusiveZone: margins.top + barRow.y + barRow.height - 5

            mask: Region {
                item: barRow
            }

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

            Component.onCompleted: {
                refreshWorkspaces()
                root.registerCalendarAnchor(outputName, clockPill, modelData, bar)
            }

            Item {
                id: barContent
                width: barRow.implicitWidth + 24
                height: root.barHeight + 24
                anchors.horizontalCenter: parent.horizontalCenter

                MultiEffect {
                    id: barShadowFx
                    anchors.fill: barRow
                    source: barRow
                    shadowEnabled: true
                    shadowBlur: 0.85
                    blurMax: 24
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 5
                    shadowColor: Qt.rgba(0, 0, 0, 0.65)
                    shadowOpacity: 0.6
                }

                Row {
                    id: barRow
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -2
                    spacing: root.groupSpacing

                    Module {
                        id: weatherPill
                        iconSource: weatherIconSource
                        label: root.weatherText
                        tint: root.pillColor("primary_fixed_dim")
                        visible: root.weatherText.length > 0

                        Component {
                            id: weatherIconSource
                            WeatherIcon {
                                tint: weatherPill.pillTextColor
                                variant: root.weatherKey
                            }
                        }
                    }

                    Module {
                        id: prayerPill
                        label: root.prayerText
                        tint: root.pillColor("secondary_container")
                        visible: root.prayerText.length > 0
                    }

                    Module {
                        id: btPill
                        iconSource: bluetoothIconSource
                        label: root.bluetoothText
                        tint: root.pillColor("tertiary_fixed")
                        visible: root.bluetoothStatus === "connected"

                        Component {
                            id: bluetoothIconSource
                            BluetoothIcon { tint: btPill.pillTextColor }
                        }

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
                        tint: root.pillColor("secondary_fixed")
                    }

                    Module {
                        id: volPill
                        iconSource: volIconSource
                        label: root.muted ? "MUTE" : root.volumePercent + "%"
                        tint: root.volTint()

                        Component {
                            id: volIconSource
                            VolumeIcon {
                                tint: volPill.pillTextColor
                                muted: root.muted
                                percent: root.volumePercent
                            }
                        }

                        clickArea.onClicked: {
                            volCmd.command = ["sh", "-c", Quickshell.shellDir + "/scripts/vol.sh mute"]
                            volCmd.running = true
                            volProc.running = true
                        }
                        wheelArea.onWheel: event => {
                            var delta = event.angleDelta.y > 0 ? "+5%" : "-5%"
                            volCmd.command = ["sh", "-c", Quickshell.shellDir + "/scripts/vol.sh set " + delta]
                            volCmd.running = true
                            volProc.running = true
                            event.accepted = true
                        }
                    }

                    Module {
                        id: memPill
                        iconSource: memIconSource
                        label: root.memText
                        tint: root.memTint(root.memPercent)

                        Component {
                            id: memIconSource
                            MemoryIcon { tint: memPill.pillTextColor }
                        }
                    }

                    DynamicPill {
                        id: netBattPill
                    }

                    Module {
                        id: clockPill
                        icon: "󰥔"
                        iconSize: root.fontSize + 3
                        label: root.clockText
                        // Caelestia-style: pill lights up while its popout is open.
                        tint: calPopup.visible
                            ? root.mixColor(root.pillColor("tertiary_container"), "#ffffff", 0.3)
                            : root.pillColor("tertiary_container")
                        rowSpacing: 8
                        rowClip: true

                        clickArea.onClicked: root.openCalendarForOutput(bar.outputName)
                    }
                }
            }

            }
    }

    Calendar {
        id: calPopup
        rootRef: root
    }
}
