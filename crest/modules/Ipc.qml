pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services

Scope {
    id: root

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Panels.toggle("launcher");
        }

        function open(): void {
            Panels.openLauncher("");
        }

        function close(): void {
            if (Panels.launcher)
                Panels.close();
        }

        function emoji(): void {
            Panels.openLauncher(":");
        }

        function calc(): void {
            Panels.openLauncher("=");
        }
    }

    IpcHandler {
        target: "quicksettings"

        function toggle(): void {
            Panels.toggle("quicksettings");
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            Panels.toggle("notifications");
        }

        function clear(): void {
            Notifs.clear();
        }

        function dnd(): void {
            Notifs.dnd = !Notifs.dnd;
        }

        function count(): int {
            return Notifs.count;
        }
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            Panels.toggle("session");
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            Session.lock();
        }

        function isLocked(): bool {
            return Session.locked;
        }
    }

    IpcHandler {
        target: "media"

        function toggle(): void {
            Media.toggle();
        }

        function next(): void {
            Media.next();
        }

        function previous(): void {
            Media.previous();
        }

        function stop(): void {
            Media.stop();
        }
    }

    IpcHandler {
        target: "volume"

        function up(): void {
            Audio.setVolume(Audio.volume + 0.05);
        }

        function down(): void {
            Audio.setVolume(Audio.volume - 0.05);
        }

        function mute(): void {
            Audio.toggleMute();
        }

        function set(percent: int): void {
            Audio.setVolume(percent / 100);
        }
    }

    IpcHandler {
        target: "brightness"

        function up(): void {
            Brightness.step(1);
        }

        function down(): void {
            Brightness.step(-1);
        }

        function set(percent: int): void {
            Brightness.set(percent / 100);
        }
    }

    IpcHandler {
        target: "wallpaper"

        function picker(): void {
            Panels.toggle("wallpaper");
        }

        function set(path: string): void {
            Wallpapers.set(path);
        }

        function get(): string {
            return Wallpapers.current;
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            Panels.toggle("overview");
        }
    }

    IpcHandler {
        target: "settings"

        function open(page: string): void {
            Panels.openSettings(page);
        }

        function toggle(): void {
            Panels.settings = !Panels.settings;
        }
    }

    IpcHandler {
        target: "appearance"

        function dark(): void {
            Config.appearance.mode = "dark";
        }

        function light(): void {
            Config.appearance.mode = "light";
        }

        function toggle(): void {
            Config.appearance.mode = Config.appearance.mode === "light" ? "dark" : "light";
        }

        function lowEnd(mode: string): void {
            if (["auto", "on", "off"].indexOf(mode) >= 0)
                Config.performance.lowEnd = mode;
        }
    }

    Shortcut {
        name: "launcher"
        onPressed: Panels.toggle("launcher")
    }

    Shortcut {
        name: "emoji"
        onPressed: Panels.openLauncher(":")
    }

    Shortcut {
        name: "quicksettings"
        onPressed: Panels.toggle("quicksettings")
    }

    Shortcut {
        name: "notifications"
        onPressed: Panels.toggle("notifications")
    }

    Shortcut {
        name: "clearNotifs"
        onPressed: Notifs.clear()
    }

    Shortcut {
        name: "session"
        onPressed: Panels.toggle("session")
    }

    Shortcut {
        name: "lock"
        onPressed: Session.lock()
    }

    Shortcut {
        name: "overview"
        onPressed: Panels.toggle("overview")
    }

    Shortcut {
        name: "wallpaper"
        onPressed: Panels.toggle("wallpaper")
    }

    Shortcut {
        name: "settings"
        onPressed: Panels.settings = !Panels.settings
    }

    Shortcut {
        name: "mediaToggle"
        onPressed: Media.toggle()
    }

    Shortcut {
        name: "mediaNext"
        onPressed: Media.next()
    }

    Shortcut {
        name: "mediaPrev"
        onPressed: Media.previous()
    }

    Shortcut {
        name: "mediaStop"
        onPressed: Media.stop()
    }

    Shortcut {
        name: "volumeUp"
        onPressed: Audio.setVolume(Audio.volume + 0.05)
    }

    Shortcut {
        name: "volumeDown"
        onPressed: Audio.setVolume(Audio.volume - 0.05)
    }

    Shortcut {
        name: "volumeMute"
        onPressed: Audio.toggleMute()
    }

    Shortcut {
        name: "brightnessUp"
        onPressed: Brightness.step(1)
    }

    Shortcut {
        name: "brightnessDown"
        onPressed: Brightness.step(-1)
    }

    component Shortcut: GlobalShortcut {
        appid: "crest"
    }
}
