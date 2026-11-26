.pragma library

const ansi = /\x1b\[[0-9;]*[A-Za-z]/g;
const shellPrompt = /^\[[^\]]*\]# ?/;
const promptEcho = /^\[agent\] (?:.*\(yes\/no\)|Enter PIN code|Enter passkey \(number in 0-999999\)): ?/;
const rejectPin = "reject-pin-request";

const markers = {
    "Request confirmation": "confirm",
    "Request passkey": "passkey",
    "Request PIN code": "pin",
    "Request authorization": "authorize",
    "Authorize service": "service"
};

function create() {
    return { buf: "", pending: "" };
}

function segments(raw) {
    return raw.replace(ansi, "").split(/[\r\n]/).map(s => s.replace(shellPrompt, "").trim()).filter(s => s !== "");
}

function prompt(state, seg) {
    if (!state.pending)
        return null;
    let m;
    let ev = null;
    if (state.pending === "confirm" && (m = /^\[agent\] Confirm passkey (\d+) \(yes\/no\):/.exec(seg)))
        ev = { type: "request", kind: "confirm", code: m[1] };
    else if (state.pending === "passkey" && /^\[agent\] Enter passkey\b/.test(seg))
        ev = { type: "request", kind: "passkey" };
    else if (state.pending === "pin" && /^\[agent\] Enter PIN code:/.test(seg))
        ev = { type: "request", kind: "pin" };
    else if (state.pending === "authorize" && /^\[agent\] Accept pairing \(yes\/no\):/.test(seg))
        ev = { type: "request", kind: "authorize" };
    else if (state.pending === "service" && (m = /^\[agent\] Authorize service (\S+) \(yes\/no\):/.exec(seg)))
        ev = { type: "request", kind: "service", uuid: m[1] };
    if (ev)
        state.pending = "";
    return ev;
}

function line(state, raw, events) {
    for (const seg of segments(raw)) {
        const ev = prompt(state, seg);
        if (ev)
            events.push(ev);
        let m;
        const tail = seg.replace(promptEcho, "");
        if (markers[tail]) {
            state.pending = markers[tail];
        } else if (tail === "Request canceled") {
            state.pending = "";
            events.push({ type: "cancel" });
        } else if (seg === "Agent registered" || seg === "Agent is already registered") {
            events.push({ type: "registered" });
        } else if (seg === "Default agent request successful") {
            events.push({ type: "default" });
        } else if (seg === "Agent released" || seg === "Agent unregistered" || seg.startsWith("Waiting to connect to bluetoothd")) {
            state.pending = "";
            events.push({ type: "lost" });
        } else if ((m = /^\[agent\] Passkey: (\d+)/.exec(seg))) {
            const split = /Passkey: \x1b\[[0-9;]*m(\d*)\x1b\[[0-9;]*m(\d*)/.exec(raw);
            events.push({ type: "display", kind: "passkey", code: m[1], entered: split ? split[1].length : 0 });
        } else if ((m = /^\[agent\] PIN code: (\S+)/.exec(seg))) {
            events.push({ type: "display", kind: "pin", code: m[1], entered: 0 });
        } else if ((m = /^\[(?:NEW|CHG)\] Device ([0-9A-Fa-f:]{17})\b/.exec(seg))) {
            events.push({ type: "device", address: m[1].toUpperCase() });
        }
    }
}

function feed(state, chunk) {
    const events = [];
    state.buf += chunk;
    const lines = state.buf.split("\n");
    state.buf = lines.pop();
    for (const raw of lines)
        line(state, raw, events);
    if (state.pending) {
        for (const seg of segments(state.buf)) {
            const ev = prompt(state, seg);
            if (ev)
                events.push(ev);
        }
    }
    if (state.buf.length > 4096)
        state.buf = state.buf.slice(-1024);
    return events;
}

function passkey(input) {
    const s = String(input ?? "").trim();
    return /^\d{1,6}$/.test(s) ? String(parseInt(s, 10)) : null;
}

function pin(input) {
    const s = String(input ?? "").trim();
    return /^[\x21-\x7e]{1,16}$/.test(s) && !s.startsWith("#") ? s : null;
}

function answer(kind, accept, input) {
    if (kind === "passkey") {
        if (!accept)
            return "no\n";
        const v = passkey(input);
        return v === null ? null : v + "\n";
    }
    if (kind === "pin") {
        if (!accept)
            return rejectPin + "\n";
        const v = pin(input);
        return v === null ? null : v + "\n";
    }
    return accept ? "yes\n" : "no\n";
}

function service(uuid) {
    const id = String(uuid || "").slice(4, 8).toLowerCase();
    if (["110a", "110b", "110d"].includes(id))
        return "audio";
    if (["110c", "110e", "110f"].includes(id))
        return "media controls";
    if (["1108", "1112", "111e", "111f"].includes(id))
        return "calls";
    if (["1124", "1812"].includes(id))
        return "keyboard and mouse input";
    if (["1105", "1106"].includes(id))
        return "file transfer";
    if (["1115", "1116"].includes(id))
        return "networking";
    return "a bluetooth service";
}
