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

    function popupSurface(name) {
        var v = colorFile.paletteMap[name + "_light"]
        return v === undefined ? colorOf(name) : v
    }

    readonly property color primary: colorOf("primary")
    readonly property color error: colorOf("error")
    readonly property color outlineVariant: colorOf("outline_variant")

    readonly property string fontFamily: "Ndot 57"
    readonly property string uiFont: "Inter"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int fontSize: 13

    readonly property int barHeight: 36
    readonly property int pillHeight: 32
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
            root.prayerProc.running = true
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
    property string mediaInfo: ""

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
                var info = fields.slice(1, n - 3).join("|").trim()
                var trackChanged = info && info !== root.mediaInfo
                if (trackChanged) root.mediaInfo = info

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
        property int padX: 14
        property int iconSize: root.fontSize + 2
        property color tint: root.primary
        property alias clickArea: pillArea
        property alias wheelArea: pillArea

        readonly property color pillTextColor: root.luminance(tint) > 0.5 ? "#000000" : "#ffffff"

        implicitWidth: pillRow.implicitWidth + pill.padX
        implicitHeight: root.pillHeight
        radius: 10
        color: tint
        border.width: 0

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 4

            Loader {
                visible: pill.iconSource != null
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: pill.iconSource
            }

            Text {
                id: pillIcon
                visible: pill.icon.length > 0
                text: pill.icon
                color: pill.pillTextColor
                anchors.verticalCenter: parent.verticalCenter
                font.family: root.iconFont
                font.pixelSize: pill.iconSize
                font.weight: Font.Normal
            }

            Text {
                id: pillText
                text: pill.label
                color: pill.pillTextColor
                anchors.verticalCenter: parent.verticalCenter
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
    }

    component BoltGlyph: Canvas {
        id: boltG
        property color tintColor: bat.tint
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

    component BatteryPill: Rectangle {
        id: bat
        property color tint: root.batteryTint(root.batteryPercent)
        property int padX: 14
        property int icoW: 26
        property int icoH: 18

        readonly property color fg: root.colorOf("on_primary")
        readonly property color stroke: root.mixColor(bat.tint, "#000000", 0.5)

        implicitWidth: batRow.implicitWidth + bat.padX
        implicitHeight: root.pillHeight
        radius: 10
        color: tint
        border.width: 0

        Behavior on color { ColorAnimation { duration: 250 } }

        property int iconVariant: 0 // 0 = solid bar, 1 = material outline + cap, 2 = segmented level bars

        Component {
            id: batIconSolid
            Item {
                implicitWidth: bat.icoW
                implicitHeight: bat.icoH

                Rectangle {
                    anchors.fill: parent
                    radius: parent.height / 2
                    color: root.mixColor(bat.tint, "#000000", 0.35)
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 1.5
                    anchors.rightMargin: 1.5
                    anchors.bottomMargin: 1.5
                    readonly property real fillRatio: Math.min(1, root.batteryPercent / 100)
                    height: Math.max(0, (parent.height - 3) * fillRatio)
                    radius: (parent.width - 3) / 2
                    color: "#000000"
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }

                BoltGlyph {
                    tintColor: bat.tint
                    visible: root.charging
                }
            }
        }

        Component {
            id: batIconOutline
            Item {
                implicitWidth: 9
                implicitHeight: 20

                Rectangle {
                    anchors.bottom: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 4
                    height: 2
                    radius: 1
                    color: bat.stroke
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    border.width: 2
                    border.color: bat.stroke
                    color: "transparent"
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    anchors.bottomMargin: 2
                    readonly property real fillRatio: Math.min(1, root.batteryPercent / 100)
                    height: Math.max(0, (parent.height - 4) * fillRatio)
                    radius: 3
                    color: root.mixColor(bat.tint, "#ffffff", 0.45)
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }

                BoltGlyph {
                    tintColor: bat.tint
                    visible: root.charging
                }
            }
        }

        Component {
            id: batIconSegmented
            Rectangle {
                implicitWidth: 10
                implicitHeight: 20
                radius: 2
                border.width: 1
                border.color: root.mixColor(bat.tint, "#000000", 0.3)
                color: "transparent"

                Column {
                    anchors.centerIn: parent
                    spacing: 1.6

                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: 7
                            height: 3.2
                            radius: 1.6
                            readonly property bool lit: {
                                if (root.charging) return true
                                return Math.round(root.batteryPercent) > (3 - index) * 25
                            }
                            color: lit
                                ? "#000000"
                                : root.mixColor(bat.tint, "#000000", 0.18)
                        }
                    }
                }

                BoltGlyph {
                    tintColor: bat.tint
                    visible: root.charging
                }
            }
        }

        Row {
            id: batRow
            anchors.centerIn: parent
            spacing: 5

            Loader {
                id: batIconLoader
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: [
                    batIconSolid,
                    batIconOutline,
                    batIconSegmented
                ][Math.max(0, Math.min(2, bat.iconVariant))]
            }

            Text {
                text: root.batteryPercent + "%"
                color: bat.fg
                anchors.verticalCenter: parent.verticalCenter
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.weight: Font.Normal
            }
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

    component NetworkPill: Rectangle {
        id: net
        property color tint: root.networkConnected ? root.signalTint(root.networkSignal) : root.pillColor("error")
        readonly property color pillTextColor: root.luminance(tint) > 0.5 ? "#000000" : "#ffffff"
        property int iconSize: root.fontSize + 2

        implicitWidth: netRow.implicitWidth + 14
        implicitHeight: root.pillHeight
        radius: 10
        color: tint

        Row {
            id: netRow
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: "\uF1EB"
                color: net.pillTextColor
                anchors.verticalCenter: parent.verticalCenter
                font.family: root.iconFont
                font.pixelSize: net.iconSize
            }

            Text {
                text: root.networkConnected
                    ? (root.networkIp + "  ↓  " + root.formatSpeed(root.networkDown) || root.networkText)
                    : "No net"
                color: net.pillTextColor
                anchors.verticalCenter: parent.verticalCenter
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.weight: Font.Normal
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
        readonly property real dotW: 13
        readonly property real activeW: 24
        readonly property real dotH: 13
        readonly property real dotSpacing: 6
        readonly property real pillPad: 10
        readonly property real dotRadius: 7

        function contentWidth() {
            return (count - 1) * dotW + activeW + dotSpacing * (count - 1)
        }

        width: contentWidth() + pillPad * 2
        height: root.pillHeight
        radius: 10
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

    function openWallpaperPicker() {
        if (wallPicker.visible || openAnim.running) return
        notifSvc.closeCenter()
        root.launcherActive = false
        root.ytxActive = false
        root.clipboardActive = false
        root.whatsappActive = false
        root.notesActive = false
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

    function openAppLauncher() { root.launcherActive = true; notifSvc.closeCenter(); root.closeYtx(); root.closeClipboard(); root.closeWhatsApp(); root.closeNotes() }
    function closeAppLauncher() { root.launcherActive = false }
    function toggleAppLauncher() { root.launcherActive = !root.launcherActive }

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

    function openYtx() { root.ytxActive = true; notifSvc.closeCenter(); root.closeAppLauncher(); root.closeClipboard(); root.closeWhatsApp(); root.closeNotes() }
    function closeYtx() { root.ytxActive = false }
    function toggleYtx() { root.ytxActive = !root.ytxActive }

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

    function openWhatsApp() { root.whatsappActive = true; notifSvc.closeCenter(); root.closeAppLauncher(); root.closeYtx(); root.closeClipboard(); root.closeNotes() }
    function closeWhatsApp() { root.whatsappActive = false }
    function toggleWhatsApp() { root.whatsappActive = !root.whatsappActive }

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

    function openClipboard() { root.clipboardActive = true; notifSvc.closeCenter(); root.closeAppLauncher(); root.closeYtx(); root.closeWhatsApp(); root.closeNotes() }
    function closeClipboard() { root.clipboardActive = false }
    function toggleClipboard() { root.clipboardActive = !root.clipboardActive }

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

    function openNotes() { root.notesActive = true; notifSvc.closeCenter(); root.closeAppLauncher(); root.closeYtx(); root.closeClipboard(); root.closeWhatsApp() }
    function closeNotes() { root.notesActive = false }
    function toggleNotes() { root.notesActive = !root.notesActive }

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
        if (!notifSvc.centerOpen) {
            root.launcherActive = false
            root.ytxActive = false
            root.clipboardActive = false
            root.whatsappActive = false
            root.closeWallpaperPicker()
        }
        notifSvc.toggleCenter()
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

            Component.onCompleted: refreshWorkspaces()

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

                    NetworkPill {
                        id: netPill
                        iconSize: root.fontSize
                    }

                    BatteryPill {
                        id: batPill
                        icoW: 22
                        icoH: 15
                    }

                    Module {
                        id: clockPill
                        icon: "󰥔"
iconSize: root.fontSize + 3
                        label: root.clockText
                        tint: root.pillColor("tertiary_container")

                        clickArea.onClicked: calPopup.open()
                    }
                }
            }

            PopupWindow {
            id: calPopup
            visible: false
            grabFocus: true
            implicitWidth: 250
            color: "transparent"

            mask: Region {
                Region { item: calPopupBody; radius: 25 }
                Region { item: timerSection }
            }

                property bool dismissedByOutside: false
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

                property bool expanded: false

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

                    if (calPopup.selectedKey === key && calPopup.expanded) {
                        calPopup.expanded = false
                        return
                    }
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

                readonly property int collapsedHeight: 312
                readonly property int timerGap: 8
                readonly property int timerHeight: 64
                implicitHeight: collapsedHeight + calPopup.editorHeight + 6
                    + calPopup.timerGap + calPopup.timerHeight

                readonly property color popupFg: root.luminance(Qt.color(clockPill.tint)) > 0.45 ? "#000000" : "#ffffff"

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
                    color: clockPill.tint
                    border.width: 1
                    border.color: root.withAlpha(root.outlineVariant, 0.35)
                    clip: true

                    SurfaceGradient {
                        anchors.fill: parent
                        inset: 1
                        radius: 25
                        color: clockPill.tint
                    }
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
                                    color: calPopup.popupFg
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
                                    color: calPopup.popupFg
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
                                color: calPopup.popupFg
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
                                color: calPopup.popupFg
                                font.family: root.iconFont
                                font.pixelSize: root.fontSize + 3
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")
                                color: calPopup.popupFg
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize + 2
                                font.weight: Font.Normal
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
                                            ? calPopup.popupFg
                                            : dayHover.containsMouse
                                                ? root.withAlpha(calPopup.popupFg, 0.18)
                                                : isToday ? root.withAlpha(calPopup.popupFg, 0.4) : "transparent"

                                        Text {
                                            id: dayNum
                                            anchors.centerIn: parent
                                            visible: day > 0
                                            text: day
                                            color: isSelected ? root.onTextColor : calPopup.popupFg
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fontSize
                                            font.weight: Font.Normal
                                        }

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 3
                                            visible: hasNote
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: isSelected ? root.onTextColor : calPopup.popupFg
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
                                    color: calPopup.popupFg
                                    font.family: root.iconFont
                                    font.pixelSize: root.fontSize + 1
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: calPopup.selectedDateLabel()
                                    color: calPopup.popupFg
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    font.weight: Font.Normal
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
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 2
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: "󰅖"
                                    color: calPopup.popupFg
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
                                        ? root.withAlpha(calPopup.popupFg, 0.35)
                                        : root.withAlpha(calPopup.popupFg, 0.22)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: calPopup.popupFg
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 2
                                        font.weight: Font.Normal
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
                                        : root.withAlpha(calPopup.popupFg, calPopup.selectedEntryId >= 0 ? 0.12 : 0.05)
                                    enabled: calPopup.selectedEntryId >= 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: "-"
                                        color: calPopup.selectedEntryId >= 0 ? root.error : root.withAlpha(calPopup.popupFg, 0.3)
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 2
                                        font.weight: Font.Normal
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
                                    color: calPopup.popupFg
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
                                        color: root.withAlpha(calPopup.popupFg, 0.3)
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
                                            color: root.withAlpha(calPopup.popupFg, saved ? 0.05 : 0.08)
                    border.width: 0
                                            border.color: isSelected
                                                ? calPopup.popupFg
                                                : saved ? "transparent" : root.withAlpha(calPopup.popupFg, 0.15)

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
                                                        ? (todoCheckArea.containsMouse ? root.withAlpha(calPopup.popupFg, 0.8) : calPopup.popupFg)
                                                        : (todoCheckArea.containsMouse ? root.withAlpha(calPopup.popupFg, 0.08) : "transparent")
                                                    border.width: 1
                                                    border.color: entryDone ? calPopup.popupFg : root.withAlpha(calPopup.popupFg, 0.35)

                                                    Behavior on color { ColorAnimation { duration: 120 } }

                                                    Text {
                                                        visible: entryDone
                                                        anchors.centerIn: parent
                                                        text: "󰄲"
                                                        color: root.onTextColor
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
                                                    color: calPopup.popupFg
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
                                                    color: calPopup.popupFg
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
                                                    color: saveHover.containsMouse ? root.withAlpha(calPopup.popupFg, 0.25) : "transparent"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰄴"
                                                        color: calPopup.popupFg
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
                        color: clockPill.tint
                        border.width: 1
                        border.color: root.withAlpha(root.outlineVariant, 0.35)
                        opacity: 0

                        SurfaceGradient {
                            anchors.fill: parent
                            inset: 1
                            radius: 25
                            color: clockPill.tint
                        }

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
                                    color: calPopup.popupFg
                                    font.family: root.iconFont
                                    font.pixelSize: root.fontSize + 2
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 40
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: root.fmtTimer(root.timerRemainingMs)
                                    color: root.timerRemainingMs <= 0 ? root.error : calPopup.popupFg
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize + 8
                                    font.weight: Font.Normal
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
                                        ? root.withAlpha(calPopup.popupFg, 0.35)
                                        : root.withAlpha(calPopup.popupFg, 0.18)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "-"
                                        color: calPopup.popupFg
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 2
                                        font.weight: Font.Normal
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
                                        ? root.withAlpha(calPopup.popupFg, 0.35)
                                        : root.withAlpha(calPopup.popupFg, 0.18)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: calPopup.popupFg
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 2
                                        font.weight: Font.Normal
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
                                        ? root.withAlpha(calPopup.popupFg, 0.45)
                                        : root.withAlpha(calPopup.popupFg, 0.28)

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.timerRunning ? "󰏤" : "󰐊"
                                        color: calPopup.popupFg
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
                                        : root.withAlpha(calPopup.popupFg, 0.08)

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
