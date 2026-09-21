import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell

Item {
    id: launcher

    property var rootRef: null
    property bool active: false

    signal requestClose()

    // Compact bottom drawer, large rounding.
    readonly property int cardWidth: 440
    readonly property int rowHeight: 44
    readonly property int maxRows: 5
    readonly property int searchHeight: 42
    readonly property int pad: 12
    readonly property int cornerRadius: 0
    readonly property int listSpacing: 4

    readonly property string cardTile: "launcher_card"
    readonly property color cardColor: {
        var base = rootRef
            ? (rootRef.qsLight
                ? rootRef.pillColor(cardTile)
                : rootRef.colorOf(cardTile))
            : "#f3dfd1"
        if (rootRef && rootRef.mixColor && rootRef.colorOf)
            base = rootRef.mixColor(base, rootRef.colorOf("surface_container_highest"), 0.2)
        return Qt.darker(base, 1.2)
    }
    readonly property color cardBorder: rootRef
        ? rootRef.withAlpha(rootRef.colorOf("widget_border"),
            rootRef.qsLight ? 0.7 : 0.5)
        : "#00000000"

    readonly property color fg: rootRef
        ? rootRef.contrastColor(launcher.cardColor)
        : "#000000"
    // Caelestia selection is a subtle on-surface overlay, not an accent block.
    readonly property color highlight: rootRef ? rootRef.withAlpha(launcher.fg, 0.08) : "#00000014"
    readonly property color hoverFill: rootRef ? rootRef.withAlpha(launcher.fg, 0.05) : "#0000000d"
    readonly property color descColor: rootRef ? rootRef.withAlpha(launcher.fg, 0.6) : "#888888"

    readonly property string fontFamily: uiFont
    readonly property string uiFont: rootRef && rootRef.uiFont ? rootRef.uiFont : "Geist"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13
    readonly property string terminalCommand: rootRef ? rootRef.terminalCommand : "kitty"

    property real animProgress: launcher.active ? 1.0 : 0.0
    Behavior on animProgress {
        Anim { type: Anim.Bouncy }
    }

    readonly property int bottomMargin: 24

    opacity: launcher.animProgress

    property var apps: []
    ListModel {
        id: listModel
    }

    Connections {
        target: DesktopEntries && DesktopEntries.applications ? DesktopEntries.applications : null
        function onValuesChanged() { launcher.reloadApps() }
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
                    calcResult: ""
                })
            }
        }
        arr.sort(function(a, b) { return a.name.localeCompare(b.name) })
        launcher.apps = arr
        if (launcher.active) launcher.filterApps(searchField.text)
    }

    // Local fallback for entries whose theme icon is missing/broken.
    // File managers (pcmanfm et al.) get a folder; everything else sparkles.
    function fallbackIconSource(icon, name, desktopId) {
        var s = ((icon || "") + " " + (name || "") + " " + (desktopId || "")).toLowerCase()
        if (s.indexOf("pcmanfm") >= 0 || s.indexOf("thunar") >= 0
                || s.indexOf("nautilus") >= 0 || s.indexOf("dolphin") >= 0
                || s.indexOf("nemo") >= 0 || s.indexOf("caja") >= 0
                || s.indexOf("file manager") >= 0 || s.indexOf("filemanager") >= 0
                || s.indexOf("system-file-manager") >= 0)
            return Qt.resolvedUrl("../assets/icons/y2k-folder.svg")
        return Qt.resolvedUrl("../assets/icons/y2k-sparkle.svg")
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
            // Caelestia action-prefix mode: only the command row.
            if (raw.toLowerCase().startsWith(">calc ")) {
                var mathRes = launcher.evaluateMath(raw.substring(6))
                listModel.append({
                    name: mathRes !== null ? raw.substring(6).trim() + " = " + mathRes : "Type an expression to calculate",
                    desc: mathRes !== null ? "Copy result to clipboard" : ">calc <expression>",
                    icon: "",
                    desktopId: "",
                    isCommand: false,
                    isCalc: mathRes !== null,
                    cmd: "",
                    calcResult: mathRes !== null ? mathRes : ""
                })
            } else {
                listModel.append({
                    name: cmd.length > 0 ? "> " + cmd : "> ...",
                    desc: cmd.length > 0 ? "Run in terminal" : "Type a command to execute",
                    icon: "",
                    desktopId: "",
                    isCommand: cmd.length > 0,
                    isCalc: false,
                    cmd: cmd,
                    calcResult: ""
                })
            }
        } else {
            var mathRes2 = launcher.evaluateMath(raw)
            if (mathRes2 !== null) {
                listModel.append({
                    name: raw + " = " + mathRes2,
                    desc: "Copy result to clipboard",
                    icon: "",
                    desktopId: "",
                    isCommand: false,
                    isCalc: true,
                    cmd: "",
                    calcResult: mathRes2
                })
            }

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
                    calcResult: ""
                })
            }
        }

        appList.currentIndex = listModel.count > 0 ? 0 : -1
    }

    function activate() {
        var idx = appList.currentIndex
        if (idx < 0 || idx >= listModel.count) return
        var it = listModel.get(idx)

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
        y: Math.floor(parent.height - card.height - launcher.bottomMargin)
        height: contentColumn.implicitHeight + launcher.pad * 2
        Behavior on height { Anim { type: Anim.BouncyFast } }
        radius: launcher.cornerRadius
        color: launcher.cardColor
        border.width: 1
        border.color: launcher.cardBorder
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

        // Caelestia drawer motion: rise + scale up + fade (bouncy driver
        // overshoots, so the card pops past 1.0 for a frame).
        scale: 0.82 + 0.18 * launcher.animProgress
        transformOrigin: Item.Bottom
        transform: Translate {
            y: (1.0 - launcher.animProgress) * 24
        }

        Column {
            id: contentColumn
            x: launcher.pad
            y: launcher.pad
            width: launcher.cardWidth - launcher.pad * 2
            spacing: 12

            // Caelestia order: results on top, search bar anchored at bottom.
            Item {
                id: listContainer
                width: parent.width
                height: appList.count > 0
                    ? Math.min(appList.count, launcher.maxRows) * launcher.rowHeight
                        + Math.max(0, Math.min(appList.count, launcher.maxRows) - 1) * launcher.listSpacing
                    : emptyState.implicitHeight
                clip: true

                ListView {
                    id: appList
                    anchors.fill: parent
                    visible: count > 0
                    model: listModel
                    spacing: launcher.listSpacing
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    highlightFollowsCurrentItem: false
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: height
                    highlightRangeMode: ListView.ApplyRange

                    // Caelestia sliding highlight.
                    Rectangle {
                        id: morphHighlight
                        parent: appList.contentItem
                        z: 0
                        visible: appList.count > 0 && appList.currentIndex >= 0 && appList.currentItem !== null
                        width: appList.width
                        height: launcher.rowHeight
                        radius: 0
                        color: launcher.highlight
                        y: appList.currentItem ? appList.currentItem.y : 0
                        Behavior on y {
                            Anim { type: Anim.BouncyFast }
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
                        required property string cmd
                        required property string calcResult

                        width: appList.width
                        height: launcher.rowHeight
                        z: 1

                        // Hover layer under content.
                        Rectangle {
                            anchors.fill: parent
                            radius: 0
                            color: rowHover.containsMouse ? launcher.hoverFill : "transparent"
                            Behavior on color { CAnim { type: CAnim.FastEffects } }
                        }

                        Item {
                            id: rowBody
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.topMargin: 5
                            anchors.bottomMargin: 5
                            opacity: 0
                            // Press squish on top of the entrance grow.
                            scale: rowHover.pressed ? 0.95 : 1.0
                            Behavior on scale { Anim { type: Anim.BouncyFast } }
                            transform: [
                                Translate { id: rowSlide; x: 18 },
                                Scale { id: rowGrow; xScale: 0.94; yScale: 0.94 }
                            ]
                            transformOrigin: Item.Center
                            Component.onCompleted: staggerIn.start()

                            Image {
                                id: appIcon
                                anchors.verticalCenter: parent.verticalCenter
                                x: 0
                                width: parent.height * 0.8
                                height: parent.height * 0.8
                                visible: !isCommand && !isCalc && icon.length > 0 && status === Image.Ready
                                source: icon.length > 0 ? "image://icon/" + icon : ""
                                sourceSize: Qt.size(64, 64)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                mipmap: true
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 0
                                width: parent.height * 0.8
                                horizontalAlignment: Text.AlignHCenter
                                visible: !appIcon.visible && (isCommand || isCalc)
                                text: isCommand ? ">" : "="
                                color: launcher.descColor
                                font.family: launcher.fontFamily
                                font.pixelSize: launcher.fontSize + 6
                                font.weight: Font.Medium
                            }

                            QIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 0
                                visible: !appIcon.visible && !isCommand && !isCalc
                                source: launcher.fallbackIconSource(icon, name, desktopId)
                                color: launcher.descColor
                                iconSize: parent.height * 0.8
                            }

                            Item {
                                anchors.left: parent.left
                                anchors.leftMargin: parent.height * 0.8 + 12
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: nameText.implicitHeight + descText.implicitHeight

                                Text {
                                    id: nameText
                                    width: parent.width
                                    text: name
                                    elide: Text.ElideRight
                                    font.family: launcher.fontFamily
                                    font.pixelSize: launcher.fontSize
                                    font.weight: Font.Medium
                                    color: launcher.fg
                                }

                                Text {
                                    id: descText
                                    width: parent.width
                                    visible: desc.length > 0
                                    text: desc
                                    elide: Text.ElideRight
                                    font.family: launcher.uiFont
                                    font.pixelSize: Math.max(9, launcher.fontSize - 2)
                                    color: launcher.descColor
                                    anchors.top: nameText.bottom
                                }
                            }

                            // Staggered entrance: rows cascade in as results
                            // change while typing.
                            SequentialAnimation {
                                id: staggerIn
                                PauseAnimation { duration: Math.max(0, Math.min(index, 8)) * 22 }
                                ParallelAnimation {
                                    Anim { target: rowBody; property: "opacity"; to: 1; type: Anim.FastEffects }
                                    Anim { target: rowSlide; property: "x"; to: 0; type: Anim.BouncyFast }
                                    Anim { target: rowGrow; property: "xScale"; to: 1; type: Anim.BouncyFast }
                                    Anim { target: rowGrow; property: "yScale"; to: 1; type: Anim.BouncyFast }
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

                    // Caelestia list transitions.
                    add: Transition {
                        Anim { property: "opacity"; from: 0; to: 1; type: Anim.DefaultEffects }
                    }
                    remove: Transition {
                        Anim { property: "opacity"; from: 1; to: 0; type: Anim.FastEffects }
                    }
                    move: Transition {
                        Anim { property: "y"; type: Anim.BouncyFast }
                        Anim { property: "opacity"; to: 1; type: Anim.DefaultEffects }
                    }
                    displaced: Transition {
                        Anim { property: "y"; type: Anim.BouncyFast }
                    }
                }

                // Caelestia empty state.
                Row {
                    id: emptyState
                    visible: appList.count === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    padding: 12
                    transform: Scale { id: emptyPop; xScale: 1; yScale: 1 }
                    transformOrigin: Item.Center
                    onVisibleChanged: {
                        if (visible) {
                            emptyPop.xScale = 0.7
                            emptyPop.yScale = 0.7
                            emptyPopGo.start()
                        }
                    }

                    ParallelAnimation {
                        id: emptyPopGo
                        Anim { target: emptyPop; property: "xScale"; to: 1; type: Anim.Bouncy }
                        Anim { target: emptyPop; property: "yScale"; to: 1; type: Anim.Bouncy }
                    }

                    QIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: Qt.resolvedUrl("../assets/icons/search.svg")
                        color: launcher.descColor
                        iconSize: launcher.fontSize + 14
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "No results"
                                font.family: launcher.fontFamily
                                font.pixelSize: launcher.fontSize
                                font.weight: Font.Medium
                                color: launcher.descColor
                            }

                            QIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("../assets/icons/y2k-sparkle-double.svg")
                                color: launcher.descColor
                                iconSize: launcher.fontSize + 2
                            }
                        }

                        Text {
                            text: "Try searching for something else"
                            font.family: launcher.uiFont
                            font.pixelSize: Math.max(9, launcher.fontSize - 2)
                            color: launcher.descColor
                        }
                    }
                }
            }

            Rectangle {
                id: searchBox
                width: parent.width
                height: launcher.searchHeight
                radius: 0
                // Pops a little when focused for typing.
                scale: searchField.inputFocus ? 1.02 : 1.0
                Behavior on scale { Anim { type: Anim.BouncyFast } }
                transformOrigin: Item.Center
                color: rootRef.withAlpha(launcher.fg, 0.08)
                border.width: 1
                border.color: searchField.inputFocus
                    ? rootRef.withAlpha(launcher.fg, 0.4)
                    : rootRef.withAlpha(launcher.fg, 0.12)
                Behavior on border.color { CAnim { type: CAnim.FastEffects } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 6
                    spacing: 8

                    QIcon {
                        Layout.alignment: Qt.AlignVCenter
                        source: Qt.resolvedUrl("../assets/icons/search.svg")
                        color: rootRef.withAlpha(launcher.fg, 0.55)
                        iconSize: launcher.fontSize + 3
                    }

                    CharField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        textColor: launcher.fg
                        font.family: launcher.uiFont
                        font.pixelSize: launcher.fontSize + 1
                        font.weight: Font.Medium
                        placeholderText: "Type \">\" for commands"
                        placeholderTextColor: rootRef.withAlpha(launcher.fg, 0.6)
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter

                        onTextEdited: launcher.filterApps(searchField.text)

                        Keys.onDownPressed: event => {
                            if (appList.currentIndex < listModel.count - 1) appList.currentIndex++
                            event.accepted = true
                        }
                        Keys.onUpPressed: event => {
                            if (appList.currentIndex > 0) appList.currentIndex--
                            event.accepted = true
                        }
                        Keys.onTabPressed: event => {
                            if (listModel.count > 0)
                                appList.currentIndex = (appList.currentIndex + 1) % listModel.count
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
                        radius: 0
                        color: clearHover.containsMouse
                            ? rootRef.withAlpha(launcher.fg, 0.25)
                            : "transparent"
                        Behavior on color { CAnim { type: CAnim.FastEffects } }

                        QIcon {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../assets/icons/close.svg")
                            color: launcher.fg
                            iconSize: launcher.fontSize
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
        }
    }
}
