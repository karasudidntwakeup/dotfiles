import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: center

    property var rootRef: null
    property var svc: null

    focus: svc ? svc.centerOpen : false

    readonly property int panelWidth: 400
    readonly property int pad: 12
    readonly property color panelColor: rootRef
        ? (rootRef.qsLight ? rootRef.pillColor("surface") : rootRef.colorOf("surface"))
        : "#15161a"
    readonly property color panelBorder: rootRef ? rootRef.withAlpha(Qt.color(rootRef.colorOf("widget_border")), rootRef.qsLight ? 0.7 : 0.5) : "#ffffff33"
    readonly property color fg: rootRef ? center.contrastColor(center.panelColor) : "#ffffff"
    readonly property color muteFg: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.55)
    readonly property color accent: rootRef ? Qt.color(rootRef.colorOf("widget_accent")) : "#ff8fb2"
    readonly property string iconFont: rootRef && rootRef.iconFont ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string uiFont: rootRef && rootRef.uiFont ? rootRef.uiFont : "Inter"
    readonly property string fontFamily: rootRef && rootRef.fontFamily ? rootRef.fontFamily : "Ndot 57"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13

    function _lin(v: double): double {
        if (v <= 0.03928) return v / 12.92
        return Math.pow((v + 0.055) / 1.055, 2.4)
    }
    function relLum(c: color): double {
        return 0.2126 * center._lin(c.r) + 0.7152 * center._lin(c.g) + 0.0722 * center._lin(c.b)
    }
    function contrastColor(c: color): color {
        var l = center.relLum(c)
        var white = (1.05) / (l + 0.05)
        var black = (l + 0.05) / (0.05)
        return white >= black ? "#ffffff" : "#000000"
    }
    property real animProgress: svc && svc.centerOpen ? 1.0 : 0.0
    Behavior on animProgress {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    Keys.onEscapePressed: event => {
        if (svc) svc.closeCenter()
        event.accepted = true
    }
    Keys.onDownPressed: event => {
        if (centerList.count > 0) centerList.incrementCurrentIndex()
        event.accepted = true
    }
    Keys.onUpPressed: event => {
        if (centerList.count > 0) centerList.decrementCurrentIndex()
        event.accepted = true
    }
    Keys.onReturnPressed: event => {
        var current = centerList.currentItem
        if (current && typeof current.activate === "function") current.activate()
        event.accepted = true
    }

    MouseArea {
        id: backdropArea
        anchors.fill: parent
        onClicked: { if (svc) svc.closeCenter() }
    }

    Rectangle {
        id: panel
        width: center.panelWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: 30
        anchors.bottomMargin: 30
        anchors.rightMargin: 10
        color: center.panelColor
        radius: 22
        border.width: 2
        border.color: center.panelBorder
        clip: true

        SurfaceGradient {
            anchors.fill: parent
            inset: 1
            color: center.panelColor
            radius: 22
        }

        transform: Translate {
            x: (1.0 - center.animProgress) * (center.panelWidth + 48)
        }
        scale: 0.98 + 0.02 * center.animProgress
        rotation: (1.0 - center.animProgress) * 1.5
        transformOrigin: Item.Right

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: center.pad
            anchors.rightMargin: center.pad
            anchors.topMargin: center.pad
            anchors.bottomMargin: center.pad
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 8

                Text {
                    text: ""
                    color: center.fg
                    font.family: center.iconFont
                    font.pixelSize: center.fontSize + 3
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 30
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text: "Notifications"
                    color: center.fg
                    font.family: center.fontFamily
                    font.pixelSize: center.fontSize + 2
                    font.weight: Font.Black
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    visible: svc && svc.unreadCount > 0
                    Layout.preferredHeight: 20
                    implicitWidth: unreadLabel.implicitWidth + 12
                    radius: 10
                    color: center.accent

                    Text {
                        id: unreadLabel
                        anchors.centerIn: parent
                        text: svc ? String(svc.unreadCount) : ""
                        color: "#15161a"
                        font.family: center.fontFamily
                        font.pixelSize: center.fontSize - 2
                        font.weight: Font.Black
                    }
                }

                HeaderBtn {
                    glyph: "󰂚"
                    active: svc ? svc.dnd : false
                    onTapped: { if (svc) svc.dnd = !svc.dnd }
                }

                HeaderBtn {
                    glyph: "󰗩"
                    enabled_: svc && svc.history.count > 0
                    active: false
                    onTapped: { if (svc) svc.clearAll() }
                }
            }

            ListView {
                id: centerList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: svc ? svc.history : []
                spacing: 10
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    width: 3
                    policy: ScrollBar.AsNeeded
                    background: Item {}
                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: 1.5
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }

                onCountChanged: {
                    if (centerList.count === 0) centerList.currentIndex = -1
                    else if (centerList.currentIndex >= centerList.count)
                        centerList.currentIndex = centerList.count - 1
                }

                Component.onCompleted: {
                    if (centerList.count > 0) centerList.currentIndex = 0
                }

                delegate: NotificationCard {
                    width: centerList.width
                    rootRef: center.rootRef
                    svc: center.svc
                    nData: model
                    context: "center"
                    selected: centerList.currentIndex === index
                    z: centerList.currentIndex === index ? 2 : 1
                    onCardSelected: centerList.currentIndex = index
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: svc && svc.history.count === 0

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -24
                    text: ""
                    color: center.muteFg
                    font.family: center.iconFont
                    font.pixelSize: 34
                }
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 22
                    text: "No notifications"
                    color: center.muteFg
                    font.family: center.uiFont
                    font.pixelSize: center.fontSize - 1
                }
            }

            Rectangle {
                id: mediaCard
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                visible: rootRef && rootRef.mediaStatus !== "none"
                radius: 16
                color: Qt.rgba(center.accent.r, center.accent.g, center.accent.b, 0.08)
                border.width: 1
                border.color: Qt.rgba(center.accent.r, center.accent.g, center.accent.b, 0.15)

                property string mediaTitle: {
                    if (!rootRef || !rootRef.mediaInfo) return ""
                    var parts = rootRef.mediaInfo.split("|")
                    return parts[0] || ""
                }
                property string mediaArtist: {
                    if (!rootRef || !rootRef.mediaInfo) return ""
                    var parts = rootRef.mediaInfo.split("|")
                    return parts.length > 1 ? parts[1] : ""
                }
                property real progress: rootRef && rootRef.mediaLenMs > 0
                    ? Math.max(0, Math.min(1, rootRef.mediaPosMs / rootRef.mediaLenMs))
                    : 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
spacing: 15

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            Layout.fillWidth: true
                            text: mediaCard.mediaTitle
                            color: center.fg
                            font.family: center.fontFamily
                            font.pixelSize: center.fontSize
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: mediaCard.mediaArtist
                            color: center.muteFg
                            font.family: center.uiFont
                            font.pixelSize: center.fontSize - 2
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18

                            Rectangle {
                                id: seekTrack
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 3
                                radius: 1.5
                                color: Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.1)
                            }

                            Rectangle {
                                id: seekFill
                                anchors.left: seekTrack.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: mediaCard.progress * seekTrack.width
                                height: 3
                                radius: 1.5
                                color: center.accent
                            }

                            Rectangle {
                                id: seekKnob
                                anchors.verticalCenter: parent.verticalCenter
                                x: seekTrack.x + mediaCard.progress * seekTrack.width - width / 2
                                width: 6
                                height: 6
                                radius: 3
                                color: center.accent
                                visible: seekArea.containsMouse || seekArea.dragging
                            }

                            MouseArea {
                                id: seekArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                property bool dragging: false

                                function seekTo(posX) {
                                    if (!rootRef || rootRef.mediaLenMs <= 0) return
                                    var ratio = Math.max(0, Math.min(1, posX / seekArea.width))
                                    var targetMs = Math.round(ratio * rootRef.mediaLenMs)
                                    Quickshell.execDetached(["playerctl", "position", String(targetMs / 1000)])
                                    rootRef.mediaPosMs = targetMs
                                }

                                onPressed: (mouse) => {
                                    dragging = true
                                    seekTo(mouse.x)
                                }
                                onPositionChanged: (mouse) => {
                                    if (dragging) seekTo(mouse.x)
                                }
                                onReleased: (mouse) => {
                                    dragging = false
                                }
                            }
                        }
                    }

                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        Item {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28

                            Rectangle {
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                radius: 14
                                color: mediaPrevArea.containsMouse
                                    ? Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.1)
                                    : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: center.fg
                                    font.family: center.iconFont
                                    font.pixelSize: center.fontSize + 2
                                }

                                MouseArea {
                                    id: mediaPrevArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rootRef ? Quickshell.execDetached(["playerctl", "previous"]) : {}
                                }
                            }
                        }

                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32

                            Rectangle {
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                radius: 16
                                color: center.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: rootRef && rootRef.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                                    color: "#15161a"
                                    font.family: center.iconFont
                                    font.pixelSize: center.fontSize + 4
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rootRef ? Quickshell.execDetached(["playerctl", "play-pause"]) : {}
                                }
                            }
                        }

                        Item {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28

                            Rectangle {
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                radius: 14
                                color: mediaNextArea.containsMouse
                                    ? Qt.rgba(center.fg.r, center.fg.g, center.fg.b, 0.1)
                                    : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: center.fg
                                    font.family: center.iconFont
                                    font.pixelSize: center.fontSize + 2
                                }

                                MouseArea {
                                    id: mediaNextArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rootRef ? Quickshell.execDetached(["playerctl", "next"]) : {}
                                }
                            }
                        }
                    }
                }
            }
        }

    component HeaderBtn: Item {
        id: btn
        property string glyph: ""
        property bool active: false
        property bool enabled_: true
        signal tapped()

        Layout.preferredWidth: 30
        Layout.preferredHeight: 30

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: !btn.enabled_
                ? Qt.rgba(1, 1, 1, 0.04)
                : btn.active
                    ? Qt.rgba(center.accent.r, center.accent.g, center.accent.b, 0.35)
                    : (hoverArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: !btn.enabled_ ? Qt.rgba(1, 1, 1, 0.25) : center.fg
            font.family: center.iconFont
            font.pixelSize: center.fontSize
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            enabled: btn.enabled_
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.tapped()
        }
    }



}
}
