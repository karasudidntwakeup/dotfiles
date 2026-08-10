import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Niri._Ipc
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "colors.js" as Matugen

// Waybar-style bar for niri.
// Mirrors ~/.config/waybar (modules + Material You pill styling).
// Palette comes from matugen via colors.js (regenerated on wallpaper change).

// matugen 1786346875

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

    Process {
        id: netCmd
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
        onTriggered: root.clockText = Qt.formatDateTime(new Date(), "hh:mm AP")
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
                + "\nkblayout='" + root.shortLayout(Niri.currentKeyboardLayoutName) + "'"
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

        width: 48
        height: root.pillHeight  + 10
        radius: 20
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
                if (wsBtn.ws) Niri.dispatch(["focus-workspace", String(wsBtn.ws.idx)])
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            property var modelData
            screen: modelData

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
                for (const ws of Niri.workspaces.values) {
                    if (ws.output === outputName) list.push(ws)
                }
                list.sort((a, b) => a.idx - b.idx)
                workspaceList = list
            }

            Connections {
                target: Niri
                function onWorkspacesUpdated() { bar.refreshWorkspaces() }
                function onOutputsUpdated() { bar.refreshWorkspaces() }
            }

            Connections {
                target: Niri.workspaces
                function onValuesChanged() { bar.refreshWorkspaces() }
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
                    x: 0
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
                        label: root.shortLayout(Niri.currentKeyboardLayoutName)
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

                        clickArea.onClicked: {
                            netCmd.command = ["kitty", "impala"]
                            netCmd.running = true
                        }
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
                    }
                }
            }
        }
    }
}
