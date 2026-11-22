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

    // Some generated presets repeat one palette under both mode suffixes.
    // Keep neutral surfaces usable even when that palette has the wrong tone.
    readonly property var surfaceFallbacks: ({
        background: ["#f6f7fa", "#151619"],
        surface: ["#f6f7fa", "#151619"],
        surface_container_lowest: ["#ffffff", "#101114"],
        surface_container_low: ["#f0f1f4", "#1b1c20"],
        surface_container: ["#eaecf0", "#202126"],
        surface_container_high: ["#e3e5ea", "#292b30"],
        surface_container_highest: ["#dadde3", "#33353b"]
    })

    function colorOf(name, light = root.qsLight) {
        var map = colorFile.paletteMap
        var value = light ? map[name + "_light"] || map[name] : map[name]
        var fallback = root.surfaceFallbacks[name]
        if (fallback && (!value || (light ? root.relativeLuminance(value) < 0.20 : root.relativeLuminance(value) > 0.175)))
            return fallback[light ? 0 : 1]

        if (name === "on_surface" || name === "on_surface_variant" || name === "on_background") {
            var surfaces = name === "on_background" ? ["background"] : [
                "surface", "surface_container_lowest", "surface_container_low",
                "surface_container", "surface_container_high", "surface_container_highest"
            ]
            var ink = light ? "#000000" : "#ffffff"
            if (!value) return ink
            if (surfaces.some(role => root.contrastRatio(value, root.colorOf(role, light)) < 4.5))
                return ink
        }
        return value || "#808080"
    }

    FileView {
        id: qsThemeFile
        property string mode: "light"
        path: Quickshell.shellDir + "/qs-theme.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: qsThemeFile.reload()
        onLoadFailed: error => console.log("[qs-theme] failed to load qs-theme.json:", error)
        onLoaded: {
            try {
                var theme = JSON.parse(String(qsThemeFile.text()))
                if (theme.mode === "light" || theme.mode === "dark")
                    qsThemeFile.mode = theme.mode
            } catch (e) {
                console.log("[qs-theme] parse error:", e)
            }
        }
    }

    // An explicit desktop preference overrides the wallpaper-derived mode.
    Process {
        id: desktopTheme
        property string mode: ""
        running: true
        command: ["sh", "-c",
            "gsettings get org.gnome.desktop.interface color-scheme; "
            + "exec gsettings monitor org.gnome.desktop.interface color-scheme"]
        stdout: SplitParser {
            onRead: line => {
                var match = line.trim().match(/^(?:color-scheme:\s*)?'?(prefer-light|prefer-dark|default)'?$/)
                if (match)
                    desktopTheme.mode = match[1] === "default" ? "" : match[1]
            }
        }
    }

    readonly property bool qsLight: desktopTheme.mode
        ? desktopTheme.mode === "prefer-light"
        : qsThemeFile.mode === "light"

    function barColor(name) {
        return root.colorOf(name, true)
    }

    function tonalPillColor(accent, light = root.qsLight) {
        var color = Qt.color(accent)
        // Tonal pills follow the mode: light pills on light mode, dark
        // pills on dark mode, so text picked by contrastColor stays readable.
        var lightness = light
            ? Math.max(color.hslLightness, 0.76)
            : Math.min(color.hslLightness, 0.24)
        return Qt.hsla(Math.max(0, color.hslHue), color.hslSaturation, lightness, 1)
    }

    function relativeLuminance(color) {
        var col = Qt.color(color)
        var linear = value => value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
        return 0.2126 * linear(col.r) + 0.7152 * linear(col.g) + 0.0722 * linear(col.b)
    }

    function contrastRatio(foreground, background) {
        var fg = root.relativeLuminance(foreground)
        var bg = root.relativeLuminance(background)
        return (Math.max(fg, bg) + 0.05) / (Math.min(fg, bg) + 0.05)
    }

    function contrastColor(background) {
        return root.relativeLuminance(background) < 0.179 ? "#ffffff" : "#000000"
    }

    function readableColor(foreground, background) {
        if (root.contrastRatio(foreground, background) >= 4.5) return Qt.color(foreground)
        var ink = root.contrastColor(background)
        for (var amount of [0.25, 0.5, 0.75]) {
            var candidate = root.mixColor(foreground, ink, amount)
            if (root.contrastRatio(candidate, background) >= 4.5) return candidate
        }
        return Qt.color(ink)
    }

    readonly property color primary: colorOf("primary")
    readonly property color error: colorOf("error")

    readonly property string fontFamily: "Geist"
    readonly property string uiFont: "Geist"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int fontSize: 13

    readonly property int barHeight: 32
    readonly property int pillHeight: 32
    readonly property int pillRadius: 12
    readonly property int groupSpacing: 8

    readonly property string terminalCommand: "foot"

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
        var g = root.barColor("secondary_fixed_dim")
        var a = root.barColor("secondary_container")
        var r = root.barColor("error")
        if (p <= 50) return root.mixColor(g, a, p / 50)
        return root.mixColor(a, r, (p - 50) / 50)
    }

    // Audio meter: calm grey when quiet → primary blue when loud, red on mute.
    function volTint() {
        if (root.muted) return root.barColor("error")
        return root.mixColor(root.barColor("surface_container_high"),
                             root.barColor("primary_fixed_dim"),
                             root.volumePercent / 100)
    }

    property string weatherText: ""
    property string weatherKey: "cloud"
    property bool weatherIsDay: true
    property var weatherWeek: []
    property string weatherFeels: ""
    property string weatherCity: ""

    function updateWeatherDayNight() {
        var h = new Date().getHours()
        var day = h >= 6 && h < 19
        if (day !== weatherIsDay) weatherIsDay = day
    }

    // Condition label for the key weather.sh reports. The pill only ever
    // showed the temperature, so the panel needs its own name for the kind.
    function weatherLabel() {
        switch (weatherKey) {
        case "sun": return "Clear"
        case "partly": return "Partly cloudy"
        case "cloud": return "Cloudy"
        case "fog": return "Fog"
        case "rain": return "Rain"
        case "storm": return "Thunderstorm"
        case "snow": return "Snow"
        default: return "Cloudy"
        }
    }

    // The panel shows the temperature alone, in the display face, so the
    // unit suffix the script appends is dropped to keep the reading large.
    function weatherTempOnly() {
        return weatherText.replace(/C$/, "")
    }

    // Modern glyph icon (Symbols Nerd Font weather set —
    // codepoints verified present in the installed font).
    // Picks a glyph from both the condition and the time of day.
    function weatherGlyph() {
        return root.hourGlyph(weatherKey, weatherIsDay)
    }

    // Same set, but per-entry day flag — for the hourly strip, whose
    // hours each carry their own day/night.
    function hourGlyph(key, day) {
        switch (key) {
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

    property var mountedDisks: []
    property var removableDrives: []

    function refreshStorage() {
        if (removableProc.running || mountedDisksProc.running) {
            removableDebounce.restart()
            return
        }
        removableProc.running = true
        mountedDisksProc.running = true
    }

    function removableAction(args) {
        if (removableCmd.running) return
        removableCmd.command = args
        removableCmd.running = true
    }

    function mountVolume(devPath) {
        root.removableAction(["udisksctl", "mount", "-b", devPath])
    }

    function unmountVolume(devPath) {
        root.removableAction(["udisksctl", "unmount", "-b", devPath])
    }

    function ejectDrive(devPath) {
        // Unmount every volume first, then power the drive down.
        var vols = []
        for (var i = 0; i < root.removableDrives.length; i++) {
            var d = root.removableDrives[i]
            if (d && d.dev === devPath && d.volumes) vols = d.volumes
        }
        var mounts = []
        for (var j = 0; j < vols.length; j++)
            if (vols[j] && vols[j].mount) mounts.push(vols[j].path)
        var script = "disk=\"$1\"; shift; "
                   + "for v in \"$@\"; do udisksctl unmount -b \"$v\" >/dev/null || exit; done; "
                   + "udisksctl power-off -b \"$disk\""
        root.removableAction(["sh", "-c", script, "eject", devPath].concat(mounts))
    }

    function openMount(mountPoint) {
        // Opens a foot terminal in the directory. -D sets the working
        // directory; a bare path would be treated as the command to run.
        if (!mountPoint) return
        var title = "foot"
        var parts = String(mountPoint).split("/").filter(p => p.length > 0)
        if (parts.length > 0) title = parts[parts.length - 1]
        Quickshell.execDetached([root.terminalCommand, "-D", mountPoint, "-T", title])
    }

    Process {
        id: removableProc
        command: ["sh", Quickshell.shellDir + "/scripts/removable.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(this.text)
                    if (arr instanceof Array) {
                        // Guard: keep the old reference when nothing changed so
                        // the NotifCenter repeater doesn't rebuild every poll.
                        if (JSON.stringify(arr) !== JSON.stringify(root.removableDrives))
                            root.removableDrives = arr
                    }
                } catch (e) {
                    console.log("[removable] parse error:", e)
                }
            }
        }
        onExited: code => { if (code !== 0) console.log("[removable] script failed:", code) }
    }

    Process {
        id: removableCmd
        onExited: code => {
            if (code !== 0) console.warn("[storage] command failed:", code)
            removableDebounce.restart()
        }
    }

    // Event-driven refresh: removableWatch blocks on udisks2 D-Bus signals
    // (attach / detach / mount / unmount) and prints one line per event.
    // Bursts (one plug = several signals) are coalesced by the debounce timer.
    Process {
        id: removableWatch
        command: ["sh", Quickshell.shellDir + "/scripts/removable_watch.sh"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data && data.indexOf("refresh") >= 0 && !removableDebounce.running)
                    removableDebounce.restart()
            }
        }
        onExited: watchRestart.restart()
    }

    Timer {
        id: removableDebounce
        interval: 600
        repeat: false
        onTriggered: root.refreshStorage()
    }

    Timer {
        id: watchRestart
        interval: 5000
        repeat: false
        onTriggered: { if (!removableWatch.running) removableWatch.running = true }
    }

    Process {
        id: weatherProc
        command: ["sh", Quickshell.shellDir + "/scripts/weather.sh"]
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
                        weatherFeels = parts.length >= 4 ? parts[3].trim() : ""
                        weatherCity = parts.length >= 5 ? parts[4].trim() : ""
                    } else {
                        weatherText = ""
                        weatherFeels = ""
                        weatherCity = ""
                    }
                } else {
                    weatherText = ""
                    weatherFeels = ""
                    weatherCity = ""
                }
            }
        }
        onExited: code => { if (code !== 0) { weatherText = ""; weatherFeels = ""; weatherCity = "" } }
    }

    Process {
        id: prayerProc
        command: ["sh", Quickshell.shellDir + "/scripts/prayer.sh"]
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
        command: ["sh", Quickshell.shellDir + "/scripts/mem.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split("|")
                var used = parts[0] || ""
                root.memText = used ? used + "G" : ""
                root.memPercent = parseInt(parts[1] || "0", 10) || 0
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
        command: ["sh", Quickshell.shellDir + "/scripts/mounted_disks.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                var arr = root.parseMountedDisks(this.text)
                // Keep the old reference when nothing changed, so the storage
                // rows in the NotifCenter are not rebuilt on every open.
                if (JSON.stringify(arr) !== JSON.stringify(root.mountedDisks))
                    root.mountedDisks = arr
            }
        }
    }

    Process {
        id: weatherWeekProc
        command: ["sh", Quickshell.shellDir + "/scripts/weather_week.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var v = JSON.parse(this.text.trim())
                    if (!(v instanceof Array)) return
                    // Keep the old reference when nothing changed, so the
                    // forecast columns in the NotifCenter are not rebuilt.
                    if (JSON.stringify(v) !== JSON.stringify(root.weatherWeek))
                        root.weatherWeek = v
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: { if (!weatherProc.running) weatherProc.running = true }
    }

    // NOTE: weatherWeekProc has no timer — the week strip lives in the
    // notification center, which triggers a fetch on open (see below).

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: { if (!prayerProc.running) prayerProc.running = true }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: updatePrayerCountdown()
    }

    Timer {
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
        onTriggered: { if (!memProc.running) memProc.running = true }
    }

    // NOTE: mountedDisksProc has no timer — the disk cards live in the
    // notification center, which triggers a fetch on open (see below).

    property int volumePercent: 0
    property bool muted: false

    Process {
        id: volProc
        command: ["sh", Quickshell.shellDir + "/scripts/vol.sh", "get"]
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
        property var queue: []

        function enqueue(args) {
            queue.push(args)
            if (!running) Qt.callLater(volCmd.runNext)
        }

        function runNext() {
            if (running) return
            if (queue.length === 0) {
                volRefresh.restart()
                return
            }
            command = ["sh", Quickshell.shellDir + "/scripts/vol.sh"].concat(queue.shift())
            running = true
        }

        onExited: Qt.callLater(volCmd.runNext)
    }

    Timer {
        id: volRefresh
        interval: 75
        onTriggered: {
            if (volProc.running)
                restart()
            else
                volProc.running = true
        }
    }

    Process {
        id: volWatch
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var t = data.toLowerCase()
                if (t.includes("sink") || t.includes("server"))
                    volRefresh.restart()
            }
        }
        onExited: volRestart.restart()
    }

    Timer {
        id: volRestart
        interval: 5000
        repeat: false
        onTriggered: {
            volWatch.running = true
            volRefresh.restart()
        }
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
        command: ["sh", Quickshell.shellDir + "/scripts/wifi.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    try {
                        var d = JSON.parse(data.trim())
                        root.networkConnected = d.connected === true
                        root.networkIp = d.ip || ""
                        root.networkSignal = parseInt(d.signal) || 0
                        root.networkDown = parseInt(d.down) || 0
                    } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: { if (!netProc.running) netProc.running = true }
    }

    property string bluetoothText: ""
    property string bluetoothStatus: "off"

    Process {
        id: btProc
        command: ["sh", Quickshell.shellDir + "/scripts/bluetooth.sh"]
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
        command: ["bluetoothctl", "disconnect"]
        onExited: btProc.running = true
    }

    Timer {
        id: btPoll
        interval: 10000
        running: true
        repeat: true
        // Idle backoff: radio off → re-check every 6th tick (60s).
        property int idleTicks: 0
        onTriggered: {
            if (root.bluetoothStatus === "off") {
                btPoll.idleTicks++
                if (btPoll.idleTicks < 6) return
                btPoll.idleTicks = 0
            } else {
                btPoll.idleTicks = 0
            }
            if (!btProc.running) btProc.running = true
        }
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
        command: ["sh", Quickshell.shellDir + "/scripts/media.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var fields = data.split("\u001f")
                if (fields.length !== 6) return
                if (fields[0]) root.mediaStatus = fields[0]

                const pos = Math.max(0, Number(fields[1]) / 1000 || 0)
                const len = Number(fields[2]) / 1000
                const artist = fields[3]
                const title = fields[4]
                const art = fields[5]
                const sig = fields.slice(3).join("\u001f")
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

                root.mediaPosMs = pos
            }
        }
    }

    Timer {
        id: mediaSync
        interval: 2000
        running: notifSvc.centerOpen
        repeat: true
        // Media lives in the notification center: no polling at all while
        // it's closed. While open, back off to every 5th tick (10s) when
        // nothing is playing.
        property int idleTicks: 0
        onTriggered: {
            if (root.mediaStatus === "none") {
                mediaSync.idleTicks++
                if (mediaSync.idleTicks < 5) return
                mediaSync.idleTicks = 0
            } else {
                mediaSync.idleTicks = 0
            }
            if (!mediaProc.running) mediaProc.running = true
        }
    }

    Timer {
        interval: 250
        running: root.mediaStatus === "Playing" && root.mediaLenMs > 0 && notifSvc.centerOpen
        repeat: true
        onTriggered: root.mediaPosMs = Math.min(root.mediaPosMs + interval, root.mediaLenMs)
    }

    function toggleCalendar(anchor, screen, window) {
        if (root.calDemand) {
            root.closeCalendar()
            return
        }
        root.closeOverlays()
        root.calEntry = { anchor, screen, window }
        root.calDemand = true
        if (calLoader.item)
            root.showCalendar()
    }

    function showCalendar() {
        const entry = root.calEntry
        if (!entry) return
        root.calEntry = null
        const calendar = calLoader.item
        calendar.anchorItem = entry.anchor
        calendar.anchorWin = entry.window
        calendar.screen = entry.screen
        calendar.open()
    }

    function closeCalendar() {
        if (!root.calDemand) return
        root.calEntry = null
        if (calLoader.item) {
            calUnload.restart()
            calLoader.item.close()
        }
        root.calDemand = false
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

    // QS-native wallpaper: one Background-layer window per screen.
    Variants {
        model: Quickshell.screens
        WallpaperBackground {
            modelData: modelData
        }
    }

    // Stagger the initial status queries so the bar can paint first.
    property var startupQueue: []
    Timer {
        id: startupSeq
        interval: 200
        repeat: true
        onTriggered: {
            if (root.startupQueue.length === 0) {
                startupSeq.stop()
                return
            }
            var job = root.startupQueue[0]
            root.startupQueue = root.startupQueue.slice(1)
            job()
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"])
        var _now = new Date()
        root.clockText = Qt.formatDateTime(_now, "hh:mm AP")
        root.clockDateText = Qt.formatDateTime(_now, "ddd MMM d")
        root.startupQueue = [
            () => { memProc.running = true },
            () => { netProc.running = true },
            () => { volProc.running = true },
            () => { btProc.running = true },
            () => { weatherProc.running = true },
            () => { prayerProc.running = true }
        ]
        startupSeq.start()
    }


    // Mango keyboard-layout source (mmsg). Idle unless running under mango
    // (MANGO_INSTANCE_SIGNATURE set by the compositor).
    component MangoIpc: Item {
        id: mango

        readonly property bool available: (Quickshell.env("MANGO_INSTANCE_SIGNATURE") || "").length > 0

        // Keyboard layout via `mmsg watch keyboardlayout`.
        property string keyboardLayoutName: ""

        function applyKbLayout(text) {
            try {
                var obj = JSON.parse(text)
                if (obj.layout && obj.layout !== mango.keyboardLayoutName)
                    mango.keyboardLayoutName = obj.layout
            } catch (e) { return }
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

        // Overview has no IPC flag; it shows up as active_tags [0].
        property bool overviewOpen: false

        Process {
            command: ["sh", "-c", "exec mmsg watch all-monitors 2>/dev/null"]
            running: mango.available
            stdout: SplitParser {
                onRead: data => {
                    if (!data) return
                    try {
                        var o = JSON.parse(data)
                        var list = o.monitors instanceof Array ? o.monitors : [o]
                        for (var i = 0; i < list.length; i++)
                            if ((list[i].active_tags || []).indexOf(0) >= 0) {
                                mango.overviewOpen = true
                                return
                            }
                        mango.overviewOpen = false
                    } catch (e) {}
                }
            }
        }
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
        property color tint: root.barColor("primary")
        property alias clickArea: pillArea

        readonly property color pillTextColor: root.contrastColor(pill.color)

        implicitWidth: pillRow.implicitWidth + pill.padX
        implicitHeight: root.pillHeight
        radius: root.pillRadius
        color: root.tonalPillColor(tint, true)
        border.width: 1
        border.color: root.withAlpha(Qt.color(root.barColor("outline_variant")), 0.38)
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
        layer.enabled: Quickshell.env("QS_NO_SHADOW") !== "1"
        layer.effect: MultiEffect {
            shadowEnabled: Quickshell.env("QS_NO_SHADOW") !== "1"
            shadowBlur: 0.8
            blurMax: 16
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
            shadowColor: Qt.rgba(0, 0, 0, 0.34)
            shadowOpacity: 0.8
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
                visible: pill.icon.length > 0
                text: pill.icon
                color: pill.pillTextColor
                Layout.alignment: Qt.AlignVCenter
                font.family: root.iconFont
                font.pixelSize: pill.iconSize
                font.weight: Font.Normal
            }

            Text {
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

        scale: pillArea.pressed ? 0.94 : pillArea.containsMouse ? 1.06 : 1.0
        Behavior on scale { Anim { type: Anim.BouncyFast } }
    }

    component DynamicPill: Rectangle {
        id: dc
        property int padX: 14
        property int iconSize: root.fontSize + 2
        // Auto static fallback when RAM is high or QS_NO_DYNAMIC=1.
        // Stops smoothing + shadows (the expensive parts), keeps text.
        readonly property bool staticMode: Quickshell.env("QS_NO_DYNAMIC") === "1" || root.memPercent >= 85
        // Pill gets its own `wifi` token (peach) — wifi strength is also
        // shown by the live arcs inside. Red only offline.
        readonly property color tint: root.networkConnected ? root.barColor("keymap") : root.barColor("error")
        readonly property color pillTextColor: root.contrastColor(dc.color)
        readonly property bool hovering: dcArea.containsMouse || dcArea.pressed
        // Smoothed signal so arcs animate live instead of jumping.
        // Disabled in staticMode: direct assignment, no animation churn.
        property real liveSignal: root.networkSignal
        Behavior on liveSignal { enabled: !dc.staticMode; Anim { type: Anim.StandardLarge } }

        implicitHeight: root.pillHeight
        radius: root.pillRadius
        color: root.tonalPillColor(dc.tint, true)
        border.width: 1
        border.color: root.withAlpha(Qt.color(root.barColor("outline_variant")), 0.38)
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
        layer.enabled: !dc.staticMode && Quickshell.env("QS_NO_SHADOW") !== "1"
        layer.effect: MultiEffect {
            shadowEnabled: !dc.staticMode && Quickshell.env("QS_NO_SHADOW") !== "1"
            shadowBlur: 0.8
            blurMax: 16
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
            shadowColor: Qt.rgba(0, 0, 0, 0.34)
            shadowOpacity: 0.8
        }

        implicitWidth: dcRow.implicitWidth + dc.padX
        Behavior on implicitWidth { enabled: !dc.staticMode; Anim { type: Anim.BouncyFast } }
        Behavior on color { CAnim { } }

        scale: dc.staticMode ? 1.0 : (dcArea.pressed ? 0.94 : dcArea.containsMouse ? 1.06 : 1.0)
        Behavior on scale { enabled: !dc.staticMode; Anim { type: Anim.BouncyFast } }

        Row {
            id: dcRow
            anchors.centerIn: parent
            spacing: 8

            Item {
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
                anchors.verticalCenter: parent.verticalCenter
                text: root.networkConnected ? (root.networkIp + "  ↓  " + root.formatSpeed(root.networkDown)) : "No net"
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
            radius: 10
            color: root.barColor("surface_container")
            border.width: 1
            border.color: root.withAlpha(Qt.color(root.barColor("outline_variant")), 0.38)
            opacity: dc.hovering ? 1 : 0
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            Text {
                id: tipText
                anchors.centerIn: parent
                text: root.charging ? "CHARGING" : root.batteryPercent + "%"
                color: !root.charging && root.batteryPercent < 15 ? root.readableColor(root.barColor("error"), tip.color) : root.contrastColor(tip.color)
                font.family: root.fontFamily
                font.pixelSize: root.fontSize - 1
                font.weight: Font.Normal
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
        locked: lockActive

        WlSessionLockSurface {
            color: "#000000"
            Item {
                anchors.fill: parent
                clip: true
                LockSurface {
                    anchors.fill: parent
                    rootRef: root
                    locked: root.lockActive
                    onUnlocked: {
                        lockActive = false
                        Quickshell.execDetached(["rm", "-f", "--", lockReq.path])
                    }
                }
            }
        }
    }

    function closeOverlays() {
        root.closeNotifCenter()
        appLauncherWin.dismiss()
        ytxWin.dismiss()
        whatsappWin.dismiss()
        clipWin.dismiss()
        notesWin.dismiss()
        wallpaperWin.dismiss()
        themeWin.dismiss()
        root.closeCalendar()
    }

    component OverlaySheet: PanelWindow {
        id: sheet
        required property string ns
        property bool open: false
        property Component content
        readonly property alias item: sheetLoader.item
        property bool ready: false
        property bool busy: false
        function setBusy(value) {
            if (!value && !sheet.open)
                unloadTimer.restart()
            sheet.busy = value
        }
        function hold() {
            if (sheet.open)
                unloadTimer.restart()
        }

        function dismiss() {
            if (!sheet.open) return
            sheet.hold()
            sheet.open = false
        }

        function toggle() {
            if (sheet.open) {
                sheet.dismiss()
                return
            }
            root.closeOverlays()
            sheet.open = true
        }
        WlrLayershell.namespace: sheet.ns
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: sheet.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        color: "transparent"
        visible: sheet.open || (sheetLoader.item ? sheetLoader.item.fadeProgress > 0.001 : false)

        Loader {
            id: sheetLoader
            anchors.fill: parent
            // Keep the content alive until the close animation finishes.
            active: sheet.open || unloadTimer.running || sheet.busy
            sourceComponent: sheet.content
            onStatusChanged: { if (status === Loader.Null) sheet.ready = false }
            onLoaded: {
                Qt.callLater(() => sheet.ready = true)
            }
        }

        Timer {
            id: unloadTimer
            interval: 700
            repeat: false
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            wallpaperWin.toggle()
        }
    }

    IpcHandler {
        target: "theme"
        function toggle(): void {
            themeWin.toggle()
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            appLauncherWin.toggle()
        }
    }

    OverlaySheet {
        id: appLauncherWin
        ns: "app-launcher"
        content: Component {
            AppLauncher {
                anchors.fill: parent
                rootRef: root
                active: appLauncherWin.open && appLauncherWin.ready
                onRequestClose: appLauncherWin.dismiss()
            }
        }
    }

    IpcHandler {
        target: "ytx"
        function toggle(): void {
            ytxWin.toggle()
        }
    }

    OverlaySheet {
        id: ytxWin
        ns: "ytx-picker"
        content: Component {
            YtXLauncher {
                anchors.fill: parent
                rootRef: root
                active: ytxWin.open && ytxWin.ready
                onRequestClose: ytxWin.dismiss()
            }
        }
    }

    IpcHandler {
        target: "whatsapp"
        function toggle(): void {
            whatsappWin.toggle()
        }
    }

    OverlaySheet {
        id: whatsappWin
        ns: "whatsapp-picker"
        content: Component {
            WhatsApp {
                anchors.fill: parent
                rootRef: root
                active: whatsappWin.open && whatsappWin.ready
                onRequestClose: whatsappWin.dismiss()
            }
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            clipWin.toggle()
        }
    }

    OverlaySheet {
        id: clipWin
        ns: "clipboard-picker"
        content: Component {
            Clipboard {
                anchors.fill: parent
                rootRef: root
                active: clipWin.open && clipWin.ready
                onRequestClose: clipWin.dismiss()
            }
        }
    }

    IpcHandler {
        target: "notes"
        function toggle(): void {
            notesWin.toggle()
        }
    }

    OverlaySheet {
        id: notesWin
        ns: "notes-picker"
        content: Component {
            Notes {
                anchors.fill: parent
                rootRef: root
                active: notesWin.open && notesWin.ready
                onRequestClose: notesWin.dismiss()
            }
        }
    }

    OverlaySheet {
        id: wallpaperWin
        ns: "wallpaper-picker"
        content: Component {
            WallpaperPicker {
                anchors.fill: parent
                visible_: wallpaperWin.open && wallpaperWin.ready

                surfaceColor: Qt.color(root.colorOf("surface_container"))
                borderColor: Qt.color(root.colorOf("outline_variant"))
                fgColor: Qt.color(root.colorOf("on_surface"))
                mutedColor: Qt.color(root.colorOf("on_surface_variant"))
                hoverColor: Qt.color(root.colorOf("surface_container_high"))
                selectedColor: Qt.color(root.colorOf("surface_container_highest"))
                accentColor: Qt.color(root.colorOf("primary"))
                iconFont: root.iconFont
                uiFont: root.uiFont
                onIsApplyingChanged: wallpaperWin.setBusy(isApplying)
                onRequestClose: wallpaperWin.dismiss()
            }
        }
    }

    OverlaySheet {
        id: themeWin
        ns: "theme-picker"
        content: Component {
            ThemePicker {
                anchors.fill: parent
                visible_: themeWin.open && themeWin.ready

                surfaceColor: Qt.color(root.colorOf("surface_container"))
                borderColor: Qt.color(root.colorOf("outline_variant"))
                fgColor: Qt.color(root.colorOf("on_surface"))
                mutedColor: Qt.color(root.colorOf("on_surface_variant"))
                hoverColor: Qt.color(root.colorOf("surface_container_high"))
                selectedColor: Qt.color(root.colorOf("surface_container_highest"))
                accentColor: Qt.color(root.colorOf("primary"))
                iconFont: root.iconFont
                uiFont: root.uiFont
                onIsApplyingChanged: themeWin.setBusy(isApplying)
                onRequestClose: themeWin.dismiss()
            }
        }
    }

    NotificationService {
        id: notifSvc
    }

    NotifPopups {
        rootRef: root
        svc: notifSvc
    }

    function toggleNotifCenter() {
        if (notifSvc.centerOpen) {
            root.closeNotifCenter()
        } else {
            root.closeOverlays()
            notifSvc.openCenter()
        }
    }

    function closeNotifCenter() {
        notifWin.hold()
        notifSvc.closeCenter()
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void {
            root.toggleNotifCenter()
        }
    }

    OverlaySheet {
        id: notifWin
        ns: "notification-center"
        open: notifSvc.centerOpen
        content: Component {
            NotifCenter {
                anchors.fill: parent
                rootRef: root
                svc: notifSvc
            }
        }

        onOpenChanged: {
            if (!open) return
            // Center-only data: fetch on open instead of polling at idle.
            if (!mediaProc.running) mediaProc.running = true
            if (!weatherWeekProc.running) weatherWeekProc.running = true
            root.refreshStorage()
            Qt.callLater(() => {
                if (notifWin.open && notifWin.item)
                    notifWin.item.forceActiveFocus()
            })
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
                    //  chrome     → neutral surface_container_high (volume base)
                    //  net        → peach `wifi` token            (net/battery)
                    //  input      → mauve `keymap` token          (keyboard)
                    //  audio      → grey→blue volTint, red on mute (volume)
                    //  pressure   → green→yellow→red memTint      (memory)
                    //  anchors    → sapphire primary_container    (workspaces)
                    //              pink tertiary_container        (clock)
                    //
                    //  Reading order: glance → faith → input → devices → navigate → sound → meters → time.
                    QIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: (mangoIpc.available && mangoIpc.overviewOpen) ? 1 : 0
                        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                        source: Qt.resolvedUrl("./assets/icons/y2k-starburst.svg")
                        color: "#ffffff"
                        iconSize: 22
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowBlur: 0.6
                            blurMax: 12
                            shadowColor: Qt.rgba(0, 0, 0, 0.9)
                            shadowOpacity: 0.9
                        }
                    }

                    Item {
                        width: 48
                        height: 1
                    }

                    Module {
                        id: weatherPill
                        enterOrder: 0
                        icon: root.weatherIsY2kMoon() ? "" : root.weatherGlyph()
                        iconSource: root.weatherIsY2kMoon() ? y2kMoonSource : null
                        iconSize: root.fontSize + 11
                        label: root.weatherText
                        tint: root.barColor("mauve")
                        visible: root.weatherText.length > 0
                        clickArea.onClicked: root.toggleNotifCenter()

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
                        enterOrder: 1
                        label: root.prayerText
                        tint: root.memTint(root.memPercent)
                        visible: root.prayerText.length > 0
                    }

                    Module {
                        id: kbPill
                        enterOrder: 2
                        iconSource: kbIconSource
                        label: root.shortLayout(mangoIpc.keyboardLayoutName)
                        tint: root.barColor("keymap")

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
                        tint: root.barColor("secondary_fixed_dim")
                        visible: root.bluetoothStatus === "connected"

                        Component {
                            id: bluetoothIconSource
                            BluetoothIcon { tint: btPill.pillTextColor }
                        }

                        clickArea.onClicked: btCmd.running = true
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

                        clickArea.onClicked: volCmd.enqueue(["mute"])
                        clickArea.onWheel: event => {
                            if (event.angleDelta.y === 0) return
                            const delta = event.angleDelta.y > 0 ? "+5%" : "-5%"
                            volCmd.enqueue(["set", delta])
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
                        enterOrder: 7
                    }

                    Rectangle {
                        id: clockPill
                        property int enterOrder: 8
                        property color tint: root.calDemand
                            ? root.mixColor(root.barColor("tertiary_container"), "#ffffff", 0.3)
                            : root.barColor("tertiary_container")
                        readonly property color pillTextColor: root.contrastColor(clockPill.color)
                        readonly property color dimTextColor: Qt.rgba(pillTextColor.r, pillTextColor.g, pillTextColor.b, 0.62)

                        implicitWidth: clockRow.implicitWidth + 20
                        implicitHeight: root.pillHeight
                        radius: root.pillRadius
                        color: root.tonalPillColor(tint, true)
                        border.width: 1
                        border.color: root.withAlpha(Qt.color(root.barColor("outline_variant")), 0.38)
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
                        layer.enabled: Quickshell.env("QS_NO_SHADOW") !== "1"
                        layer.effect: MultiEffect {
                            shadowEnabled: Quickshell.env("QS_NO_SHADOW") !== "1"
                            shadowBlur: 0.8
                            blurMax: 16
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 3
                            shadowColor: Qt.rgba(0, 0, 0, 0.34)
                            shadowOpacity: 0.8
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
                                font.weight: Font.Normal
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 3
                                radius: 10
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
                            onClicked: root.toggleCalendar(clockPill, bar.screen, bar)
                        }

                        scale: clockArea.pressed ? 0.94 : clockArea.containsMouse ? 1.06 : 1.0
                        Behavior on scale { Anim { type: Anim.BouncyFast } }
                    }
                }
            }
        }
    }

    property bool calDemand: false
    property var calEntry: null
    Loader {
        id: calLoader
        active: root.calDemand || calUnload.running
        sourceComponent: Component {
            Calendar {
                rootRef: root
            }
        }
        onLoaded: root.showCalendar()
    }

    Timer {
        id: calUnload
        interval: 700
        repeat: false
    }
}
