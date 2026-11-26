local shell = "crest"
local mod = "SUPER"
local terminal = "kitty"
local crested = shell == "crest"
local function crest(name) return hl.dsp.global("crest:" .. name) end
local runs = { crest = "qs -c crest -d", noctalia = "noctalia", dux = "dms run", none = "waybar" }
local files = "thunar"
local browser = "firefox"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XDG_CONFIG_DIRS", "/usr/share/fiordland/xdg:/etc/xdg")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
if not os.getenv("QS_ICON_THEME") then hl.env("QS_ICON_THEME", "Fiordland") end

local function nvidia_only()
    if not io.open("/proc/driver/nvidia/version", "r") then
        return false
    end
    local p = io.popen("cat /sys/class/drm/card*/device/vendor 2>/dev/null")
    local out = p and p:read("*a") or ""
    if p then p:close() end
    return not out:find("0x8086") and not out:find("0x1002")
end

if nvidia_only() then
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end

hl.on("hyprland.start", function()
    if runs[shell] then hl.exec_cmd(runs[shell]) end
    if shell == "none" then
        hl.exec_cmd("mako")
        hl.exec_cmd("swaybg -m fill -i /usr/share/fiordland/wallpaper.png")
    end
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("xdg-user-dirs-update")
    hl.exec_cmd("fiordland-dots")
    hl.exec_cmd("kuaka --tray")
end)

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(9ecaffee)", "rgba(86d6cbee)" }, angle = 45 },
            inactive_border = "rgba(41474faa)",
        },
        resize_on_border = true,
        allow_tearing = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 20,
        rounding_power = 2.4,
        shadow = { enabled = true, range = 32, render_power = 3, color = 0x59000000 },
        blur = { enabled = true, size = 8, passes = 3, noise = 0.012, contrast = 0.95, brightness = 0.9, vibrancy = 0.2, popups = true },
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

hl.curve("emphasizedDecel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("emphasizedAccel", { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("standard", { type = "bezier", points = { {0.2, 0}, {0, 1} } })
hl.curve("spatial", { type = "bezier", points = { {0.38, 1.21}, {0.22, 1} } })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "spatial", style = "popin 88%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "emphasizedAccel", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "spatial" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "standard" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "standard" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "emphasizedDecel", style = "slidevert" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "emphasizedDecel", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "emphasizedAccel", style = "fade" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + T", hl.dsp.exec_cmd(terminal))
if crested then
    hl.bind("SUPER + SUPER_L", crest("launcher"), { release = true })
    hl.bind(mod .. " + SPACE", crest("launcher"))
    hl.bind(mod .. " + D", crest("overview"))
    hl.bind(mod .. " + A", crest("quicksettings"))
    hl.bind(mod .. " + N", crest("notifications"))
    hl.bind(mod .. " + SHIFT + N", crest("clearNotifs"), { locked = true })
    hl.bind(mod .. " + L", crest("lock"), { locked = true })
    hl.bind(mod .. " + ESCAPE", crest("session"))
    hl.bind(mod .. " + M", crest("session"))
    hl.bind(mod .. " + I", crest("settings"))
    hl.bind(mod .. " + W", crest("wallpaper"))
    hl.bind(mod .. " + PERIOD", crest("emoji"))
    hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
else
    hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("pkill fuzzel || fuzzel"), { release = true })
    hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("pkill fuzzel || fuzzel"))
    hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"), { locked = true })
    hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
end
hl.bind(mod .. " + E", hl.dsp.exec_cmd(files))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true })
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

hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
if crested then
    hl.bind("XF86AudioRaiseVolume", crest("volumeUp"), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", crest("volumeDown"), { locked = true, repeating = true })
    hl.bind("XF86AudioMute", crest("volumeMute"), { locked = true })
    hl.bind("XF86MonBrightnessUp", crest("brightnessUp"), { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown", crest("brightnessDown"), { locked = true, repeating = true })
    hl.bind("XF86AudioPlay", crest("mediaToggle"), { locked = true })
    hl.bind("XF86AudioPause", crest("mediaToggle"), { locked = true })
    hl.bind("XF86AudioNext", crest("mediaNext"), { locked = true })
    hl.bind("XF86AudioPrev", crest("mediaPrev"), { locked = true })
    hl.bind("XF86AudioStop", crest("mediaStop"), { locked = true })
else
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
    hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })
end
hl.layer_rule({ match = { namespace = "^crest-(bar|launcher|quicksettings|notifications|session|osd|wallpaper|overview)$" }, blur = true, ignore_alpha = 0.3, no_anim = true })
hl.layer_rule({ match = { namespace = "^crest-background$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^(selection|hyprpicker|wayfreeze)$" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "^launcher$" }, animation = "popin 80%", blur = true })

hl.window_rule({ name = "fiordland-dots", match = { class = "^fiordland-dots$" }, float = true, center = true, size = "1000 640" })
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
