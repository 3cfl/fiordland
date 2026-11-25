pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool demo: Quickshell.env("CREST_DEMO") === "1"
    property var list: demo ? [
        { name: "aroha", display: "Aroha Ngata", icon: "", uid: 1000 },
        { name: "tama", display: "Tama Wiremu", icon: "", uid: 1001 },
        { name: "guest", display: "", icon: "", uid: 1002 }
    ] : []

    function find(name: string): var {
        for (const u of list)
            if (u.name === name)
                return u;
        return null;
    }

    function parse(text: string): void {
        const out = [];
        const bad = /\/(nologin|false|sync|shutdown|halt)$/;
        for (const line of text.split("\n")) {
            const f = line.split(":");
            if (f.length < 7)
                continue;
            const uid = parseInt(f[2]);
            if (!(uid >= 1000 && uid < 60000))
                continue;
            if (!/^[a-z_][a-z0-9_-]*[$]?$/.test(f[0]) || f[0].length > 32)
                continue;
            if (f[6] === "" || bad.test(f[6]))
                continue;
            out.push({
                name: f[0],
                display: (f[4] ?? "").split(",")[0].trim(),
                icon: `file:///var/lib/AccountsService/icons/${f[0]}`,
                uid: uid
            });
        }
        out.sort((a, b) => a.uid - b.uid);
        list = out;
    }

    FileView {
        path: root.demo ? "" : "/etc/passwd"
        printErrors: false
        onLoaded: root.parse(text())
    }
}
