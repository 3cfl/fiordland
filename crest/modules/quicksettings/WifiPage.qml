pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.components
import qs.services
import qs.theme

ColumnLayout {
    id: root

    property var pending: null

    signal back

    spacing: 8

    onVisibleChanged: Net.scan(visible)

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        IconButton {
            icon: "arrow_back"
            size: 36
            onClicked: root.back()
        }

        Txt {
            Layout.fillWidth: true
            text: "wi‑fi"
            role: "titleL"
        }

        Switch {
            checked: Net.wifiEnabled
            onToggled: on => Net.setWifi(on)
        }
    }

    Txt {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: Net.sorted.length === 0
        text: Net.wifiEnabled ? "looking for networks…" : "wi‑fi is off"
        role: "bodyM"
        color: Colours.fgSurfaceVariant
    }

    Repeater {
        model: Net.sorted

        Rectangle {
            id: row

            required property var modelData
            readonly property bool secured: modelData.security !== WifiSecurityType.Open

            Layout.fillWidth: true
            implicitHeight: 52 + (root.pending === modelData ? 56 : 0)
            radius: Style.rLg
            color: modelData.connected ? Colours.alpha(Colours.primaryContainer, 0.9) : Colours.alpha(Colours.surfaceContainerHighest, 0.6)

            Behavior on implicitHeight {
                SpringDefault {}
            }

            StateLayer {
                anchors.fill: undefined
                width: parent.width
                height: 52
                radius: Style.rLg
                onClicked: {
                    const n = row.modelData;
                    if (n.connected)
                        n.disconnect();
                    else if (n.known || !row.secured)
                        n.connect();
                    else
                        root.pending = root.pending === n ? null : n;
                }
            }

            RowLayout {
                x: 14
                width: parent.width - 28
                height: 52
                spacing: 12

                Icon {
                    name: row.modelData.signalStrength > 0.66 ? "network_wifi" : row.modelData.signalStrength > 0.33 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                    fill: 1
                    size: 20
                    color: row.modelData.connected ? Colours.fgPrimaryContainer : Colours.fgSurface
                }

                Txt {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    role: "bodyL"
                    color: row.modelData.connected ? Colours.fgPrimaryContainer : Colours.fgSurface
                }

                LoadingIndicator {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    visible: row.modelData.stateChanging
                }

                Icon {
                    visible: row.secured
                    name: "lock"
                    size: 16
                    color: Colours.fgSurfaceVariant
                }
            }

            RowLayout {
                visible: root.pending === row.modelData
                x: 14
                y: 52
                width: parent.width - 28
                height: 44
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: height / 2
                    color: Colours.surfaceContainerLowest

                    TextInput {
                        id: psk

                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Colours.fgSurface
                        font.family: Style.font
                        font.pixelSize: 14
                        focus: visible
                        onAccepted: {
                            row.modelData.connectWithPsk(text);
                            text = "";
                            root.pending = null;
                        }
                    }
                }

                IconButton {
                    icon: "arrow_forward"
                    variant: "filled"
                    size: 40
                    onClicked: psk.accepted()
                }
            }
        }
    }
}
