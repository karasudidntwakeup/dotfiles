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
    anchors.left: true
    anchors.right: true

    readonly property real popupMaxH: 1200
    implicitHeight: Math.min(popupMaxH, popupList.contentHeight)

    margins {
        top: barThickness + 40
    }

    readonly property bool hasCritical: {
        if (!svc) return false
        for (var i = 0; i < svc.popups.count; i++) {
            if (svc.popups.get(i).urgency === 2) return true
        }
        return false
    }

    visible: svc && svc.popups.count > 0 && !svc.centerOpen && (hasCritical || !svc.dnd)

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
        clip: false
        boundsBehavior: Flickable.StopAtBounds

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.92; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; from: -16; to: 0; duration: 280; easing.type: Easing.OutCubic }
            }
        }

        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0.0; duration: 160; easing.type: Easing.OutCubic }
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
