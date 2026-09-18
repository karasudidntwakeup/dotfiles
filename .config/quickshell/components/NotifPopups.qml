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

        // Caelestia drawer entrance: expressive slide + quick fade + subtle scale.
        populate: Transition {
            Anim { property: "x"; from: popupList.width; to: 0; type: Anim.Bouncy }
            Anim { property: "opacity"; from: 0.0; to: 1.0; type: Anim.DefaultEffects }
            Anim { property: "scale"; from: 0.96; to: 1.0; type: Anim.Bouncy }
        }

        add: Transition {
            Anim { property: "x"; from: popupList.width; to: 0; type: Anim.Bouncy }
            Anim { property: "opacity"; from: 0.0; to: 1.0; type: Anim.DefaultEffects }
            Anim { property: "scale"; from: 0.96; to: 1.0; type: Anim.Bouncy }
        }

        remove: Transition {
            Anim { property: "x"; to: popupList.width + 40; type: Anim.BouncyFast }
            Anim { property: "opacity"; to: 0.0; type: Anim.FastEffects }
        }

        displaced: Transition {
            Anim { property: "y"; type: Anim.BouncyFast }
        }
        removeDisplaced: Transition {
            Anim { property: "y"; type: Anim.BouncyFast }
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
