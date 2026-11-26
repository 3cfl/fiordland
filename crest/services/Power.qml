pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config

Singleton {
    id: root

    readonly property bool demo: Config.demo
    readonly property UPowerDevice battery: demo ? null : UPower.displayDevice
    readonly property bool hasBattery: demo || ((battery?.isLaptopBattery ?? false) && (battery?.isPresent ?? false))
    readonly property real level: demo ? 0.76 : (battery?.percentage ?? 0)
    readonly property bool charging: demo ? false : (battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.FullyCharged)
    readonly property real timeLeft: demo ? 15840 : (charging ? (battery?.timeToFull ?? 0) : (battery?.timeToEmpty ?? 0))
    property int demoProfile: PowerProfile.Balanced
    readonly property int profile: demo ? demoProfile : PowerProfiles.profile
    readonly property bool hasPerformance: demo || PowerProfiles.hasPerformanceProfile
    readonly property string icon: {
        if (!hasBattery)
            return "power";
        if (charging)
            return "battery_android_bolt";
        const steps = ["battery_android_0", "battery_android_1", "battery_android_2", "battery_android_3", "battery_android_4", "battery_android_5", "battery_android_6", "battery_android_full"];
        return steps[Math.max(0, Math.min(7, Math.round(level * 7)))];
    }
    readonly property string profileName: profile === PowerProfile.PowerSaver ? "power saver" : profile === PowerProfile.Performance ? "performance" : "balanced"
    readonly property string profileIcon: profile === PowerProfile.PowerSaver ? "energy_savings_leaf" : profile === PowerProfile.Performance ? "bolt" : "balance"

    function setProfile(p: int): void {
        if (demo)
            demoProfile = p;
        else
            PowerProfiles.profile = p;
    }

    function cycleProfile(): void {
        const order = hasPerformance ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance] : [PowerProfile.PowerSaver, PowerProfile.Balanced];
        const i = order.indexOf(profile);
        setProfile(order[(i + 1) % order.length]);
    }

    function fmtTime(seconds: real): string {
        if (seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }
}
