pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

Glass {
    id: root

    property string page: "main"
    readonly property string user: Quickshell.env("USER") ?? ""

    implicitWidth: 412
    implicitHeight: column.implicitHeight + 32
    radius: Style.rXl

    Behavior on implicitHeight {
        SpringDefault {}
    }

    ColumnLayout {
        id: column

        x: 16
        y: 16
        width: parent.width - 32
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Avatar {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                shape: "cookie6"
                initial: root.user
                source: Config.demo ? "" : `file://${Config.home}/.face`
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Txt {
                    Layout.fillWidth: true
                    text: root.user || "you"
                    role: "titleM"
                }

                Txt {
                    Layout.fillWidth: true
                    text: Power.hasBattery ? `${Math.round(Power.level * 100)}%${Power.charging ? " · charging" : ""}${Power.timeLeft > 0 ? " · " + Power.fmtTime(Power.timeLeft) + (Power.charging ? " to full" : " left") : ""}` : Qt.formatDate(new Date(), "dddd d MMMM")
                    role: "bodyS"
                    color: Colours.fgSurfaceVariant
                }
            }

            IconButton {
                icon: "wallpaper"
                variant: "tonal"
                size: 40
                onClicked: Panels.show("wallpaper")
            }

            IconButton {
                icon: "settings"
                variant: "tonal"
                size: 40
                onClicked: Panels.openSettings("appearance")
            }

            IconButton {
                icon: "power_settings_new"
                variant: "filled"
                size: 40
                onClicked: Panels.show("session")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.page === "main"
            spacing: 12

            Slider {
                Layout.fillWidth: true
                icon: Audio.icon
                value: Audio.muted ? 0 : Audio.volume
                showValue: true
                onMoved: v => Audio.setVolume(v)
            }

            Slider {
                Layout.fillWidth: true
                visible: Brightness.available
                icon: "light_mode"
                value: Brightness.value
                showValue: true
                onMoved: v => Brightness.set(v)
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                Tile {
                    Layout.fillWidth: true
                    icon: Net.wifiEnabled ? Net.icon : "wifi_off"
                    label: "Wi‑Fi"
                    sublabel: !Net.wifiEnabled ? "off" : (Net.name || "not connected")
                    active: Net.wifiEnabled
                    details: true
                    onClicked: Net.setWifi(!Net.wifiEnabled)
                    onSecondaryClicked: root.page = "wifi"
                }

                Tile {
                    Layout.fillWidth: true
                    visible: Bt.available
                    icon: Bt.connected.length > 0 ? "bluetooth_connected" : "bluetooth"
                    label: "Bluetooth"
                    sublabel: Bt.label
                    active: Bt.enabled
                    onClicked: Bt.setEnabled(!Bt.enabled)
                }

                Tile {
                    Layout.fillWidth: true
                    icon: Power.profileIcon
                    label: "Power mode"
                    sublabel: Power.profileName
                    active: Power.profileName !== "balanced"
                    onClicked: Power.cycleProfile()
                }

                Tile {
                    Layout.fillWidth: true
                    icon: Notifs.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                    label: "Do not disturb"
                    sublabel: Notifs.dnd ? "on" : "off"
                    active: Notifs.dnd
                    onClicked: Notifs.dnd = !Notifs.dnd
                }

                Tile {
                    Layout.fillWidth: true
                    icon: "nightlight"
                    label: "Night light"
                    sublabel: NightLight.enabled ? `${NightLight.temperature} K` : "off"
                    active: NightLight.enabled
                    onClicked: NightLight.toggle()
                }

                Tile {
                    Layout.fillWidth: true
                    icon: Colours.light ? "light_mode" : "dark_mode"
                    label: "Dark mode"
                    sublabel: Colours.light ? "off" : "on"
                    active: !Colours.light
                    onClicked: Config.appearance.mode = Colours.light ? "dark" : "light"
                }
            }

            MediaCard {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: Media.available
            }
        }

        WifiPage {
            Layout.fillWidth: true
            visible: root.page === "wifi"
            onBack: root.page = "main"
        }
    }
}
