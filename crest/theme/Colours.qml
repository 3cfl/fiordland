pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool light: false
    property var scheme: null

    readonly property var fjordDark: ({
            primary: "#9ECAFF",
            onPrimary: "#00325A",
            primaryContainer: "#1D4A74",
            onPrimaryContainer: "#D2E4FF",
            secondary: "#BAC8DB",
            onSecondary: "#243140",
            secondaryContainer: "#3A4857",
            onSecondaryContainer: "#D6E4F7",
            tertiary: "#86D6CB",
            onTertiary: "#003732",
            tertiaryContainer: "#00504A",
            onTertiaryContainer: "#A2F2E6",
            error: "#FFB4AB",
            onError: "#690005",
            errorContainer: "#93000A",
            onErrorContainer: "#FFDAD6",
            surface: "#0E1217",
            surfaceDim: "#0E1217",
            surfaceBright: "#34383E",
            surfaceContainerLowest: "#090D12",
            surfaceContainerLow: "#161B21",
            surfaceContainer: "#1A1F25",
            surfaceContainerHigh: "#252A30",
            surfaceContainerHighest: "#30353B",
            onSurface: "#E1E2E8",
            onSurfaceVariant: "#C1C7D0",
            outline: "#8B919A",
            outlineVariant: "#41474F",
            inverseSurface: "#E1E2E8",
            inverseOnSurface: "#2E3135",
            inversePrimary: "#2C6197",
            scrim: "#000000",
            shadow: "#000000"
        })

    readonly property var fjordLight: ({
            primary: "#2C6197",
            onPrimary: "#FFFFFF",
            primaryContainer: "#D2E4FF",
            onPrimaryContainer: "#001C37",
            secondary: "#535F70",
            onSecondary: "#FFFFFF",
            secondaryContainer: "#D6E4F7",
            onSecondaryContainer: "#0F1D2A",
            tertiary: "#006A62",
            onTertiary: "#FFFFFF",
            tertiaryContainer: "#A2F2E6",
            onTertiaryContainer: "#00201D",
            error: "#BA1A1A",
            onError: "#FFFFFF",
            errorContainer: "#FFDAD6",
            onErrorContainer: "#410002",
            surface: "#F8F9FF",
            surfaceDim: "#D8DAE0",
            surfaceBright: "#F8F9FF",
            surfaceContainerLowest: "#FFFFFF",
            surfaceContainerLow: "#F2F3F9",
            surfaceContainer: "#ECEEF4",
            surfaceContainerHigh: "#E6E8EE",
            surfaceContainerHighest: "#E1E2E8",
            onSurface: "#191C20",
            onSurfaceVariant: "#41474F",
            outline: "#717880",
            outlineVariant: "#C1C7D0",
            inverseSurface: "#2E3135",
            inverseOnSurface: "#EFF0F7",
            inversePrimary: "#9ECAFF",
            scrim: "#000000",
            shadow: "#000000"
        })

    readonly property var roles: Object.keys(fjordDark)

    function pick(name: string): color {
        const s = root.scheme;
        if (s && typeof s[name] === "string" && /^#[0-9a-fA-F]{6}$/.test(s[name]))
            return s[name];
        return root.light ? root.fjordLight[name] : root.fjordDark[name];
    }

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    readonly property color primary: pick("primary")
    readonly property color onPrimary: pick("onPrimary")
    readonly property color primaryContainer: pick("primaryContainer")
    readonly property color onPrimaryContainer: pick("onPrimaryContainer")
    readonly property color secondary: pick("secondary")
    readonly property color onSecondary: pick("onSecondary")
    readonly property color secondaryContainer: pick("secondaryContainer")
    readonly property color onSecondaryContainer: pick("onSecondaryContainer")
    readonly property color tertiary: pick("tertiary")
    readonly property color onTertiary: pick("onTertiary")
    readonly property color tertiaryContainer: pick("tertiaryContainer")
    readonly property color onTertiaryContainer: pick("onTertiaryContainer")
    readonly property color error: pick("error")
    readonly property color onError: pick("onError")
    readonly property color errorContainer: pick("errorContainer")
    readonly property color onErrorContainer: pick("onErrorContainer")
    readonly property color surface: pick("surface")
    readonly property color surfaceDim: pick("surfaceDim")
    readonly property color surfaceBright: pick("surfaceBright")
    readonly property color surfaceContainerLowest: pick("surfaceContainerLowest")
    readonly property color surfaceContainerLow: pick("surfaceContainerLow")
    readonly property color surfaceContainer: pick("surfaceContainer")
    readonly property color surfaceContainerHigh: pick("surfaceContainerHigh")
    readonly property color surfaceContainerHighest: pick("surfaceContainerHighest")
    readonly property color onSurface: pick("onSurface")
    readonly property color onSurfaceVariant: pick("onSurfaceVariant")
    readonly property color outline: pick("outline")
    readonly property color outlineVariant: pick("outlineVariant")
    readonly property color inverseSurface: pick("inverseSurface")
    readonly property color inverseOnSurface: pick("inverseOnSurface")
    readonly property color inversePrimary: pick("inversePrimary")
    readonly property color scrim: pick("scrim")
    readonly property color shadow: pick("shadow")
}
