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

    // Max-contrast text pick (black vs white, whichever contrasts more).
    // Single shared implementation — components must call this instead of
    // carrying their own copies.
    function contrastColor(c) {
        var col = Qt.color(c)
        var linear = value => value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
        var l = 0.2126 * linear(col.r) + 0.7152 * linear(col.g) + 0.0722 * linear(col.b)
        var white = 1.05 / (l + 0.05)
        var black = (l + 0.05) / 0.05
        return white >= black ? "#ffffff" : "#000000"
    }

    readonly property color primary: colorOf("primary")
    readonly property color error: colorOf("error")
    readonly property color outlineVariant: colorOf("outline_variant")

    readonly property string fontFamily: "Geist"
    readonly property string uiFont: "Geist"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int fontSize: 13

    readonly property int barHeight: 32
    readonly property int pillHeight: 32
    readonly property int pillRadius: 9
    readonly property int groupSpacing: 8

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

    // Audio meter: calm grey when quiet → primary blue when loud, red on mute.
    function volTint() {
        if (root.muted) return root.pillColor("error")
        return root.mixColor(root.pillColor("surface_container_high"),
                             root.pillColor("primary_fixed_dim"),
                             root.volumePercent / 100)
    }

    property string weatherText: ""
    property string weatherKey: "cloud"
    property bool weatherIsDay: true
    property var weatherWeek: []

    function updateWeatherDayNight() {
        var h = new Date().getHours()
        var day = h >= 6 && h < 19
        if (day !== weatherIsDay) weatherIsDay = day
    }

    // Modern glyph icon (Symbols Nerd Font weather set —
    // codepoints verified present in the installed font).
    // Picks a glyph from both the condition and the time of day.
    function weatherGlyph() {
        var day = weatherIsDay
        switch (weatherKey) {
        case "sun": return day ? "\ue30d" : "\ue32b"
        case "partly": return day ? "\ue302" : "\ue32e"
        case "cloud": return "\ue312"
        case "rain": return day ? "\ue308" : "\ue333"
        case "storm": return day ? "\ue30f" : "\ue338"
        case "snow": return day ? "\ue30a" : "\ue335"
        case "fog": return day ? "\ue303" : "\ue313"
        default: return "\ue312"
        }
    }

    // Y2K moon-star replaces the plain clear-night moon glyph.
    function weatherIsY2kMoon() {
        return !weatherIsDay && weatherKey === "sun"
    }

    function refreshWeather() {
        weatherProc.running = true
        weatherWeekProc.running = true
    }

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
    property string memTotalText: ""

    property var mountedDisks: []

    Process {
        id: weatherProc
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/weather.sh"]
        stdout: SplitParser {
            onRead: data => {
                var t = data ? data.trim() : ""
                if (t && !/error|unavailable|failed|not available|⚠|N\/A/i.test(t)) {
                    var parts = t.split("|")
                    if (parts.length >= 2 && parts[1].trim().length > 0) {
                        var k = parts[0].trim()
                        if (k === "sun" || k === "partly" || k === "cloud"
                                || k === "rain" || k === "storm"
                                || k === "snow" || k === "fog")
                            weatherKey = k
                        else
                            weatherKey = "cloud"
                        // Prefer real sunrise/sunset from the script;
                        // fall back to the fixed-hour guess.
                        if (parts.length >= 3) {
                            var dn = parts[2].trim()
                            if (dn === "day" || dn === "night")
                                weatherIsDay = dn === "day"
                            else
                                updateWeatherDayNight()
                        } else {
                            updateWeatherDayNight()
                        }
                        weatherText = parts[1].trim()
                    } else {
                        weatherText = ""
                    }
                } else {
                    weatherText = ""
                }
            }
        }
        onExited: code => { if (code !== 0) weatherText = "" }
    }

    Process {
        id: prayerProc
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/prayer.sh"]
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
                root.memText = used ? used + "G" : ""
                root.memPercent = parseInt(parts[1] || "0", 10) || 0
                var total = parts[2] || ""
                root.memTotalText = total ? total + "G" : ""
            }
        }
    }

    function parseMountedDisks(text) {
        var disks = []
        if (!text) return disks
        var lines = text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var parts = line.split("|")
            if (parts.length >= 4) {
                disks.push({
                    mount: parts[0],
                    pct: parseInt(parts[1] || "0", 10) || 0,
                    free: parts[2] || "0",
                    total: parts[3] || "0"
                })
            }
        }
        return disks
    }

    Process {
        id: mountedDisksProc
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/mounted_disks.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.mountedDisks = root.parseMountedDisks(this.text)
        }
    }

    Process {
        id: weatherWeekProc
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/weather_week.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var arr = JSON.parse(data.trim())
                    if (arr instanceof Array) root.weatherWeek = arr
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: weatherProc.running = true
    }

    Timer {
        interval: 1800000
        running: true
        repeat: true
        onTriggered: weatherWeekProc.running = true
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
                "paplay ~/.local/share/sounds/ios-rebound.oga &\n" +
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

    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: mountedDisksProc.running = true
    }

    property int volumePercent: 0
    property bool muted: false

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
        if (!name) return ""
        if (name.indexOf("Arabic") >= 0 || name === "ara") return "AR"
        if (name.indexOf("English") >= 0 || name === "us") return "US"
        return name
    }

    // Workspace click router: mango tags when available, niri otherwise.
    function focusTag(idx) {
        if (mangoIpc.available) mangoIpc.focusWorkspace(idx)
        else niriIpc.focusWorkspace(idx)
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
        interval: 3000
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
                    "{ sleep 1; paplay ~/.local/share/sounds/iphone-radar.oga; } &\n" +
                    "resp=$(notify-send -u critical -i alarm-clock -t 10000 -A 'default=Stop' 'Timer' 'Time is up! 󰄉');\n" +
                    "[ \"$resp\" = \"default\" ] && pkill -f 'paplay .*iphone-radar\\.oga'"])
            } else {
                root.timerRemainingMs = left
            }
        }
    }

    property string clockText: ""
    property string clockDateText: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date()
            var t = Qt.formatDateTime(now, "hh:mm AP")
            if (t !== root.clockText) root.clockText = t
            var d = Qt.formatDateTime(now, "ddd MMM d")
            if (d !== root.clockDateText) root.clockDateText = d
            // NOTE: day/night comes from real sunrise/sunset via weather.sh —
            // do not override it here with the fixed-hour guess.
        }
    }

    Process {
        id: awwwProc
        command: ["awww-daemon"]
        running: true
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"])
        var _now = new Date()
        root.clockText = Qt.formatDateTime(_now, "hh:mm AP")
        root.clockDateText = Qt.formatDateTime(_now, "ddd MMM d")
        weatherProc.running = true
        weatherWeekProc.running = true
        prayerProc.running = true
        memProc.running = true
        mountedDisksProc.running = true
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

    // Mango tag source (mmsg). Idle unless running under mango
    // (MANGO_INSTANCE_SIGNATURE set by the compositor). Niri path untouched.
    component MangoIpc: Item {
        id: mango

        readonly property bool available: (Quickshell.env("MANGO_INSTANCE_SIGNATURE") || "").length > 0

        // Same shape as NiriIpc.workspaces so bar/widgets need no changes:
        // {id, idx (0-based), name, output, active, focused, urgent, occupied}
        property var workspaces: []

        // Keyboard layout via `mmsg watch keyboardlayout`
        // (niri path uses niriIpc.keyboardLayoutName; mango has no niri socket).
        property string keyboardLayoutName: ""

        signal workspacesUpdated()

        function applyPayload(text) {
            var list = []
            try {
                var obj = JSON.parse(text)
                var groups = obj.all_tags || []
                for (var g = 0; g < groups.length; g++) {
                    var mon = groups[g].monitor || ""
                    var tags = groups[g].tags || []
                    for (var t = 0; t < tags.length; t++) {
                        var tg = tags[t]
                        var num = parseInt(tg.index) || 0
                        if (num <= 0) continue
                        list.push({
                            id: mon + ":" + num,
                            idx: num - 1,
                            name: String(num),
                            output: mon,
                            active: tg.is_active === true,
                            focused: tg.is_active === true,
                            urgent: tg.is_urgent === true,
                            occupied: (parseInt(tg.client_count) || 0) > 0
                        })
                    }
                }
            } catch (e) { return }
            mango.workspaces = list
            mango.workspacesUpdated()
        }

        function focusWorkspace(idx) {
            Quickshell.execDetached(["mmsg", "dispatch", "comboview," + (idx + 1)])
        }

        function applyKbLayout(text) {
            try {
                var obj = JSON.parse(text)
                if (obj.layout && obj.layout !== mango.keyboardLayoutName)
                    mango.keyboardLayoutName = obj.layout
            } catch (e) { return }
        }

        function refreshOnce() {
            if (!mango.available || getProc.running) return
            getProc.running = true
        }

        Process {
            id: getProc
            command: ["sh", "-c", "mmsg get all-tags 2>/dev/null"]
            stdout: SplitParser {
                onRead: data => { if (data) mango.applyPayload(data) }
            }
        }

        Process {
            id: watchProc
            command: ["sh", "-c", "exec mmsg watch all-tags 2>/dev/null"]
            running: mango.available
            stdout: SplitParser {
                onRead: data => { if (data) mango.applyPayload(data) }
            }
            onExited: watchRestart.restart()
        }

        Timer {
            id: watchRestart
            interval: 5000
            repeat: false
            onTriggered: { if (mango.available) watchProc.running = true }
        }

        // Streams {"layout":"English (US)"} / {"layout":"Arabic"}; emits
        // the current layout immediately on connect, so no initial get needed.
        Process {
            id: kbWatchProc
            command: ["sh", "-c", "exec mmsg watch keyboardlayout 2>/dev/null"]
            running: mango.available
            stdout: SplitParser {
                onRead: data => { if (data) mango.applyKbLayout(data) }
            }
            onExited: kbWatchRestart.restart()
        }

        Timer {
            id: kbWatchRestart
            interval: 5000
            repeat: false
            onTriggered: { if (mango.available) kbWatchProc.running = true }
        }

        Timer {
            id: tagPoller
            interval: 10000
            running: mango.available
            repeat: true
            onTriggered: mango.refreshOnce()
        }

        Component.onCompleted: Qt.callLater(() => mango.refreshOnce())
    }

    NiriIpc {
        id: niriIpc
    }

    MangoIpc {
        id: mangoIpc
    }

    component Module: Rectangle {
        id: pill
        property string label: ""
        property string icon: ""
        property Component iconSource: null
        property int padX: 20
        property int rowSpacing: 4
        property bool rowClip: false
        property int iconSize: root.fontSize + 8
        property color tint: root.primary
        property alias clickArea: pillArea
        property alias wheelArea: pillArea

        readonly property color pillTextColor: root.pillForeground(pill.color)

        implicitWidth: pillRow.implicitWidth + pill.padX
        implicitHeight: root.pillHeight
        radius: root.pillRadius
        color: root.tonalPillColor(tint)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        property int enterOrder: 0
        property real enterShift: 10
        opacity: 0
        transform: Translate { y: pill.enterShift }
        Timer {
            interval: 120 + pill.enterOrder * 55
            running: true
            repeat: false
            onTriggered: { pill.opacity = 1; pill.enterShift = 0 }
        }
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        Behavior on enterShift { Anim { type: Anim.Bouncy } }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: Quickshell.env("QS_NO_SHADOW") !== "1"
            shadowBlur: 0.7
            blurMax: 16
            shadowHorizontalOffset: 3
            shadowVerticalOffset: 5
            shadowColor: Qt.rgba(0, 0, 0, 0.9)
            shadowOpacity: 0.9
        }

        Behavior on color { CAnim { } }

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
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: pillArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }

        scale: pillArea.pressed ? 0.94 : pillArea.containsMouse ? 1.06 : 1.0
        Behavior on scale { Anim { type: Anim.BouncyFast } }
    }

    component DynamicPill: Rectangle {
        id: dc
        property int padX: 14
        property int iconSize: root.fontSize + 2
        // Pill stays a neutral surface tone — wifi strength is shown by the
        // live arcs inside, not by re-tinting the whole pill. Red only offline.
        readonly property color tint: root.networkConnected ? root.pillColor("surface_container_high") : root.pillColor("error")
        readonly property color pillTextColor: root.pillForeground(dc.color)
        readonly property bool hovering: dcArea.containsMouse || dcArea.pressed
        // Smoothed signal so arcs animate live instead of jumping.
        property real liveSignal: root.networkSignal
        Behavior on liveSignal { Anim { type: Anim.StandardLarge } }

        implicitHeight: root.pillHeight
        radius: root.pillRadius
        color: root.tonalPillColor(dc.tint)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        property int enterOrder: 0
        property real enterShift: 10
        opacity: 0
        transform: Translate { y: dc.enterShift }
        Timer {
            interval: 120 + dc.enterOrder * 55
            running: true
            repeat: false
            onTriggered: { dc.opacity = 1; dc.enterShift = 0 }
        }
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        Behavior on enterShift { Anim { type: Anim.Bouncy } }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: Quickshell.env("QS_NO_SHADOW") !== "1"
            shadowBlur: 0.7
            blurMax: 16
            shadowHorizontalOffset: 3
            shadowVerticalOffset: 5
            shadowColor: Qt.rgba(0, 0, 0, 0.9)
            shadowOpacity: 0.9
        }

        implicitWidth: dcRow.implicitWidth + dc.padX
        Behavior on implicitWidth { Anim { type: Anim.BouncyFast } }
        Behavior on color { CAnim { } }

        scale: dcArea.pressed ? 0.94 : dcArea.containsMouse ? 1.06 : 1.0
        Behavior on scale { Anim { type: Anim.BouncyFast } }

        Row {
            id: dcRow
            anchors.centerIn: parent
            spacing: 8

            Item {
                id: arcSlot
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: arcC.width + 8
                implicitHeight: root.pillHeight

                Canvas {
                    id: arcC
                    anchors.centerIn: parent
                    // Follow the pill height so the icon scales with the bar.
                    width: root.pillHeight - 3
                    height: root.pillHeight - 3
                    antialiasing: true
                    property int percent: root.batteryPercent
                    property bool charging: root.charging
                    property color base: dc.pillTextColor
                    property real signal: dc.liveSignal
                    property bool wifiConnected: root.networkConnected

                    onPercentChanged: requestPaint()
                    onChargingChanged: requestPaint()
                    onBaseChanged: requestPaint()
                    onSignalChanged: requestPaint()
                    onWifiConnectedChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        var ctx = arcC.getContext("2d")
                        ctx.reset()
                        var w = arcC.width
                        var h = arcC.height
                        if (w <= 0 || h <= 0) return
                        // Resolution-independent: the artwork below is authored
                        // in a 32x32 design box, scaled to fit the canvas.
                        var s = Math.min(w, h) / 32
                        ctx.translate((w - 32 * s) / 2, (h - 32 * s) / 2)
                        ctx.scale(s, s)
                        var cx = 16
                        var cy = 16
                        var r = 13.5
                        var gapRad = Math.PI / 4
                        var maxSweep = 2 * Math.PI - 2 * gapRad
                        ctx.lineCap = "round"
                        ctx.lineWidth = 3
                        var capInset = (ctx.lineWidth / 2) / r
                        var sweepMax = maxSweep - 2 * capInset
                        var frac = Math.max(0, Math.min(1, arcC.percent / 100))
                        var start = Math.PI / 2 + gapRad + capInset

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
                        ctx.lineWidth = 1.8
                        // Live signal: dot + 3 arcs light up by thresholds.
                        // Disconnected -> everything dim.
                        var litArcs = !arcC.wifiConnected ? -1
                            : arcC.signal >= 70 ? 3
                            : arcC.signal >= 45 ? 2
                            : arcC.signal >= 20 ? 1 : 0
                        var dotA = arcC.wifiConnected ? 1.0 : 0.18
                        var b = arcC.base
                        ctx.fillStyle = Qt.rgba(b.r, b.g, b.b, dotA)
                        ctx.beginPath()
                        ctx.arc(cx, gy, 1.8, 0, Math.PI * 2)
                        ctx.fill()
                        for (var i = 0; i < 3; i++) {
                            var a = (i < litArcs) ? 1.0 : 0.18
                            ctx.strokeStyle = Qt.rgba(b.r, b.g, b.b, a)
                            ctx.beginPath()
                            ctx.arc(cx, gy, 4.2 + i * 3.3, Math.PI * 1.25, Math.PI * 1.75)
                            ctx.stroke()
                        }
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
                font.weight: Font.DemiBold
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
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

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
    component VolumeIcon: Canvas {
        id: v
        property color tint: "#ffffff"
        property bool muted: false
        property int percent: 50
        implicitWidth: 22
        implicitHeight: 22

        onTintChanged: requestPaint()
        onMutedChanged: requestPaint()
        onPercentChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.scale(v.width / 24, v.height / 24)
            ctx.strokeStyle = v.tint
            ctx.fillStyle = v.tint
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            // Solid speaker body.
            ctx.beginPath()
            ctx.moveTo(11, 5.5)
            ctx.lineTo(6.5, 9.5)
            ctx.lineTo(3, 9.5)
            ctx.lineTo(3, 14.5)
            ctx.lineTo(6.5, 14.5)
            ctx.lineTo(11, 18.5)
            ctx.closePath()
            ctx.fill()

            if (v.muted) {
                ctx.lineWidth = 2.2
                ctx.beginPath()
                ctx.moveTo(15.5, 9.5)
                ctx.lineTo(21, 15)
                ctx.moveTo(21, 9.5)
                ctx.lineTo(15.5, 15)
                ctx.stroke()
            } else {
                // Three live waves — lit by level, dim when below threshold.
                var lit = v.percent > 66 ? 3 : v.percent > 33 ? 2 : v.percent > 0 ? 1 : 0
                ctx.lineWidth = 2
                for (var i = 0; i < 3; i++) {
                    var t = v.tint
                    ctx.strokeStyle = Qt.rgba(t.r, t.g, t.b, (i < lit) ? 1.0 : 0.18)
                    ctx.beginPath()
                    ctx.arc(8.5, 12, 4.2 + i * 3, -Math.PI / 4, Math.PI / 4, false)
                    ctx.stroke()
                }
            }
        }
    }

    component BluetoothIcon: Canvas {
        id: bt
        property color tint: "#ffffff"
        implicitWidth: 22
        implicitHeight: 22

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
        implicitWidth: 22
        implicitHeight: 22

        onTintChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            // Native art is a 20px grid — scale into the shared 22px icon cell.
            ctx.scale(1.1, 1.1)
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

    component KeyboardIcon: Canvas {
        id: kb
        property color tint: "#ffffff"
        implicitWidth: 26
        implicitHeight: 19

        onTintChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            // Scale the 22x16 native art about its center into the 26x19 cell.
            ctx.translate(13, 9.5)
            ctx.scale(1.2, 1.2)
            ctx.translate(-11, -8)
            ctx.strokeStyle = kb.tint
            ctx.fillStyle = kb.tint
            ctx.lineCap = "round"
            ctx.lineWidth = 1.5

            // Board outline.
            var x = 2, y = 3, w = 18, h = 10, r = 2.5
            ctx.beginPath()
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + w - r, y)
            ctx.arcTo(x + w, y, x + w, y + r, r)
            ctx.lineTo(x + w, y + h - r)
            ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
            ctx.lineTo(x + r, y + h)
            ctx.arcTo(x, y + h, x, y + h - r, r)
            ctx.lineTo(x, y + r)
            ctx.arcTo(x, y, x + r, y, r)
            ctx.closePath()
            ctx.stroke()

            // Top row keys.
            for (var i = 0; i < 4; i++)
                ctx.fillRect(4.5 + i * 3.4, 5, 2, 2)
            // Bottom row: key + spacebar + key.
            ctx.fillRect(4.5, 8.6, 2, 2)
            ctx.fillRect(7.4, 8.6, 7.2, 2)
            ctx.fillRect(15.3, 8.6, 2, 2)
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
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        property int enterOrder: 0
        property real enterShift: 10
        opacity: 0
        transform: Translate { y: wsWidget.enterShift }
        Timer {
            interval: 120 + wsWidget.enterOrder * 55
            running: true
            repeat: false
            onTriggered: { wsWidget.opacity = 1; wsWidget.enterShift = 0 }
        }
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        Behavior on enterShift { Anim { type: Anim.Bouncy } }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: Quickshell.env("QS_NO_SHADOW") !== "1"
            shadowBlur: 0.7
            blurMax: 16
            shadowHorizontalOffset: 3
            shadowVerticalOffset: 5
            shadowColor: Qt.rgba(0, 0, 0, 0.9)
            shadowOpacity: 0.9
        }

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
                            Behavior on width { Anim { type: Anim.BouncyFast } }
                            Behavior on scale { Anim { type: Anim.BouncyFast } }

                            Rectangle {
                                anchors.fill: parent
                                radius: wsWidget.dotRadius
                                color: focused ? wsWidget.accent : root.pillForeground(wsWidget.color)
                                opacity: focused ? 1.0 : (occupied ? 0.5 : 0.18)
                                Behavior on color { CAnim { } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: {
                                    if (modelData) root.focusTag(modelData.idx)
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
            if (ws) root.focusTag(ws.idx)
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
        root.whatsappActive = false
        root.clipboardActive = false
        root.notesActive = false
        root.wallpaperActive = false
        if (calPopup.visible) calPopup.close()
    }

    property bool wallpaperActive: false

    function openWallpaperPicker() {
        if (root.wallpaperActive) return
        root.closeOverlays()
        root.wallpaperActive = true
    }
    function closeWallpaperPicker() {
        root.wallpaperActive = false
    }
    function toggleWallpaperPicker() {
        if (root.wallpaperActive) closeWallpaperPicker()
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
        color: "transparent"
        WlrLayershell.namespace: "app-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        // NOTE: no `focusable:` alongside keyboardFocus (both write the same
        // property; focusable would downgrade Exclusive to OnDemand and mango
        // only auto-focuses Exclusive layers).
        WlrLayershell.keyboardFocus: root.launcherActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
        color: "transparent"
        WlrLayershell.namespace: "ytx-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.ytxActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
        color: "transparent"
        WlrLayershell.namespace: "whatsapp-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.whatsappActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
        color: "transparent"
        WlrLayershell.namespace: "clipboard-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.clipboardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
        color: "transparent"
        WlrLayershell.namespace: "notes-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.notesActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
        visible: root.wallpaperActive || pickerContent.animProgress > 0.001
        color: "transparent"
        WlrLayershell.namespace: "wallpaper-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.wallpaperActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        WallpaperPicker {
            id: pickerContent
            anchors.fill: parent
            visible_: root.wallpaperActive
            currentMode: root.qsLight ? "light" : "dark"

            surfaceColor: "#17181c"
            borderColor: Qt.color(root.colorOf("outline_variant"))
            fgColor: "#ffffff"
            accentColor: Qt.color(root.colorOf("primary"))
            iconFont: root.iconFont
            uiFont: root.uiFont
            onRequestClose: root.wallpaperActive = false
        }

        onVisibleChanged: {
            if (visible) {
                pickerContent.triggerIndexer()
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
        color: "transparent"
        WlrLayershell.namespace: "notification-center"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: notifSvc.centerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
            // Mango gives keyboard focus to any EXCLUSIVE layer, so a permanently
            // focusable bar would trap keys (and receive focus after pickers close).
            // Niri handles this fine, so only gate it under mango.
            focusable: !mangoIpc.available

            anchors.top: true
            margins.top: 12
            implicitWidth: barContent.width
            implicitHeight: barContent.height
            color: "transparent"
            // mango 0.17.2 stacks the surface offset on top of the exclusive
            // zone (usable_top = margins.top + exclusiveZone), and outer gaps
            // (gappov) stack on top of that. -14 keeps tiled windows ~15px
            // under the pills with gappov=15.
            exclusiveZone: margins.top + barRow.y + barRow.height - 5

            mask: Region {
                item: barRow
            }

            readonly property string outputName: modelData ? modelData.name : ""
            property var workspaceList: []

            function refreshWorkspaces() {
                var list = []
                var src = (mangoIpc.available && mangoIpc.workspaces.length > 0)
                    ? mangoIpc.workspaces : niriIpc.workspaces
                for (const ws of src) {
                    if (ws.output === outputName) list.push(ws)
                }
                list.sort((a, b) => a.idx - b.idx)
                workspaceList = list
            }

            Connections {
                target: niriIpc
                function onWorkspacesUpdated() { bar.refreshWorkspaces() }
            }

            Connections {
                target: mangoIpc
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

                Row {
                    id: barRow
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -2
                    spacing: root.groupSpacing

                    // Pill color roles (matugen tokens, one hue per family):
                    //  sky info   → blue   primary_fixed_dim      (weather)
                    //  faith      → yellow `prayer` token         (prayer)
                    //  devices    → green  secondary_fixed_dim    (bluetooth)
                    //  chrome     → neutral surface_container_high (keyboard, net/battery)
                    //  audio      → grey→blue volTint, red on mute (volume)
                    //  pressure   → green→yellow→red memTint      (memory)
                    //  anchors    → sapphire primary_container    (workspaces)
                    //              pink tertiary_container        (clock)
                    //
                    //  Reading order: glance → faith → input → devices → navigate → sound → meters → time.
                    Module {
                        id: weatherPill
                        enterOrder: 0
                        icon: root.weatherIsY2kMoon() ? "" : root.weatherGlyph()
                        iconSource: root.weatherIsY2kMoon() ? y2kMoonSource : null
                        iconSize: root.fontSize + 11
                        label: root.weatherText
                        tint: root.pillColor("primary_fixed_dim")
                        visible: root.weatherText.length > 0

                        Component {
                            id: y2kMoonSource
                            QIcon {
                                source: Qt.resolvedUrl("./assets/icons/y2k-moon-star.svg")
                                color: weatherPill.pillTextColor
                                iconSize: weatherPill.iconSize
                            }
                        }
                    }

                    Module {
                        id: prayerPill
                        enterOrder: 1
                        label: root.prayerText
                        tint: root.pillColor("prayer")
                        visible: root.prayerText.length > 0
                    }

                    Module {
                        id: kbPill
                        enterOrder: 2
                        iconSource: kbIconSource
                        label: root.shortLayout(mangoIpc.keyboardLayoutName.length > 0 ? mangoIpc.keyboardLayoutName : niriIpc.keyboardLayoutName)
                        tint: root.pillColor("surface_container_high")

                        Component {
                            id: kbIconSource
                            KeyboardIcon { tint: kbPill.pillTextColor }
                        }
                    }

                    Module {
                        id: btPill
                        enterOrder: 3
                        iconSource: bluetoothIconSource
                        label: root.bluetoothText
                        tint: root.pillColor("secondary_fixed_dim")
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
                        enterOrder: 4
                        workspaces: bar.workspaceList
                        anchors.verticalCenter: parent.verticalCenter
                        // mango has tags, not workspaces: hide under mango, keep under niri
                        visible: !mangoIpc.available
                    }

                    Module {
                        id: volPill
                        enterOrder: 5
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
                        enterOrder: 6
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
                        enterOrder: 7
                    }

                    Rectangle {
                        id: clockPill
                        property int enterOrder: 8
                        property color tint: calPopup.visible
                            ? root.mixColor(root.pillColor("tertiary_container"), "#ffffff", 0.3)
                            : root.pillColor("tertiary_container")
                        readonly property color pillTextColor: root.pillForeground(clockPill.color)
                        readonly property color dimTextColor: Qt.rgba(pillTextColor.r, pillTextColor.g, pillTextColor.b, 0.62)

                        implicitWidth: clockRow.implicitWidth + 20
                        implicitHeight: root.pillHeight
                        radius: root.pillRadius
                        color: root.tonalPillColor(tint)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        property real enterShift: 10
                        opacity: 0
                        transform: Translate { y: clockPill.enterShift }
                        Timer {
                            interval: 120 + clockPill.enterOrder * 55
                            running: true
                            repeat: false
                            onTriggered: { clockPill.opacity = 1; clockPill.enterShift = 0 }
                        }
                        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                        Behavior on enterShift { Anim { type: Anim.Bouncy } }
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: Quickshell.env("QS_NO_SHADOW") !== "1"
                            shadowBlur: 0.7
                            blurMax: 16
                            shadowHorizontalOffset: 3
                            shadowVerticalOffset: 5
                            shadowColor: Qt.rgba(0, 0, 0, 0.9)
                            shadowOpacity: 0.9
                        }
                        Behavior on color { CAnim { } }
                        Behavior on implicitWidth { Anim { type: Anim.BouncyFast } }

                        Row {
                            id: clockRow
                            anchors.centerIn: parent
                            spacing: 6

                            Canvas {
                                id: timeIcon
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                antialiasing: true
                                property color fg: clockPill.pillTextColor
                                property color bg: clockPill.color
                                onFgChanged: requestPaint()
                                onBgChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var c = width / 2
                                    ctx.lineCap = "round"
                                    ctx.fillStyle = timeIcon.fg
                                    ctx.beginPath()
                                    ctx.arc(c, c, 6, 0, Math.PI * 2)
                                    ctx.fill()
                                    ctx.strokeStyle = timeIcon.bg
                                    var hand = (frac, len, w) => {
                                        var a = frac * Math.PI * 2 - Math.PI / 2
                                        ctx.lineWidth = w
                                        ctx.beginPath()
                                        ctx.moveTo(c, c)
                                        ctx.lineTo(c + Math.cos(a) * len, c + Math.sin(a) * len)
                                        ctx.stroke()
                                    }
                                    hand(10 / 12, 2.8, 1.9)
                                    hand(9 / 60, 4.0, 1.6)
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.clockText
                                color: clockPill.pillTextColor
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 3
                                radius: 1.5
                                color: clockPill.dimTextColor
                            }

                            Canvas {
                                id: dateIcon
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                antialiasing: true
                                property color fg: clockPill.dimTextColor
                                onFgChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.strokeStyle = dateIcon.fg
                                    ctx.lineCap = "round"
                                    ctx.lineWidth = 1.5
                                    var x = 2, y = 3, w = 10, h = 9, r = 2
                                    ctx.beginPath()
                                    ctx.moveTo(x + r, y)
                                    ctx.lineTo(x + w - r, y)
                                    ctx.arcTo(x + w, y, x + w, y + r, r)
                                    ctx.lineTo(x + w, y + h - r)
                                    ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
                                    ctx.lineTo(x + r, y + h)
                                    ctx.arcTo(x, y + h, x, y + h - r, r)
                                    ctx.lineTo(x, y + r)
                                    ctx.arcTo(x, y, x + r, y, r)
                                    ctx.closePath()
                                    ctx.stroke()
                                    ctx.beginPath()
                                    ctx.moveTo(x, y + 3.4)
                                    ctx.lineTo(x + w, y + 3.4)
                                    ctx.stroke()
                                    ctx.lineWidth = 1.6
                                    ctx.beginPath()
                                    ctx.moveTo(x + 3.2, y + 1.2)
                                    ctx.lineTo(x + 3.2, y + 3.4)
                                    ctx.moveTo(x + w - 3.2, y + 1.2)
                                    ctx.lineTo(x + w - 3.2, y + 3.4)
                                    ctx.stroke()
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.clockDateText
                                color: clockPill.dimTextColor
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize - 1
                                font.weight: Font.Normal
                            }
                        }

                        MouseArea {
                            id: clockArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openCalendarForOutput(bar.outputName)
                        }

                        scale: clockArea.pressed ? 0.94 : clockArea.containsMouse ? 1.06 : 1.0
                        Behavior on scale { Anim { type: Anim.BouncyFast } }
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
