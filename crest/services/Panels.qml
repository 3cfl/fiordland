pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

Singleton {
    id: root

    property string open: ""
    property string launcherSeed: ""
    property bool settings: false
    property string settingsPage: "appearance"

    readonly property bool launcher: open === "launcher"
    readonly property bool quicksettings: open === "quicksettings"
    readonly property bool notifications: open === "notifications"
    readonly property bool session: open === "session"
    readonly property bool wallpaper: open === "wallpaper"
    readonly property bool overview: open === "overview"
    readonly property var screen: {
        const screens = Quickshell.screens;
        if (Config.demo)
            return screens[0] ?? null;
        const name = Hyprland.focusedMonitor?.name ?? "";
        return screens.find(s => s.name === name) ?? screens[0] ?? null;
    }

    function toggle(name: string): void {
        open = open === name ? "" : name;
    }

    function show(name: string): void {
        open = name;
    }

    function close(): void {
        open = "";
    }

    function openLauncher(seed: string): void {
        launcherSeed = seed;
        open = "launcher";
    }

    function openSettings(page: string): void {
        if (page)
            settingsPage = page;
        open = "";
        settings = true;
    }
}
