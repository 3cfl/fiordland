local mod = "SUPER"
local terminal = "kitty"
local function crest(name) return hl.dsp.global("crest:" .. name) end
local files = "thunar"
local browser = "firefox"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XDG_CONFIG_DIRS", "/usr/share/fiordland/xdg:/etc/xdg")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c crest -d")
    hl.exec_cmd("xdg-user-dirs-update")
    local live = io.open("/run/archiso/bootmnt", "r")
    if live then
        live:close()
        hl.exec_cmd("rawaru")
    end
end)

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(8ec5ffee)", "rgba(c4dfffee)" }, angle = 45 },
            inactive_border = "rgba(2e2e2eaa)",
        },
        resize_on_border = true,
        allow_tearing = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 16,
        rounding_power = 2,
        shadow = { enabled = true, range = 18, render_power = 3, color = 0x99000000 },
        blur = { enabled = true, size = 6, passes = 2, vibrancy = 0.17 },
    },
    animations = { enabled = true },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        numlock_by_default = true,
        touchpad = { natural_scroll = true, tap_to_click = true, disable_while_typing = true },
    },
    cursor = { hide_on_key_press = true, inactive_timeout = 0 },
    render = { direct_scanout = 2 },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        vrr = 2,
        focus_on_activate = true,
        middle_click_paste = false,
    },
    dwindle = { preserve_split = true },
})

hl.curve("emphasized", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("standard", { type = "bezier", points = { {0.2, 0}, {0, 1} } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "emphasized", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "standard", style = "popin 85%" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "standard" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "emphasized", style = "slide" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "emphasized", style = "fade" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + SUPER_L", crest("launcher"), { release = true })
hl.bind(mod .. " + SPACE", crest("launcher"))
hl.bind(mod .. " + D", crest("dashboard"))
hl.bind(mod .. " + A", crest("sidebar"))
hl.bind(mod .. " + N", crest("sidebar"))
hl.bind(mod .. " + SHIFT + N", crest("clearNotifs"), { locked = true })
hl.bind(mod .. " + L", crest("lock"), { locked = true })
hl.bind(mod .. " + ESCAPE", crest("session"))
hl.bind(mod .. " + M", crest("session"))
hl.bind(mod .. " + I", crest("nexus"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard"))
hl.bind(mod .. " + PERIOD", hl.dsp.exec_cmd("pkill fuzzel || caelestia emoji -p"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(files))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + S", crest("screenshot"))
hl.bind(mod .. " + SHIFT + ALT + S", crest("screenshotFreeze"))
hl.bind("Print", hl.dsp.exec_cmd("caelestia screenshot"), { locked = true })
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("caelestia record -r"))

hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + TAB", hl.dsp.focus({ workspace = "previous" }))
hl.bind("ALT + TAB", hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }))
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", crest("brightnessUp"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", crest("brightnessDown"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", crest("mediaToggle"), { locked = true })
hl.bind("XF86AudioPause", crest("mediaToggle"), { locked = true })
hl.bind("XF86AudioNext", crest("mediaNext"), { locked = true })
hl.bind("XF86AudioPrev", crest("mediaPrev"), { locked = true })
hl.bind("XF86AudioStop", crest("mediaStop"), { locked = true })

hl.layer_rule({ match = { namespace = "^crest-(border-exclusion|area-picker)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^crest-(drawers|background)$" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "^(selection|hyprpicker|wayfreeze)$" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "^launcher$" }, animation = "popin 80%", blur = true })

hl.window_rule({ name = "rawaru", match = { class = "^rawaru$" }, float = true, center = true, size = "1040 700" })
hl.window_rule({ name = "pavucontrol", match = { class = "^org.pulseaudio.pavucontrol$" }, float = true, size = "760 520" })
hl.window_rule({ name = "nm-editor", match = { class = "^nm-connection-editor$" }, float = true })
hl.window_rule({ name = "dialogs", match = { title = "^(Open|Save|Open File|Save As|Select|Choose|File Upload).*" }, float = true, center = true })
hl.window_rule({ name = "pip", match = { title = "^Picture.in.[Pp]icture$" }, float = true, pin = true, size = "480 270", move = "100%-500 100%-290" })
hl.window_rule({ name = "games-tear", match = { content = "game" }, immediate = true })
hl.window_rule({ name = "steam-games", match = { class = "^steam_app_.*" }, immediate = true })
hl.window_rule({ name = "xwayland-drags", match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, no_focus = true })

local user = io.open((os.getenv("HOME") or "") .. "/.config/hypr/user.lua", "r")
if user then
    user:close()
    require("user")
end
