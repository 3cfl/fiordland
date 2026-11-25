pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config

Singleton {
    id: root

    readonly property bool demo: Config.demo
    readonly property var devices: demo ? [] : Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property bool wifiEnabled: demo ? demoEnabled : Networking.wifiEnabled
    readonly property var networks: wifi ? wifi.networks.values : []
    readonly property var active: networks.find(n => n.connected) ?? null
    readonly property real strength: demo ? 0.8 : (active?.signalStrength ?? 0)
    readonly property bool online: demo || wired !== null || active !== null
    readonly property string name: demo ? "fjordnet" : (wired ? "Ethernet" : (active?.name ?? ""))
    readonly property string icon: {
        if (wired)
            return "lan";
        if (!wifiEnabled)
            return "wifi_off";
        if (!active && !demo)
            return "signal_wifi_statusbar_not_connected";
        return strength > 0.75 ? "network_wifi" : strength > 0.5 ? "network_wifi_3_bar" : strength > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }
    readonly property var sorted: networks.slice().filter(n => n.name).sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength)).slice(0, 12)
    property bool demoEnabled: true

    function setWifi(on: bool): void {
        if (demo)
            demoEnabled = on;
        else
            Networking.wifiEnabled = on;
    }

    function scan(on: bool): void {
        if (wifi)
            wifi.scannerEnabled = on;
    }
}
