import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: clipMgr

    property var rootRef: null
    property bool active: false

    signal requestClose()

    readonly property int cardWidth: 400
    readonly property int rowHeight: 46
    readonly property int maxRows: 8
    readonly property int searchHeight: 40
    readonly property int pad: 14
    readonly property int cornerRadius: 0

    // YtX-style Android roles: flat surface card, theme text tokens.
    readonly property color cardColor: rootRef ? Qt.color(rootRef.colorOf("surface_container")) : "#1f2c34"
    readonly property color fieldColor: rootRef ? Qt.color(rootRef.colorOf("surface_container_high")) : "#2a3942"
    readonly property color cardBorder: rootRef
        ? rootRef.withAlpha(Qt.color(rootRef.colorOf("outline_variant")), 0.5)
        : "#222d34"

    readonly property color fg: rootRef ? Qt.color(rootRef.colorOf("on_surface")) : "#e9edef"
    readonly property color muted: rootRef ? Qt.color(rootRef.colorOf("on_surface_variant")) : "#8696a0"
    readonly property color selectedFg: clipMgr.fg
    readonly property color errorColor: rootRef ? Qt.color(rootRef.colorOf("widget_error")) : "#e30000"

    // Text/alpha helpers live on root (contrastColor/withAlpha).
    readonly property string fontFamily: uiFont
    readonly property string uiFont: rootRef && rootRef.uiFont ? rootRef.uiFont : "Geist"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13
    readonly property string thumbDir: "/tmp/quickshell-cliphist"

    property real animProgress: clipMgr.active ? 1.0 : 0.0
    Behavior on animProgress {
        Anim { type: Anim.Bouncy }
    }

    // Smooth opacity ramp decoupled from the bouncy slide: OutBack
    // finishes ~95% in the first 150ms, which reads as a pop.
    property real fadeProgress: clipMgr.active ? 1.0 : 0.0
    Behavior on fadeProgress { Anim { type: Anim.SlowEffects } }

    readonly property int bottomMargin: 24
    readonly property int sideMargin: 24

    opacity: clipMgr.fadeProgress

    property var allEntries: []
    ListModel { id: listModel }
    property int totalCount: 0

    onActiveChanged: {
        if (clipMgr.active) {
            searchField.text = ""
            clipMgr.reload()
            focusRequest.restart()
        }
    }

    Timer {
        id: focusRequest
        interval: 40
        repeat: false
        onTriggered: searchField.forceActiveFocus()
    }

    function reload() {
        clipMgr.allEntries = []
        listModel.clear()
        clipMgr.totalCount = 0
        clipProc.running = true
    }

    Process {
        id: clipProc
        command: ["sh", "-c", "cliphist list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: clipMgr.ingest(this.text)
        }
    }

    function ingest(raw) {
        var arr = []
        if (raw) {
            var lines = raw.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                if (!line) continue
                var t = line.indexOf("\t")
                if (t <= 0) continue
                var entryId = line.substring(0, t).trim()
                if (!/^\d+$/.test(entryId)) continue
                arr.push({ entryId: entryId, preview: line.substring(t + 1).replace(/\s+$/g, "") })
            }
        }
        clipMgr.allEntries = arr
        clipMgr.totalCount = arr.length
        clipMgr.applyFilter(searchField.text)
    }

    function applyFilter(text) {
        var q = (text || "").toLowerCase()
        var src = clipMgr.allEntries
        listModel.clear()
        for (var i = 0; i < src.length; i++) {
            var e = src[i]
            if (q.length > 0 && e.preview.toLowerCase().indexOf(q) < 0) continue
            listModel.append({ entryId: e.entryId, preview: e.preview })
        }
        listView.currentIndex = 0
    }

    function copyEntry(eid) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode '" + eid + "' | wl-copy"])
        clipMgr.requestClose()
    }

    function deleteEntry(eid) {
        Quickshell.execDetached(["sh", "-c", "cliphist delete '" + eid + "'"])
        var src = clipMgr.allEntries
        for (var i = 0; i < src.length; i++) {
            if (src[i].entryId === eid) { src.splice(i, 1); break }
        }
        clipMgr.totalCount = src.length
        clipMgr.applyFilter(searchField.text)
        if (listView.currentIndex >= listModel.count)
            listView.currentIndex = Math.max(0, listModel.count - 1)
    }

    function deleteSelected() {
        if (listModel.count === 0) return
        var idx = listView.currentIndex
        if (idx < 0 || idx >= listModel.count) return
        clipMgr.deleteEntry(listModel.get(idx).entryId)
    }

    function activate() {
        if (listModel.count === 0) return
        var idx = listView.currentIndex
        if (idx < 0 || idx >= listModel.count) return
        clipMgr.copyEntry(listModel.get(idx).entryId)
    }

    function wipeAll() {
        Quickshell.execDetached(["cliphist", "wipe"])
        clipMgr.allEntries = []
        clipMgr.totalCount = 0
        clipMgr.applyFilter(searchField.text)
    }

    function wipeArm() { clipMgr.wipeArmed = true }
    function wipeDisarm() { clipMgr.wipeArmed = false }

    property bool wipeArmed: false
    Timer {
        id: wipeDisarmTimer
        interval: 2600
        repeat: false
        onTriggered: clipMgr.wipeArmed = false
    }
    onWipeArmedChanged: {
        if (clipMgr.wipeArmed) {
            wipeDisarmTimer.restart()
        }
    }

    function imageLabel(preview) {
        return preview
            .replace(/\[\[\s*binary data/i, "")
            .replace(/\s*\]\]\s*$/, "")
            .trim()
            || "image"
    }

    Rectangle {
        z: 0
        anchors.fill: parent
        color: "transparent"
        MouseArea {
            anchors.fill: parent
            onClicked: clipMgr.requestClose()
        }
    }

    Rectangle {
        id: card
        z: 1
        width: clipMgr.cardWidth
        height: contentColumn.implicitHeight + clipMgr.pad * 2
        anchors.left: parent.left
        anchors.leftMargin: clipMgr.sideMargin
        y: Math.floor(parent.height - card.height - clipMgr.bottomMargin)
        radius: clipMgr.cornerRadius
        color: clipMgr.cardColor
        border.width: 1
        border.color: clipMgr.cardBorder
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

        transform: Translate {
            x: -(1.0 - clipMgr.animProgress) * 8
        }



        Column {
            id: contentColumn
            x: clipMgr.pad
            y: clipMgr.pad
            width: clipMgr.cardWidth - clipMgr.pad * 2
            spacing: 8

            RowLayout {
                width: parent.width
                spacing: 6

                QIcon {
                    source: Qt.resolvedUrl("../assets/icons/clipboard.svg")
                    color: clipMgr.fg
                    iconSize: clipMgr.fontSize + 4
                }

                Text {
                    text: "Clipboard"
                    color: clipMgr.fg
                    font.family: clipMgr.fontFamily
                    font.pixelSize: clipMgr.fontSize + 1
                    font.weight: Font.DemiBold
                    font.letterSpacing: 3
                    verticalAlignment: Text.AlignVCenter
                }

                QIcon {
                    source: Qt.resolvedUrl("../assets/icons/y2k-sparkle.svg")
                    color: clipMgr.muted
                    iconSize: clipMgr.fontSize + 1
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: clipMgr.totalCount + (clipMgr.totalCount === 1 ? " item" : " items")
                    color: clipMgr.muted
                    font.family: clipMgr.uiFont
                    font.pixelSize: clipMgr.fontSize - 2
                    font.letterSpacing: 1.5
                    verticalAlignment: Text.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: wipeBtn
                    Layout.preferredWidth: wipeText.implicitWidth + 22
                    Layout.preferredHeight: 24
                    radius: 0
                    color: clipMgr.wipeArmed
                        ? (wipeHover.containsMouse ? rootRef.withAlpha(clipMgr.errorColor, 0.8) : clipMgr.errorColor)
                        : (wipeHover.containsMouse ? rootRef.withAlpha(clipMgr.fg, 0.08) : Qt.rgba(clipMgr.fg.r, clipMgr.fg.g, clipMgr.fg.b, 0.02))
                    border.width: 1
                    border.color: clipMgr.wipeArmed
                        ? "transparent"
                        : (wipeHover.containsMouse ? rootRef.withAlpha(clipMgr.fg, 0.35) : rootRef.withAlpha(clipMgr.fg, 0.16))
                    Behavior on color { CAnim { type: CAnim.FastEffects } }

                    Row {
                        id: wipeText
                        anchors.centerIn: parent
                        spacing: 5

                        QIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: Qt.resolvedUrl("../assets/icons/trash.svg")
                            color: clipMgr.wipeArmed ? "#ffffff" : clipMgr.fg
                            iconSize: clipMgr.fontSize
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: clipMgr.wipeArmed ? "CONFIRM CLEAR" : "CLEAR ALL"
                            color: clipMgr.wipeArmed ? "#ffffff" : clipMgr.fg
                            font.family: clipMgr.uiFont
                            font.pixelSize: clipMgr.fontSize - 2
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.5
                        }
                    }

                    MouseArea {
                        id: wipeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (clipMgr.wipeArmed) {
                                clipMgr.wipeAll()
                                clipMgr.wipeDisarm()
                            } else {
                                clipMgr.wipeArm()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 0
                    color: closeHover.containsMouse
                        ? rootRef.withAlpha(clipMgr.fg, 0.2)
                        : "transparent"
                    Behavior on color { CAnim { type: CAnim.FastEffects } }

                    QIcon {
                        anchors.centerIn: parent
                        source: Qt.resolvedUrl("../assets/icons/close.svg")
                        color: clipMgr.fg
                        iconSize: clipMgr.fontSize + 2
                    }

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipMgr.requestClose()
                    }
                }
            }

            Rectangle {
                id: searchBox
                width: parent.width
                height: clipMgr.searchHeight
                radius: 0
                color: clipMgr.fieldColor
                border.width: 1
                border.color: searchField.inputFocus
                    ? rootRef.withAlpha(clipMgr.fg, 0.5)
                    : clipMgr.cardBorder
                Behavior on border.color { CAnim { type: CAnim.FastEffects } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 6
                    spacing: 8

                    QIcon {
                        source: Qt.resolvedUrl("../assets/icons/search.svg")
                        color: clipMgr.muted
                        iconSize: clipMgr.fontSize + 4
                        Layout.alignment: Qt.AlignVCenter
                    }

                    CharField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        textColor: clipMgr.fg
                        font.family: clipMgr.uiFont
                        font.pixelSize: clipMgr.fontSize + 1
                        font.weight: Font.Medium
                        placeholderText: "Search history"
                        placeholderTextColor: clipMgr.muted
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter

                        onTextEdited: clipMgr.applyFilter(searchField.text)

                        Keys.onDownPressed: event => {
                            if (listModel.count > 0 && listView.currentIndex < listModel.count - 1)
                                listView.currentIndex++
                            event.accepted = true
                        }
                        Keys.onUpPressed: event => {
                            if (listView.currentIndex > 0) listView.currentIndex--
                            event.accepted = true
                        }
                        Keys.onReturnPressed: event => {
                            clipMgr.activate()
                            event.accepted = true
                        }
                        Keys.onDeletePressed: event => {
                            clipMgr.deleteSelected()
                            event.accepted = true
                        }
                        Keys.onEscapePressed: event => {
                            clipMgr.requestClose()
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
                            ? rootRef.withAlpha(clipMgr.fg, 0.25)
                            : "transparent"
                        Behavior on color { CAnim { type: CAnim.FastEffects } }

                        QIcon {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../assets/icons/close.svg")
                            color: clipMgr.fg
                            iconSize: clipMgr.fontSize + 2
                        }

                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = ""
                                searchField.forceActiveFocus()
                                clipMgr.applyFilter("")
                            }
                        }
                    }
                }
            }

            Item {
                id: listContainer
                width: parent.width
                height: listModel.count === 0
                    ? 96
                    : Math.min(clipMgr.maxRows, listModel.count) * clipMgr.rowHeight
                        + Math.max(0, Math.min(clipMgr.maxRows, listModel.count) - 1) * 8
                clip: true

                ListView {
                    id: listView
                    anchors.fill: parent
                    model: listModel
                    spacing: 8
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    // Springy list motion while filtering/adding.
                    move: Transition {
                        Anim { property: "y"; type: Anim.BouncyFast }
                        Anim { property: "opacity"; to: 1; type: Anim.DefaultEffects }
                    }
                    displaced: Transition {
                        Anim { property: "y"; type: Anim.BouncyFast }
                    }
                    add: Transition {
                        Anim { property: "opacity"; from: 0; to: 1; type: Anim.DefaultEffects }
                    }
                    remove: Transition {
                        Anim { property: "opacity"; from: 1; to: 0; type: Anim.FastEffects }
                    }

                    Rectangle {
                        id: morphHighlight
                        parent: listView.contentItem
                        z: 0
                        visible: listModel.count > 0 && listView.currentIndex >= 0 && listView.currentItem !== null
                        width: listView.width
                        height: clipMgr.rowHeight
                        radius: 0
                        color: rootRef.withAlpha(clipMgr.fg, 0.09)

                        readonly property real targetY: (listView.currentIndex >= 0 && listView.currentItem !== null)
                            ? listView.currentItem.y : 0
                        y: targetY

                        Behavior on y {
                            Anim { type: Anim.BouncyFast }
                        }
                    }

                    delegate: Item {
                        required property int index
                        required property string entryId
                        required property string preview

                        readonly property bool isSelected: listView.currentIndex === index
                        readonly property bool isImage: preview.indexOf("binary data") >= 0
                        readonly property string thumbPath: clipMgr.thumbDir + "/" + entryId + ".png"

                        width: listView.width
                        height: clipMgr.rowHeight
                        z: 1

                        Rectangle {
                            anchors.fill: parent
                            radius: 0
                            color: rowHover.containsMouse && !isSelected
                                ? rootRef.withAlpha(clipMgr.fg, 0.08)
                                : "transparent"
                            Behavior on color { CAnim { type: CAnim.FastEffects } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 0
                                    color: isSelected
                                        ? rootRef.withAlpha(clipMgr.fg, 0.16)
                                        : rootRef.withAlpha(clipMgr.fg, 0.08)
                                    Behavior on color { CAnim { type: CAnim.FastEffects } }
                                }

                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    visible: isImage
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    mipmap: true
                                    cache: false
                                    source: ""

                                    Process {
                                        id: thumbGen
                                        command: ["sh", "-c",
                                            "mkdir -p " + clipMgr.thumbDir +
                                            " && cliphist decode '" + entryId +
                                            "' > '" + thumbPath + "'"]
                                        onExited: code => {
                                            if (code === 0)
                                                thumbImg.source = "file://" + thumbPath + "?t=" + Date.now()
                                        }
                                    }

                                    Component.onCompleted: {
                                        if (isImage) thumbGen.running = true
                                    }
                                }

                                QIcon {
                                    anchors.centerIn: parent
                                    visible: !isImage
                                    source: Qt.resolvedUrl("../assets/icons/clipboard.svg")
                                    color: isSelected ? clipMgr.selectedFg : clipMgr.fg
                                    iconSize: clipMgr.fontSize + 2
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: isImage ? clipMgr.imageLabel(preview)
                                        : (preview.length === 0 ? "(empty)" : preview)
                                    color: isSelected ? clipMgr.selectedFg : clipMgr.fg
                                    font.family: isImage ? clipMgr.uiFont : clipMgr.fontFamily
                                    font.pixelSize: clipMgr.fontSize
                                    font.weight: Font.Medium
                                    maximumLineCount: preview.length === 0 ? 1 : 2
                                    clip: true
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { CAnim { type: CAnim.FastEffects } }
                                }

                                Text {
                                    visible: isImage
                                    width: parent.width
                                    text: "image — " + preview
                                    elide: Text.ElideRight
                                    font.family: clipMgr.uiFont
                                    font.pixelSize: Math.max(9, clipMgr.fontSize - 2)
                                    color: isSelected
                                        ? rootRef.withAlpha(clipMgr.selectedFg, 0.85)
                                        : rootRef.withAlpha(clipMgr.fg, 0.75)
                                }
                            }

                            Rectangle {
                                id: deleteBtn
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                radius: 0
                                color: deleteHover.containsMouse
                                    ? rootRef.withAlpha(clipMgr.errorColor, 0.5)
                                    : rootRef.withAlpha(clipMgr.fg, isSelected ? 0.25 : 0.12)

                                QIcon {
                                    anchors.centerIn: parent
                                    source: Qt.resolvedUrl("../assets/icons/trash.svg")
                                    color: deleteHover.containsMouse ? "#ffffff" : clipMgr.fg
                                    iconSize: clipMgr.fontSize + 2
                                }

                                MouseArea {
                                    id: deleteHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        listView.currentIndex = index
                                        clipMgr.deleteEntry(entryId)
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            anchors.rightMargin: 40
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                listView.currentIndex = index
                                clipMgr.activate()
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: listModel.count === 0

                    MouseArea {
                        anchors.fill: parent
                        onClicked: clipMgr.requestClose()
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        QIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: Qt.resolvedUrl("../assets/icons/y2k-glitter.svg")
                            color: clipMgr.muted
                            iconSize: clipMgr.fontSize + 14
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: searchField.text.length > 0
                                ? "No matches"
                                : "Clipboard is empty"
                            color: clipMgr.muted
                            font.family: clipMgr.uiFont
                            font.pixelSize: clipMgr.fontSize
                        }
                    }
                }
            }
        }
    }
}
