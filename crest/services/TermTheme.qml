pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme

Singleton {
    id: root

    readonly property bool enabled: Config.loaded && Config.appearance.terminal && !Config.demo
    readonly property string file: (Quickshell.env("XDG_CONFIG_HOME")?.startsWith("/") ? Quickshell.env("XDG_CONFIG_HOME") : Config.home + "/.config") + "/kitty/crest-colors.conf"
    property string written: ""
    readonly property string theme: build()

    onThemeChanged: debounce.restart()
    onEnabledChanged: debounce.restart()

    function hex(c: color): string {
        const h = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
        return `#${h(c.r)}${h(c.g)}${h(c.b)}`;
    }

    function harmonize(hue: real, anchor: real): real {
        if (anchor < 0)
            return hue;
        let d = anchor - hue;
        if (d > 0.5)
            d -= 1;
        if (d < -0.5)
            d += 1;
        const shift = Math.max(-0.035, Math.min(0.035, d * 0.2));
        return (hue + shift + 1) % 1;
    }

    function ansi(): var {
        const anchor = Colours.primary.hslHue;
        const light = Colours.light;
        const hues = [0.0, 0.36, 0.12, 0.6, 0.83, 0.5];
        const normal = [];
        const bright = [];
        for (const h of hues) {
            const hue = harmonize(h, anchor);
            const yellow = h === 0.12;
            normal.push(Qt.hsla(hue, light ? 0.62 : 0.6, light ? (yellow ? 0.34 : 0.4) : (yellow ? 0.66 : 0.7), 1));
            bright.push(Qt.hsla(hue, light ? 0.7 : 0.72, light ? (yellow ? 0.28 : 0.32) : (yellow ? 0.76 : 0.8), 1));
        }
        return { normal, bright };
    }

    function build(): string {
        const a = ansi();
        const black = Colours.light ? Colours.inverseSurface : Colours.surfaceContainerHighest;
        const brightBlack = Colours.outline;
        const white = Colours.light ? Colours.outlineVariant : Colours.fgSurfaceVariant;
        const brightWhite = Colours.light ? Colours.surfaceContainerHigh : Colours.fgSurface;
        const lines = [
            ["background", Colours.surface],
            ["foreground", Colours.fgSurface],
            ["cursor", Colours.primary],
            ["cursor_text_color", Colours.fgPrimary],
            ["selection_background", Colours.primaryContainer],
            ["selection_foreground", Colours.fgPrimaryContainer],
            ["url_color", Colours.tertiary],
            ["active_border_color", Colours.primary],
            ["inactive_border_color", Colours.outlineVariant],
            ["bell_border_color", Colours.error],
            ["active_tab_background", Colours.primary],
            ["active_tab_foreground", Colours.fgPrimary],
            ["inactive_tab_background", Colours.surfaceContainerHigh],
            ["inactive_tab_foreground", Colours.fgSurfaceVariant],
            ["tab_bar_background", Colours.surfaceContainerLowest],
            ["mark1_background", Colours.primary],
            ["mark1_foreground", Colours.fgPrimary],
            ["mark2_background", Colours.tertiary],
            ["mark2_foreground", Colours.fgTertiary],
            ["color0", black],
            ["color8", brightBlack]
        ];
        for (let i = 0; i < 6; i++) {
            lines.push([`color${i + 1}`, a.normal[i]]);
            lines.push([`color${i + 9}`, a.bright[i]]);
        }
        lines.push(["color7", white]);
        lines.push(["color15", brightWhite]);
        return lines.map(l => `${l[0]} ${hex(l[1])}`).join("\n") + "\n";
    }

    Timer {
        id: debounce

        interval: 600
        onTriggered: {
            if (!Config.loaded || Config.demo)
                return;
            if (root.enabled) {
                if (root.written === root.theme)
                    return;
                root.written = root.theme;
                Quickshell.execDetached(["sh", "-c", 'f=$1; mkdir -p "$(dirname "$f")" || exit 1; printf "%s" "$2" > "$f.tmp" && mv -f "$f.tmp" "$f" && pkill -USR1 -x kitty; true', "sh", root.file, root.theme]);
            } else if (root.written !== "off") {
                root.written = "off";
                Quickshell.execDetached(["sh", "-c", '[ -e "$1" ] || exit 0; rm -f "$1" && pkill -USR1 -x kitty; true', "sh", root.file]);
            }
        }
    }
}
