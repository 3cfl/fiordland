pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool locked: false
    property string uptime: ""

    function lock(): void {
        if (!Config.demo)
            locked = true;
    }

    onLockedChanged: {
        if (locked)
            Panels.close();
    }

    function run(id: string): void {
        if (Config.demo)
            return;
        if (id === "lock") {
            lock();
        } else if (id === "suspend") {
            if (Config.lock.lockBeforeSleep)
                lock();
            Quickshell.execDetached(["systemctl", "suspend"]);
        } else if (id === "logout") {
            const sid = Quickshell.env("XDG_SESSION_ID") ?? "";
            if (/^[A-Za-z0-9_-]+$/.test(sid))
                Quickshell.execDetached(["loginctl", "terminate-session", sid]);
            else
                Hypr.exit();
        } else if (id === "reboot") {
            Quickshell.execDetached(["systemctl", "reboot"]);
        } else if (id === "poweroff") {
            Quickshell.execDetached(["systemctl", "poweroff"]);
        }
    }

    function refreshUptime(): void {
        if (Config.demo) {
            uptime = "3 h 12 min";
            return;
        }
        uptimeFile.reload();
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        printErrors: false
        onLoaded: {
            const s = Math.floor(parseFloat(text().split(" ")[0]) || 0);
            const d = Math.floor(s / 86400);
            const h = Math.floor((s % 86400) / 3600);
            const m = Math.floor((s % 3600) / 60);
            root.uptime = d > 0 ? `${d} d ${h} h` : h > 0 ? `${h} h ${m} min` : `${m} min`;
        }
    }
}
