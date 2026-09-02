import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: wifiPopup
    property var rootRef: null
    width: 360
    implicitHeight: col.implicitHeight + 32

    property bool isConnected: false
    property string wifiIface: ""
    property string currentSsid: ""
    property string currentSignal: ""
    property string currentIp: ""
    property color popupColor: "#00000000"   // pill-colored background
    property var networkList: []
    property string pendingSsid: ""
    property string passwordFor: ""           // SSID we're asking a password for

    Process {
        id: wifiPoller
        property bool scan: false
        command: wifiPoller.scan
            ? ["sh", "-c", "sh /home/karasu/.config/quickshell/scripts/wifi.sh scan 2>/dev/null"]
            : ["sh", "-c", "sh /home/karasu/.config/quickshell/scripts/wifi.sh 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim());
                    wifiPopup.isConnected = d.connected;
                    wifiPopup.wifiIface = d.iface || "wlan0";
                    wifiPopup.currentSsid = d.ssid || "";
                    wifiPopup.currentSignal = d.signal || "";
                    wifiPopup.currentIp = d.ip || "";
                    wifiPopup.networkList = d.networks || [];
                    wifiPoller.scan = false;
                } catch(e) {}
            }
        }
    }

    // trigger a fresh scan then rebuild the list
    function scanNetworks() {
        wifiPoller.scan = true;
        wifiPoller.running = true;
    }

    // connect to a network; passphrase optional (for open/known nets pass "")
    function doConnect(ssid, passphrase) {
        wifiPopup.passwordFor = "";
        wifiPopup.pendingSsid = ssid;
        let sh = s => "'" + s.replace(/'/g, "'\\''") + "'";
        let cmd = "iwctl";
        if (passphrase && passphrase !== "") cmd += " --passphrase " + sh(passphrase);
        cmd += " station " + wifiPopup.wifiIface + " connect " + sh(ssid);
        Quickshell.execDetached(["bash", "-c", cmd]);
        connectWait.restart();
    }

    Timer {
        running: true
        repeat: true
        interval: 8000
        onTriggered: wifiPoller.running = true
    }

    function signalIcon(sig) {
        let s = parseInt(sig) || 0;
        if (s >= 80) return "󰤨";
        if (s >= 60) return "󰤥";
        if (s >= 40) return "󰤢";
        if (s > 0) return "󰤟";
        return "󰤯";
    }

    // pick high-contrast foreground for a given background color
    function on(bg) {
        let lum = bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114;
        return lum > 0.5 ? "#000000" : "#ffffff";
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: wifiPopup.popupColor.a > 0 ? wifiPopup.popupColor : rootRef.colorOf("surface")
        border.width: 1
        border.color: rootRef.colorOf("outline_variant")
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "󰖩"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 18
                color: wifiPopup.on(wifiPopup.popupColor)
            }
            Text {
                text: "Wi-Fi"
                font.family: "Inter"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: wifiPopup.on(wifiPopup.popupColor)
                Layout.fillWidth: true
            }
            Text {
                text: "󰦖"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 14
                color: wifiPopup.on(wifiPopup.popupColor)
                visible: wifiPoller.scan
            }
        }

        // connected card
        Rectangle {
            Layout.fillWidth: true
            height: 64
            radius: 10
            color: rootRef.colorOf("surface_container")
            visible: wifiPopup.isConnected

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: wifiPopup.signalIcon(wifiPopup.currentSignal)
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 22
                    color: wifiPopup.on(rootRef.colorOf("surface_container"))
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: wifiPopup.currentSsid
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: wifiPopup.on(rootRef.colorOf("surface_container"))
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: wifiPopup.currentIp + (wifiPopup.currentSignal ? "  •  " + wifiPopup.currentSignal + "%" : "")
                        font.family: "Inter"
                        font.pixelSize: 11
                        color: wifiPopup.on(rootRef.colorOf("surface_container"))
                    }
                }
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: disconnectArea.containsMouse ? rootRef.colorOf("error_container") : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "󰇃"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: rootRef.colorOf("error")
                    }
                    MouseArea {
                        id: disconnectArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["bash", "-c", "iwctl station " + wifiPopup.wifiIface + " disconnect"]);
                            wifiPopup.scanNetworks();
                        }
                    }
                }
            }
        }

        // no connection banner
        Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: 10
            color: rootRef.colorOf("surface_container")
            visible: !wifiPopup.isConnected

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Text {
                    text: "󰤪"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 20
                    color: wifiPopup.on(rootRef.colorOf("surface_container"))
                }
                Text {
                    text: "Not connected"
                    font.family: "Inter"
                    font.pixelSize: 13
                    color: wifiPopup.on(rootRef.colorOf("surface_container"))
                    Layout.fillWidth: true
                }
            }
        }

        // divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: rootRef.colorOf("outline_variant")
        }

        // password prompt for protected networks
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            radius: 8
            color: rootRef.colorOf("surface_container")
            visible: wifiPopup.passwordFor !== ""

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Text {
                    text: "Password for " + wifiPopup.passwordFor
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: rootRef.colorOf("on_surface")
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: 6
                        color: rootRef.colorOf("surface_container_highest")
                        border.width: 1
                        border.color: rootRef.colorOf("outline_variant")

                        TextInput {
                            id: passInput
                            anchors.fill: parent
                            anchors.margins: 8
                            verticalAlignment: Text.AlignVCenter
                            echoMode: TextInput.Password
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: rootRef.colorOf("on_surface")
                            selectionColor: rootRef.colorOf("primary")
                            selectByMouse: true
                        }
                    }
                    Rectangle {
                        width: 34; height: 34; radius: 6
                        color: passConnect.containsMouse ? rootRef.colorOf("primary_container") : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰁾"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: rootRef.colorOf("primary")
                        }
                        MouseArea {
                            id: passConnect
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (passInput.text === "") return;
                                wifiPopup.doConnect(wifiPopup.passwordFor, passInput.text);
                            }
                        }
                    }
                    Rectangle {
                        width: 34; height: 34; radius: 6
                        color: passCancel.containsMouse ? rootRef.colorOf("surface_container_highest") : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: rootRef.colorOf("error")
                        }
                        MouseArea {
                            id: passCancel
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wifiPopup.passwordFor = ""
                        }
                    }
                }
            }
        }

        // network list
        Text {
            text: "Available networks"
            font.family: "Inter"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: wifiPopup.on(wifiPopup.popupColor)
            Layout.leftMargin: 4
        }

        Flickable {
            id: netScroll
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(netCol.implicitHeight, 300)
            clip: true
            contentWidth: width
            contentHeight: netCol.implicitHeight
            interactive: netCol.implicitHeight > 300

            Column {
                id: netCol
                width: netScroll.width
                spacing: 6

                Repeater {
                    model: wifiPopup.networkList

                    Rectangle {
                        id: netPillRow
                        width: parent ? parent.width : 0
                        height: 44
                        radius: 8

                        property string netName: modelData ? modelData.name : ""
                        property int netSig: modelData ? (parseInt(modelData.sig) || 0) : 0
                        property string netSec: modelData ? (modelData.sec || "open") : "open"
                        property bool netKnown: modelData ? modelData.known === true : false
                        property bool isCurrent: netPillRow.netName === wifiPopup.currentSsid
                        readonly property color rowBg: isCurrent ? rootRef.colorOf("primary_container")
                            : netArea.containsMouse ? rootRef.colorOf("surface_container_highest")
                            : rootRef.signalTint(netPillRow.netSig)
                        readonly property color rowFg: wifiPopup.on(netPillRow.rowBg)

                        color: netPillRow.rowBg
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            id: netRow
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            Text {
                                text: netPillRow.isCurrent ? wifiPopup.signalIcon(wifiPopup.currentSignal) : wifiPopup.signalIcon(netPillRow.netSig)
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 18
                                color: netPillRow.rowFg
                            }
                            Text {
                                text: netPillRow.netName
                                font.family: "Inter"
                                font.pixelSize: 13
                                font.weight: netPillRow.isCurrent ? Font.Medium : Font.Normal
                                color: netPillRow.rowFg
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: netPillRow.isCurrent ? "Connected" : (netPillRow.netSig ? netPillRow.netSig + "%" : "")
                                font.family: "Inter"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: netPillRow.rowFg
                                visible: !wifiPopup.pendingSsid
                            }
                            // connecting spinner
                            Text {
                                text: "󰦖"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 16
                                color: netPillRow.rowFg
                                visible: wifiPopup.pendingSsid === netPillRow.netName
                            }
                        }

                        MouseArea {
                            id: netArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (netPillRow.isCurrent) return;
                                let sec = netPillRow.netSec;
                                let isSecured = sec === "psk" || sec === "wpa" || sec === "wpa2" || sec === "wep";
                                // saved network: connect without a password prompt
                                if (netPillRow.netKnown || !isSecured) {
                                    wifiPopup.doConnect(netPillRow.netName, "");
                                    return;
                                }
                                // unsaved protected network -> ask for a password
                                wifiPopup.passwordFor = netPillRow.netName;
                                passInput.forceActiveFocus();
                                passInput.text = "";
                            }
                        }
                    }
                }
            }
        }

        Timer {
            id: connectWait
            interval: 4000
            onTriggered: {
                wifiPopup.pendingSsid = "";
                wifiPopup.scanNetworks();
            }
        }
    }
}
