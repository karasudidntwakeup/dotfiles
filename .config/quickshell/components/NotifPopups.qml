import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popupLayer

    property var rootRef: null
    property var svc: null

    WlrLayershell.namespace: "qs-notif-popups"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    implicitWidth: 360

    readonly property int barThickness: rootRef ? rootRef.barHeight : 48

    anchors.top: true
    anchors.right: true

    readonly property real popupMaxH: Math.max(0, (screen ? screen.height : 1200) - margins.top - 24)
    implicitHeight: Math.min(popupMaxH, popupList.contentHeight)

    margins {
        top: barThickness + 40
        right: 12
    }

    readonly property bool hasCritical: {
        if (!svc) return false
        for (var i = 0; i < svc.popups.count; i++) {
            if (svc.popups.get(i).urgency === 2) return true
        }
        return false
    }

    readonly property bool popupActive: svc && svc.popups.count > 0 && !svc.centerOpen && (hasCritical || !svc.dnd)

    // Hold the window open for the exit animation after the last card leaves.
    property bool exitHold: false
    Timer {
        id: exitHoldTimer
        interval: 300
        running: false
        onTriggered: popupLayer.exitHold = false
    }
    onPopupActiveChanged: {
        if (popupActive) {
            exitHoldTimer.stop()
            exitHold = false
        } else if (visible) {
            exitHold = true
            exitHoldTimer.restart()
        }
    }

    visible: popupActive || exitHold

    mask: Region {
        item: popupList
    }

    ListView {
        id: popupList
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 360
        height: parent.height
        model: svc ? svc.popups : []
        spacing: 10
        interactive: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // macOS-style entrance: slides in from the right edge with a strong
        // decelerating curve plus quick fade and subtle scale-up.
        populate: Transition {
            NumberAnimation { property: "x"; from: popupList.width; to: 0; duration: 460; easing.type: Easing.OutExpo }
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.96; to: 1.0; duration: 460; easing.type: Easing.OutExpo }
        }

        add: Transition {
            NumberAnimation { property: "x"; from: popupList.width; to: 0; duration: 460; easing.type: Easing.OutExpo }
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.96; to: 1.0; duration: 460; easing.type: Easing.OutExpo }
        }

        remove: Transition {
            NumberAnimation { property: "x"; to: popupList.width + 40; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
        }

        displaced: Transition {
            NumberAnimation { property: "y"; duration: 360; easing.type: Easing.OutQuint }
        }
        removeDisplaced: Transition {
            NumberAnimation { property: "y"; duration: 360; easing.type: Easing.OutQuint }
        }

        delegate: NotificationCard {
            width: popupList.width
            rootRef: popupLayer.rootRef
            svc: popupLayer.svc
            nData: model
            context: "popup"
        }
    }
}
