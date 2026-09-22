// Plain text input, same API as the old animated CharField so all
// existing call sites keep working without changes.
//
//   CharField {
//       textColor: theme.fg
//       font.pixelSize: 16
//       placeholderText: "Search"
//       onTextEdited: filter(text)
//       Keys.onReturnPressed: accept()
//   }
//
// Key events are forwarded from the inner TextField to this item, so
// Keys.on* handlers attached here keep working like on a normal field.
import QtQuick
import QtQuick.Controls

Item {
    id: root

    // ---- TextField surface (the parts callers actually use) ----
    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property alias placeholderTextColor: field.placeholderTextColor
    property alias selectByMouse: field.selectByMouse
    property alias readOnly: field.readOnly
    property alias verticalAlignment: field.verticalAlignment
    property alias horizontalAlignment: field.horizontalAlignment
    property alias font: field.font
    property alias inputFocus: field.activeFocus

    property color textColor: "#eeeeee"

    signal textEdited()
    signal accepted()

    function forceActiveFocus() {
        field.forceActiveFocus()
    }

    TextField {
        id: field
        anchors.fill: parent
        color: root.textColor
        leftPadding: 0
        rightPadding: 0
        clip: true
        background: Item {}
        Keys.forwardTo: [root]
        onTextEdited: root.textEdited()
        onAccepted: root.accepted()
    }
}
