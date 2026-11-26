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

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            Panels.toggle("dashboard");
        }

        function media(): void {
            Panels.openDashboard("media");
        }

        function system(): void {
            Panels.openDashboard("system");
        }

        function clipboard(): void {
            Panels.openDashboard("clipboard");
        }
    }

    IpcHandler {
        target: "capture"

        function toggle(): void {
            if (Capture.recording)
                Capture.stop();
            else
                Panels.toggle("capture");
        }

        function screenshot(mode: string): void {
            Capture.shot(mode || "region");
        }

        function record(mode: string): void {
            Capture.record(mode || "region");
        }

        function stop(): void {
            Capture.stop();
        }

        function isRecording(): bool {
            return Capture.recording;
        }
    }

    GlobalShortcut {
        appid: "crest"
        name: "dashboard"
        onPressed: Panels.toggle("dashboard")
    }

    GlobalShortcut {
        appid: "crest"
        name: "clipboard"
        onPressed: Panels.openDashboard("clipboard")
    }

    GlobalShortcut {
        appid: "crest"
        name: "capture"
        onPressed: Capture.recording ? Capture.stop() : (Panels.open && !Panels.capture) ? Capture.shot(Config.capture.mode || "region") : Panels.toggle("capture")
    }

    GlobalShortcut {
        appid: "crest"
        name: "screenshotRegion"
        onPressed: Capture.shot("region")
    }

    GlobalShortcut {
        appid: "crest"
        name: "screenshotScreen"
        onPressed: Capture.shot("screen")
    }

    GlobalShortcut {
        appid: "crest"
        name: "recordRegion"
        onPressed: Capture.record("region")
    }

    GlobalShortcut {
        appid: "crest"
        name: "launcher"
        onPressed: Panels.toggle("launcher")
    }

    GlobalShortcut {
        appid: "crest"
        name: "launcherTap"
        onReleased: if (!Session.locked) Panels.toggle("launcher")
    }

    GlobalShortcut {
        appid: "crest"
        name: "emoji"
        onPressed: Panels.openLauncher(":")
    }

    GlobalShortcut {
        appid: "crest"
        name: "quicksettings"
        onPressed: Panels.toggle("quicksettings")
    }

    GlobalShortcut {
        appid: "crest"
        name: "notifications"
        onPressed: Panels.toggle("notifications")
    }

    GlobalShortcut {
        appid: "crest"
        name: "clearNotifs"
        onPressed: Notifs.clear()
    }

    GlobalShortcut {
        appid: "crest"
        name: "session"
        onPressed: Panels.toggle("session")
    }

    GlobalShortcut {
        appid: "crest"
        name: "lock"
        onReleased: Session.lock()
    }

    GlobalShortcut {
        appid: "crest"
        name: "overview"
        onPressed: Panels.toggle("overview")
    }

    GlobalShortcut {
        appid: "crest"
        name: "wallpaper"
        onPressed: Panels.toggle("wallpaper")
    }

    GlobalShortcut {
        appid: "crest"
        name: "settings"
        onPressed: Panels.settings = !Panels.settings
    }

    GlobalShortcut {
        appid: "crest"
        name: "mediaToggle"
        onPressed: Media.toggle()
    }

    GlobalShortcut {
        appid: "crest"
        name: "mediaNext"
        onPressed: Media.next()
    }

    GlobalShortcut {
        appid: "crest"
        name: "mediaPrev"
        onPressed: Media.previous()
    }

    GlobalShortcut {
        appid: "crest"
        name: "mediaStop"
        onPressed: Media.stop()
    }

    GlobalShortcut {
        appid: "crest"
        name: "volumeUp"
        onPressed: Audio.setVolume(Audio.volume + 0.05)
    }

    GlobalShortcut {
        appid: "crest"
        name: "volumeDown"
        onPressed: Audio.setVolume(Audio.volume - 0.05)
    }

    GlobalShortcut {
        appid: "crest"
        name: "volumeMute"
        onPressed: Audio.toggleMute()
    }

    GlobalShortcut {
        appid: "crest"
        name: "brightnessUp"
        onPressed: Brightness.step(1)
    }

    GlobalShortcut {
        appid: "crest"
        name: "brightnessDown"
        onPressed: Brightness.step(-1)
    }
}
