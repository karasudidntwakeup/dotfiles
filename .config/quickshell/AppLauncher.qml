import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: launcher

    property var rootRef: null
    property bool active: false

    signal requestClose()

    readonly property int cardWidth: 560
    readonly property int rowHeight: 46
    readonly property int maxRows: 6
    readonly property int searchHeight: 40
    readonly property int pad: 14
    readonly property int cornerRadius: 20

    // Light mode: matugen `_light` (dark) card, white text. Dark: pastel card.
    readonly property string cardTile: "secondary_fixed"
    readonly property color cardColor: rootRef
        ? (rootRef.qsLight
            ? (rootRef.pillColor(cardTile))
            : rootRef.colorOf(cardTile))
        : "#f3dfd1"
    readonly property color cardBorder: rootRef
        ? rootRef.withAlpha(rootRef.colorOf("outline_variant"),
            rootRef.qsLight ? 0.5 : 0.35)
        : "#00000000"

    // Foreground mirrors Module.pillTextColor.
    readonly property color fg: rootRef
        ? (rootRef.qsLight ? rootRef.qsPillFg : rootRef.textColor)
        : "#000000"
    readonly property color accent: fg
    readonly property color accentText: rootRef && rootRef.qsLight
        ? "#000000" : "#ffffff"
    readonly property color selectedFg: accentText
    readonly property string iconFont: rootRef ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string fontFamily: rootRef ? rootRef.fontFamily : "Ndot 57"
    readonly property string uiFont: rootRef ? rootRef.uiFont : "Inter"
    readonly property int fontSize: rootRef ? rootRef.fontSize : 13
    readonly property string terminalCommand: rootRef && rootRef.terminalCommand ? rootRef.terminalCommand : "foot"

    function alpha(c: color, a: double): color {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // Entrance/exit: pops up from the bottom edge.
    property real animProgress: launcher.active ? 1.0 : 0.0
    Behavior on animProgress {
        NumberAnimation {
            duration: launcher.active ? 320 : 220
            easing.type: Easing.OutCubic
        }
    }

    readonly property int bottomMargin: 24
    readonly property real slideOffset: (1.0 - launcher.animProgress)
        * (launcher.bottomMargin * 2 + card.height)

    opacity: launcher.animProgress

    property var apps: []
    ListModel {
        id: listModel
    }

    Connections {
        target: DesktopEntries && DesktopEntries.applications ? DesktopEntries.applications : null
        function onValuesChanged() { launcher.reloadApps() }
        function onCountChanged() { launcher.reloadApps() }
    }

    onActiveChanged: {
        if (launcher.active) {
            launcher.reloadApps()
            searchField.text = ""
            launcher.filterApps("")
            focusRequest.restart()
        }
    }

    Component.onCompleted: launcher.reloadApps()

    Timer {
        id: focusRequest
        interval: 40
        repeat: false
        onTriggered: searchField.forceActiveFocus()
    }

    function reloadApps() {
        var arr = []
        if (DesktopEntries && DesktopEntries.applications && DesktopEntries.applications.values) {
            var entries = DesktopEntries.applications.values
            for (var i = 0; i < entries.length; i++) {
                var e = entries[i]
                if (e.noDisplay) continue
                arr.push({
                    name: e.name,
                    desc: e.comment || "",
                    icon: e.icon || "",
                    desktopId: e.id,
                    isCommand: false,
                    isCalc: false,
                    cmd: "",
                    calcResult: "",
                    isEmpty: false
                })
            }
        }
        arr.sort(function(a, b) { return a.name.localeCompare(b.name) })
        launcher.apps = arr
        if (launcher.active) launcher.filterApps(searchField.text)
    }

    function isSubsequence(sub, str) {
        var i = 0
        var j = 0
        while (i < sub.length && j < str.length) {
            if (sub[i] === str[j]) i++
            j++
        }
        return i === sub.length
    }

    function evaluateMath(expr) {
        if (!expr) return null
        var trimmed = expr.trim()
        if (trimmed.length === 0 || trimmed.startsWith(">")) return null

        var parsed = trimmed
            .replace(/×/g, "*")
            .replace(/÷/g, "/")
            .replace(/\bpi\b/gi, "Math.PI")
            .replace(/\be\b/gi, "Math.E")
            .replace(/\bsqrt\b/gi, "Math.sqrt")
            .replace(/\bsin\b/gi, "Math.sin")
            .replace(/\bcos\b/gi, "Math.cos")
            .replace(/\btan\b/gi, "Math.tan")
            .replace(/\babs\b/gi, "Math.abs")
            .replace(/\blog\b/gi, "Math.log")
            .replace(/\bpow\b/gi, "Math.pow")
            .replace(/\^/g, "**")

        var testStr = parsed.replace(/Math\.(PI|E|sqrt|sin|cos|tan|abs|log|pow)/g, "")
        if (!/^[\d\s\+\-\*\/\%\(\)\.\,]+$/.test(testStr)) return null

        if (!/[\+\-\*\/\%\^]/.test(trimmed) && !/\b(sqrt|sin|cos|tan|abs|log|pow|pi|e)\b/i.test(trimmed)) {
            return null
        }

        try {
            var res = Function('"use strict"; return (' + parsed + ')')()
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                return Number(Math.round(res * 1e12) / 1e12).toString()
            }
        } catch (e) {
            return null
        }
        return null
    }

    function filterApps(text) {
        var raw = text.trim()
        var q = raw.toLowerCase()
        listModel.clear()

        if (raw.startsWith(">")) {
            var cmd = raw.substring(1).trim()
            listModel.append({
                name: cmd.length > 0 ? "> " + cmd : "> ...",
                desc: cmd.length > 0 ? "Run in terminal" : "Type a command to execute",
                icon: "",
                desktopId: "",
                isCommand: cmd.length > 0,
                isCalc: false,
                cmd: cmd,
                calcResult: "",
                isEmpty: false
            })
        }

        var mathRes = launcher.evaluateMath(raw)
        if (mathRes !== null) {
            listModel.append({
                name: raw + " = " + mathRes,
                desc: "Copy result to clipboard",
                icon: "",
                desktopId: "",
                isCommand: false,
                isCalc: true,
                cmd: "",
                calcResult: mathRes,
                isEmpty: false
            })
        }

        if (!raw.startsWith(">")) {
            for (var i = 0; i < launcher.apps.length; i++) {
                var app = launcher.apps[i]
                var nameLower = app.name.toLowerCase()
                var q0 = q.length === 0
                var qn = q0 || nameLower.indexOf(q) >= 0
                var qd = q0 || (app.desc.length > 0 && app.desc.toLowerCase().indexOf(q) >= 0)
                var qs = q0 || launcher.isSubsequence(q, nameLower)
                if (!qn && !qd && !qs) continue
                listModel.append({
                    name: app.name,
                    desc: app.desc,
                    icon: app.icon,
                    desktopId: app.desktopId,
                    isCommand: false,
                    isCalc: false,
                    cmd: "",
                    calcResult: "",
                    isEmpty: false
                })
            }
        }

        if (listModel.count === 0) {
            listModel.append({
                name: "No results",
                desc: raw.startsWith(">") ? "Command mode" : "Try a different search",
                icon: "",
                desktopId: "",
                isCommand: false,
                isCalc: false,
                cmd: "",
                calcResult: "",
                isEmpty: true
            })
        }

        appList.currentIndex = 0
    }

    function activate() {
        var idx = appList.currentIndex
        if (idx < 0 || idx >= listModel.count) return
        var it = listModel.get(idx)
        if (it.isEmpty) return

        if (it.isCommand && it.cmd.length > 0) {
            Quickshell.execDetached([launcher.terminalCommand, "bash", "-c", it.cmd])
            launcher.requestClose()
            return
        }
        if (it.isCalc) {
            Quickshell.execDetached(["wl-copy", "--", it.calcResult])
            launcher.requestClose()
            return
        }
        if (it.desktopId.length > 0) {
            var entry = DesktopEntries.byId(it.desktopId)
            if (entry) entry.execute()
        }
        launcher.requestClose()
    }

    Rectangle {
        id: card
        width: launcher.cardWidth
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.floor(parent.height - card.height - launcher.bottomMargin) + launcher.slideOffset
        height: contentColumn.implicitHeight + launcher.pad * 2
        radius: launcher.cornerRadius
        color: launcher.cardColor
        border.width: 1
        border.color: launcher.cardBorder
        clip: true

        Column {
            id: contentColumn
            x: launcher.pad
            y: launcher.pad
            width: launcher.cardWidth - launcher.pad * 2
            spacing: 8

            // Search field
            Rectangle {
                id: searchBox
                width: parent.width
                height: launcher.searchHeight
                radius: launcher.searchHeight / 2
                color: launcher.alpha(launcher.fg, 0.08)
                border.width: 1
                border.color: searchField.activeFocus
                    ? launcher.alpha(launcher.fg, 0.4)
                    : launcher.alpha(launcher.fg, 0.12)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 6
                    spacing: 8

                    Text {
                        text: "󰀂"
                        color: launcher.alpha(launcher.fg, 0.55)
                        font.family: launcher.iconFont
                        font.pixelSize: launcher.fontSize + 1
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: launcher.fg
                        font.family: launcher.uiFont
                        font.pixelSize: launcher.fontSize + 1
                        font.weight: Font.Medium
                        placeholderText: "Search apps    >  runs a command"
                        placeholderTextColor: launcher.alpha(launcher.fg, 0.4)
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter
                        background: Item {}

                        onTextEdited: launcher.filterApps(searchField.text)

                        Keys.onDownPressed: event => {
                            if (appList.currentIndex < listModel.count - 1) appList.currentIndex++
                            event.accepted = true
                        }
                        Keys.onUpPressed: event => {
                            if (appList.currentIndex > 0) appList.currentIndex--
                            event.accepted = true
                        }
                        Keys.onReturnPressed: event => {
                            launcher.activate()
                            event.accepted = true
                        }
                        Keys.onEscapePressed: event => {
                            launcher.requestClose()
                            event.accepted = true
                        }
                    }

                    Rectangle {
                        id: clearBtn
                        visible: searchField.text.length > 0
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 11
                        color: clearHover.containsMouse
                            ? launcher.alpha(launcher.fg, 0.25)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: launcher.fg
                            font.family: launcher.iconFont
                            font.pixelSize: launcher.fontSize
                        }

                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = ""
                                searchField.forceActiveFocus()
                                launcher.filterApps("")
                            }
                        }
                    }
                }
            }

            // App list
            Item {
                id: listContainer
                width: parent.width
                height: Math.min(listModel.count, launcher.maxRows) * launcher.rowHeight
                clip: true

                ListView {
                    id: appList
                    anchors.fill: parent
                    model: listModel
                    spacing: 4
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    // Sliding selection highlight (renders behind the rows).
                    Rectangle {
                        id: morphHighlight
                        parent: appList.contentItem
                        z: 0
                        visible: appList.count > 0 && appList.currentIndex >= 0 && appList.currentItem !== null
                        width: appList.width
                        height: launcher.rowHeight
                        radius: 9
                        color: launcher.accent

                        readonly property real targetY: (appList.currentIndex >= 0 && appList.currentItem !== null)
                            ? appList.currentItem.y : 0
                        y: targetY

                        Behavior on y {
                            NumberAnimation {
                                duration: 240
                                easing.type: Easing.OutQuint
                            }
                        }
                    }

                    delegate: Item {
                        required property int index
                        required property string name
                        required property string desc
                        required property string icon
                        required property string desktopId
                        required property bool isCommand
                        required property bool isCalc
                        required property bool isEmpty
                        required property string cmd
                        required property string calcResult

                        readonly property bool isSelected: appList.currentIndex === index

                        width: appList.width
                        height: launcher.rowHeight
                        z: 1

                        // Hover fill (transparent, lets the sliding highlight show).
                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: rowHover.containsMouse && !isSelected
                                ? launcher.alpha(launcher.fg, 0.08)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 12

                            Item {
                                id: iconBox
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: isSelected
                                        ? launcher.alpha(launcher.accentText, 0.14)
                                        : launcher.alpha(launcher.fg, 0.10)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Image {
                                    id: appIcon
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    visible: !isEmpty && !isCommand && !isCalc
                                        && icon.length > 0 && status === Image.Ready
                                    source: icon.length > 0 ? "image://icon/" + icon : ""
                                    sourceSize: Qt.size(64, 64)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    mipmap: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !appIcon.visible
                                    text: isEmpty ? "" : isCommand ? ">"
                                        : isCalc ? "="
                                        : name.charAt(0).toUpperCase()
                                    color: isSelected ? launcher.selectedFg : launcher.fg
                                    font.family: launcher.fontFamily
                                    font.pixelSize: launcher.fontSize + 3
                                    font.weight: Font.Black
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: name
                                    elide: Text.ElideRight
                                    font.family: launcher.fontFamily
                                    font.pixelSize: launcher.fontSize + (isSelected ? 1 : 0)
                                    font.weight: isSelected ? Font.Black : Font.Medium
                                    color: isSelected ? launcher.selectedFg : launcher.fg
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Text {
                                    width: parent.width
                                    visible: !isEmpty && desc.length > 0
                                    text: desc
                                    elide: Text.ElideRight
                                    font.family: launcher.uiFont
                                    font.pixelSize: Math.max(9, launcher.fontSize - 2)
                                    color: isSelected
                                        ? launcher.alpha(launcher.selectedFg, 0.75)
                                        : launcher.alpha(launcher.fg, 0.55)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                appList.currentIndex = index
                                launcher.activate()
                            }
                        }
                    }
                }
            }
        }
    }
}