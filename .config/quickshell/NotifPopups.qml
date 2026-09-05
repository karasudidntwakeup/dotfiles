import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland

// Notification popups (toasts) — a thin non-interactive strip pinned to the
// top-right corner, fed by NotificationService.popups. Replaces swaync's
// notification area. Popups are hidden while DND is on (except critical) or
// while the notification center is open.
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

    // Hug the toasts instead of a full-height strip (no big transparent region).
    readonly property real popupMaxH: 1200
    implicitHeight: Math.min(popupMaxH, popupList.contentHeight)

    margins {
        top: barThickness + 20
        right: 16
    }

    readonly property bool hasCritical: {
        if (!svc) return false
        for (var i = 0; i < svc.popups.count; i++) {
            if (svc.popups.get(i).urgency === 2) return true
        }
        return false
    }

    visible: svc && svc.popups.count > 0 && !svc.centerOpen && (hasCritical || !svc.dnd)

    // Only the popup cards accept input; the rest of the strip passes through.
    mask: Region {
        item: popupList
    }

    ListView {
        id: popupList
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height
        model: svc ? svc.popups : []
        spacing: 10
        interactive: true
        clip: false
        boundsBehavior: Flickable.StopAtBounds

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: popupList.width * 0.4; to: 0; duration: 280; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; from: -12; to: 0; duration: 280; easing.type: Easing.OutCubic }
            }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0.0; duration: 160; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; to: popupList.width * 0.4; duration: 200; easing.type: Easing.OutCubic }
            }
        }

        displaced: Transition {
            NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic }
        }
        removeDisplaced: Transition {
            NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic }
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