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
    // NB: Flickable topMargin/bottomMargin sit outside contentHeight, so add
    // them explicitly or the window comes up short and slices the card.
    implicitHeight: Math.min(popupMaxH, popupList.contentHeight + popupList.topMargin + popupList.bottomMargin)

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
        // No viewport clipping: the window bounds already clip, and clipping
        // here would slice the card shadows (offset + blur overhang).
        // Shadow room comes from the side inset + top/bottom margins below.
        clip: false
        topMargin: 12
        bottomMargin: 12
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 2000

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
            // Inset so the shadow (right/down overhang + blur) stays inside
            // the window instead of being sliced at its edges.
            x: 12
            width: popupList.width - 24
            rootRef: popupLayer.rootRef
            svc: popupLayer.svc
            nData: model
            context: "popup"
        }
    }
}
