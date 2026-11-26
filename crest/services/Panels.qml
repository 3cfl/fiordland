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
    property string dashboardTab: "home"

    readonly property bool launcher: open === "launcher"
    readonly property bool quicksettings: open === "quicksettings"
    readonly property bool notifications: open === "dashboard" && dashboardTab === "home"
    readonly property bool session: open === "session"
    readonly property bool wallpaper: open === "wallpaper"
    readonly property bool overview: open === "overview"
    readonly property bool dashboard: open === "dashboard"
    readonly property bool capture: open === "capture"
    readonly property var screen: {
        const screens = Quickshell.screens;
        if (Config.demo)
            return screens[0] ?? null;
        const name = Hyprland.focusedMonitor?.name ?? "";
        return screens.find(s => s.name === name) ?? screens[0] ?? null;
    }

    function toggle(name: string): void {
        if (name === "notifications" || name === "dashboard") {
            openDashboard(name === "notifications" ? "home" : dashboardTab);
            return;
        }
        open = open === name ? "" : name;
    }

    function show(name: string): void {
        if (name === "notifications") {
            dashboardTab = "home";
            name = "dashboard";
        }
        open = name;
    }

    function close(): void {
        open = "";
    }

    function openDashboard(tab: string): void {
        if (open === "dashboard" && dashboardTab === tab) {
            open = "";
            return;
        }
        dashboardTab = tab;
        open = "dashboard";
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
