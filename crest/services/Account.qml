pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") ?? ""
    property string realName: ""
    property string shell: ""
    property string keyringState: "off"
    readonly property bool keyring: keyringState !== "off"
    property int uid: 1000
    readonly property string displayName: realName !== "" ? realName : user
    readonly property string facePath: Config.demo ? "" : `file://${Config.home}/.face`
    property string face: ""
    readonly property string objectPath: `/org/freedesktop/Accounts/User${uid}`
    readonly property string greeting: {
        const h = clock.hours;
        if (h < 5)
            return "good night";
        if (h < 12)
            return "good morning";
        if (h < 18)
            return "good afternoon";
        return "good evening";
    }

    function refresh(): void {
        info.running = true;
        keyringProbe.running = true;
        faceCheck.running = true;
    }

    function setRealName(name: string): void {
        realName = name;
        Quickshell.execDetached(["busctl", "call", "org.freedesktop.Accounts", objectPath, "org.freedesktop.Accounts.User", "SetRealName", "s", name]);
    }

    function setFace(path: string): void {
        faceProc.command = ["sh", "-c", 'cp -f -- "$1" "$HOME/.face" && busctl call org.freedesktop.Accounts "$2" org.freedesktop.Accounts.User SetIconFile s "$HOME/.face" >/dev/null 2>&1; true', "sh", path, objectPath];
        faceProc.running = true;
    }

    function changePassword(): void {
        const term = Quickshell.env("TERMINAL") || "kitty";
        Quickshell.execDetached([term, "--title", "change password", "-e", "bash", "-c", "passwd; echo; read -n1 -rsp 'press any key to close'"]);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    Process {
        id: info

        running: !Config.demo
        command: ["sh", "-c", 'getent passwd "$(id -un)"']
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(":");
                if (f.length < 7)
                    return;
                root.uid = parseInt(f[2]) || 1000;
                root.realName = (f[4] ?? "").split(",")[0];
                root.shell = f[6];
            }
        }
    }

    Process {
        id: keyringProbe

        running: !Config.demo
        command: ["sh", "-c", 'busctl --user status org.freedesktop.secrets >/dev/null 2>&1 || { echo off; exit; }; c=$(busctl --user call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.Secret.Service ReadAlias s default 2>/dev/null | cut -d\\" -f2); [ -n "$c" ] && [ "$c" != / ] || { echo empty; exit; }; v=$(busctl --user get-property org.freedesktop.secrets "$c" org.freedesktop.Secret.Collection Locked 2>/dev/null); [ "$v" = "b true" ] && echo locked || echo unlocked']
        stdout: StdioCollector {
            onStreamFinished: root.keyringState = text.trim() || "off"
        }
    }

    Process {
        id: faceCheck

        running: !Config.demo
        command: ["sh", "-c", 'test -s "$HOME/.face"']
        onExited: code => root.face = code === 0 ? root.facePath : ""
    }

    Process {
        id: faceProc

        onExited: {
            root.face = "";
            faceCheck.running = true;
        }
    }
}
