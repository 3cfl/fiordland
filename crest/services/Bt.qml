pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.config
import "../utils/btagent.js" as Agent

Singleton {
    id: root

    readonly property bool demo: Config.demo
    readonly property BluetoothAdapter adapter: demo ? null : Bluetooth.defaultAdapter
    readonly property bool available: demo || adapter !== null
    property bool demoEnabled: true
    readonly property bool enabled: demo ? demoEnabled : (adapter?.enabled ?? false)
    readonly property bool scanning: demo ? pageOpen : (adapter?.discovering ?? false)
    readonly property var deviceModel: adapter?.devices ?? null
    readonly property var devices: demo ? demoDevices : (deviceModel ? deviceModel.values : [])
    readonly property var connected: devices.filter(d => d.connected)
    readonly property var paired: devices.filter(d => d.paired).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: devices.filter(d => !d.paired && (d.pairing || root.named(d))).sort((a, b) => (b.pairing - a.pairing) || a.name.localeCompare(b.name)).slice(0, 12)
    readonly property string label: connected.length === 1 ? connected[0].name : connected.length > 1 ? `${connected.length} devices` : (enabled ? "on" : "off")

    property bool pageOpen: false
    property bool agentReady: demo
    property var request: null
    property var watched: null
    property var pairTarget: null
    property string failedAddress: ""
    property string trustAddress: ""
    property string lastAddress: ""
    property var parser: Agent.create()
    property int backoff: 2000

    readonly property var demoDevices: [
        { name: "Pixel Buds Pro", address: "4C:87:5D:10:22:31", icon: "audio-headset", connected: true, paired: true, pairing: false, batteryAvailable: true, battery: 0.72, state: BluetoothDeviceState.Connected },
        { name: "MX Master 3S", address: "D4:3A:2C:91:0E:58", icon: "input-mouse", connected: true, paired: true, pairing: false, batteryAvailable: true, battery: 0.38, state: BluetoothDeviceState.Connected },
        { name: "Keychron K2", address: "DC:2C:26:4B:7A:11", icon: "input-keyboard", connected: false, paired: true, pairing: false, batteryAvailable: false, battery: 0, state: BluetoothDeviceState.Disconnected },
        { name: "Living room speaker", address: "00:1A:7D:DA:71:13", icon: "audio-card", connected: false, paired: false, pairing: true, batteryAvailable: false, battery: 0, state: BluetoothDeviceState.Disconnected },
        { name: "Pixel 9", address: "A8:9C:ED:42:0B:6F", icon: "phone", connected: false, paired: false, pairing: false, batteryAvailable: false, battery: 0, state: BluetoothDeviceState.Disconnected }
    ]
    readonly property var demoRequest: ({ kind: "confirm", code: "482915", uuid: "", entered: 0, display: false, name: "Pixel 9", address: "A8:9C:ED:42:0B:6F", icon: "phone" })

    function named(d: var): bool {
        return !!d.name && d.name.replace(/[-:]/g, "") !== d.address.replace(/[-:]/g, "");
    }

    function setEnabled(on: bool): void {
        if (demo)
            demoEnabled = on;
        else if (adapter)
            adapter.enabled = on;
    }

    function scan(on: bool): void {
        if (!demo && adapter && adapter.enabled && adapter.discovering !== on)
            adapter.discovering = on;
    }

    function busy(d: var): bool {
        return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting;
    }

    function toggle(d: var): void {
        if (demo || busy(d))
            return;
        if (d.connected)
            d.disconnect();
        else
            d.connect();
    }

    function pair(d: var): void {
        if (demo || busy(d))
            return;
        failedAddress = "";
        pairTarget = d;
        d.pair();
    }

    function forget(d: var): void {
        if (!demo)
            d.forget();
    }

    function icon(name: string): string {
        const n = name ?? "";
        if (n.includes("headset") || n.includes("headphone"))
            return "headphones";
        if (n.includes("audio") || n.includes("speaker"))
            return "speaker";
        if (n.includes("keyboard"))
            return "keyboard";
        if (n.includes("mouse"))
            return "mouse";
        if (n.includes("gaming") || n.includes("joystick"))
            return "sports_esports";
        if (n.includes("phone"))
            return "smartphone";
        if (n.includes("computer"))
            return "computer";
        if (n.includes("watch"))
            return "watch";
        return "bluetooth";
    }

    function status(d: var): string {
        if (d.pairing)
            return "pairing…";
        if (d.state === BluetoothDeviceState.Connecting)
            return "connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "disconnecting…";
        if (d.address === failedAddress)
            return "couldn't pair, try again";
        if (d.connected)
            return d.batteryAvailable ? `connected · ${Math.round(d.battery * 100)}%` : "connected";
        return d.paired ? "saved" : d.address;
    }

    function find(address: string): var {
        return address ? (devices.find(d => d.address === address) ?? null) : null;
    }

    function accept(): void {
        answer(true, "");
    }

    function reject(): void {
        if (!request)
            return;
        if (request.display) {
            request = null;
            return;
        }
        answer(false, "");
    }

    function submit(input: string): bool {
        return answer(true, input);
    }

    function answer(ok: bool, input: string): bool {
        if (!request || request.display)
            return false;
        if (demo) {
            request = null;
            return true;
        }
        const line = Agent.answer(request.kind, ok, input);
        if (line === null)
            return false;
        agent.write(line);
        trustAddress = ok ? request.address : "";
        request = null;
        return true;
    }

    function serviceName(uuid: string): string {
        return Agent.service(uuid);
    }

    function handle(events: var): void {
        for (const e of events) {
            if (e.type === "registered") {
                agent.write("default-agent\n");
            } else if (e.type === "default") {
                agentReady = true;
                backoff = 2000;
            } else if (e.type === "lost") {
                agentReady = false;
                request = null;
            } else if (e.type === "device") {
                lastAddress = e.address;
            } else if (e.type === "cancel") {
                if (request && !request.display)
                    failedAddress = request.address;
                request = null;
            } else if (e.type === "request" || e.type === "display") {
                const d = devices.find(x => x.pairing) ?? find(lastAddress);
                watched = d;
                if (e.type === "display")
                    trustAddress = d?.address ?? "";
                request = {
                    kind: e.kind,
                    code: e.code ?? "",
                    uuid: e.uuid ?? "",
                    entered: e.entered ?? 0,
                    display: e.type === "display",
                    name: d?.name ?? "",
                    address: d?.address ?? lastAddress,
                    icon: d?.icon ?? ""
                };
            }
        }
    }

    function startAgent(): void {
        if (demo || !available || agent.running)
            return;
        parser = Agent.create();
        agent.running = true;
    }

    onAvailableChanged: {
        if (available)
            startAgent();
        else
            agent.running = false;
    }
    Component.onCompleted: startAgent()

    Process {
        id: agent

        command: ["bluetoothctl", "--agent", "KeyboardDisplay"]
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root.handle(Agent.feed(root.parser, data))
        }
        onExited: {
            root.agentReady = false;
            root.request = null;
            if (root.available && !root.demo)
                retry.start();
        }
    }

    Timer {
        id: retry

        interval: root.backoff
        onTriggered: {
            root.backoff = Math.min(60000, root.backoff * 2);
            root.startAgent();
        }
    }

    Connections {
        target: root.watched

        function onPairedChanged(): void {
            const d = root.watched;
            if (!d?.paired)
                return;
            if (root.request?.display)
                root.request = null;
            if (d.address === root.trustAddress) {
                d.trusted = true;
                root.trustAddress = "";
            }
        }
    }

    Connections {
        target: root.pairTarget

        function onPairedChanged(): void {
            const d = root.pairTarget;
            if (!d?.paired)
                return;
            root.pairTarget = null;
            d.trusted = true;
            d.connect();
        }

        function onPairingChanged(): void {
            if (root.pairTarget && !root.pairTarget.pairing)
                pairCheck.restart();
        }
    }

    Timer {
        id: pairCheck

        interval: 1000
        onTriggered: {
            const d = root.pairTarget;
            if (d && !d.paired && !d.pairing) {
                root.failedAddress = d.address;
                root.pairTarget = null;
            }
        }
    }
}
