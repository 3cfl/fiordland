pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme

Singleton {
    id: root

    readonly property bool enabled: Config.loaded && Config.appearance.apps && !Config.demo
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME")?.startsWith("/") ? Quickshell.env("XDG_CONFIG_HOME") : Config.home + "/.config"
    property string written: ""
    readonly property string css: build()
    readonly property string state: `${Colours.light ? "light" : "dark"}\n${css}`

    onStateChanged: debounce.restart()
    onEnabledChanged: debounce.restart()

    function hex(c: color): string {
        const h = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
        return `#${h(c.r)}${h(c.g)}${h(c.b)}`;
    }

    function build(): string {
        const c = Colours;
        const named = [
            ["accent_color", c.primary],
            ["accent_bg_color", c.primary],
            ["accent_fg_color", c.fgPrimary],
            ["destructive_color", c.error],
            ["destructive_bg_color", c.errorContainer],
            ["destructive_fg_color", c.fgErrorContainer],
            ["success_color", c.tertiary],
            ["warning_color", c.tertiary],
            ["error_color", c.error],
            ["window_bg_color", c.surface],
            ["window_fg_color", c.fgSurface],
            ["view_bg_color", c.surfaceContainerLow],
            ["view_fg_color", c.fgSurface],
            ["headerbar_bg_color", c.surface],
            ["headerbar_fg_color", c.fgSurface],
            ["headerbar_backdrop_color", c.surface],
            ["headerbar_border_color", c.outlineVariant],
            ["sidebar_bg_color", c.surfaceContainer],
            ["sidebar_fg_color", c.fgSurface],
            ["sidebar_backdrop_color", c.surfaceContainer],
            ["secondary_sidebar_bg_color", c.surfaceContainerLow],
            ["secondary_sidebar_fg_color", c.fgSurface],
            ["card_bg_color", c.surfaceContainerHigh],
            ["card_fg_color", c.fgSurface],
            ["dialog_bg_color", c.surfaceContainerHigh],
            ["dialog_fg_color", c.fgSurface],
            ["popover_bg_color", c.surfaceContainerHigh],
            ["popover_fg_color", c.fgSurface],
            ["thumbnail_bg_color", c.surfaceContainerHigh],
            ["thumbnail_fg_color", c.fgSurface],
            ["theme_bg_color", c.surface],
            ["theme_fg_color", c.fgSurface],
            ["theme_base_color", c.surfaceContainerLow],
            ["theme_text_color", c.fgSurface],
            ["theme_selected_bg_color", c.primary],
            ["theme_selected_fg_color", c.fgPrimary],
            ["borders", c.outlineVariant]
        ];
        const sel = hex(c.primary);
        return named.map(n => `@define-color ${n[0]} ${hex(n[1])};`).join("\n") + `
@define-color headerbar_shade_color alpha(black, 0.12);
@define-color shade_color alpha(black, 0.2);
@define-color scrollbar_outline_color alpha(black, 0.3);
@define-color popover_shade_color alpha(black, 0.2);
@define-color card_shade_color alpha(black, 0.1);
.view:selected, row:selected, iconview:selected, treeview.view:selected { background-color: alpha(${sel}, 0.24); color: ${hex(c.fgSurface)}; }
menubar { background-color: ${hex(c.surface)}; padding: 2px 6px; }
entry { border-radius: 999px; padding: 4px 12px; }
button { border-radius: 999px; }
`;
    }

    Timer {
        id: debounce

        interval: 600
        onTriggered: {
            if (!Config.loaded || Config.demo)
                return;
            if (root.enabled) {
                if (root.written === root.state)
                    return;
                root.written = root.state;
                const dark = !Colours.light;
                Quickshell.execDetached(["sh", "-c", 'd=$1; for v in 3.0 4.0; do mkdir -p "$d/gtk-$v" || continue; printf "%s" "$2" > "$d/gtk-$v/crest.css.tmp" && mv -f "$d/gtk-$v/crest.css.tmp" "$d/gtk-$v/crest.css"; f="$d/gtk-$v/gtk.css"; grep -qs "crest.css" "$f" || { { echo "@import url(\\"crest.css\\");"; [ -f "$f" ] && grep -v -e "^@define-color" -e "^window, .background { background-color: #131313; }" -e "^.view, iconview, treeview.view { background-color: #1a1a1a; }" -e "^.sidebar, placessidebar, .thunar .sidebar { background-color: #0e0e0e; }" -e "^menubar { background-color: #131313" -e "^.view:selected, row:selected" "$f"; } > "$f.tmp"; mv -f "$f.tmp" "$f"; }; done; theme=adw-gtk3; [ -d /usr/share/themes/adw-gtk3 ] || theme=Adwaita; [ "$3" = dark ] && [ "$theme" = adw-gtk3 ] && theme=adw-gtk3-dark; gsettings set org.gnome.desktop.interface gtk-theme "$theme"; gsettings set org.gnome.desktop.interface color-scheme "prefer-$3"; true', "sh", root.configDir, root.css, dark ? "dark" : "light"]);
            } else if (root.written !== "off") {
                root.written = "off";
                Quickshell.execDetached(["sh", "-c", 'for v in 3.0 4.0; do rm -f "$1/gtk-$v/crest.css"; done; true', "sh", root.configDir]);
            }
        }
    }
}
