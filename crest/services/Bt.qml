pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config

Singleton {
    id: root

    readonly property bool demo: Config.demo
    readonly property BluetoothAdapter adapter: demo ? null : Bluetooth.defaultAdapter
    readonly property bool available: demo || adapter !== null
    property bool demoEnabled: false
    readonly property bool enabled: demo ? demoEnabled : (adapter?.enabled ?? false)
    readonly property var devices: demo ? [] : (adapter ? adapter.devices.values : [])
    readonly property var connected: devices.filter(d => d.connected)
    readonly property string label: connected.length === 1 ? connected[0].name : connected.length > 1 ? `${connected.length} devices` : (enabled ? "on" : "off")

    function setEnabled(on: bool): void {
        if (demo)
            demoEnabled = on;
        else if (adapter)
            adapter.enabled = on;
    }
}
