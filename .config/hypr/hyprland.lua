-- Hyprland config mirroring the niri configuration.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60",
    position = "auto",
    scale    = "1",
    icc      = "/home/karasu/.config/color/icc/devices/display/mac.icc",
})


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_THEME", "MacTahoe-dark")
hl.env("XCURSOR_SIZE", "22")
hl.env("HYPRCURSOR_THEME", "MacTahoe-dark")
hl.env("HYPRCURSOR_SIZE", "22")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("MOZ_DBUS_REMOTE", "1")


-----------------------
----- PERMISSIONS -----
-----------------------

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Mirrors niri layout: gaps 10, focus ring 2px, no border, corner radius 15.
hl.config({
    general = {
        gaps_in     = 10,
        -- niri struts: extra 10px at the bottom
        gaps_out    = { top = 10, right = 10, bottom = 20, left = 10 },

        border_size = 0,

        col = {
            active_border   = "rgb(7fc8ff)",
            inactive_border = "rgb(505050)",
        },

        resize_on_border = false,
        allow_tearing    = false,

        -- Scrolling layout, closest equivalent to niri's columns
        layout = "scrolling",
    },

    decoration = {
        rounding       = 15,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 30,
            render_power = 3,
            color        = 0x70000000,
        },

        -- niri blur: off
        blur = {
            enabled = false,
        },
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutExpo",   { type = "bezier", points = { {0.16, 1}, {0.3, 1} } })
hl.curve("linear",        { type = "bezier", points = { {0, 0},    {1, 1}    } })
hl.curve("almostLinear",  { type = "bezier", points = { {0.5, 0.5},  {0.75, 1} } })

-- Springs matching niri: damping-ratio/stiffness converted to mass/stiffness/dampening
hl.curve("niriMove",       { type = "spring", mass = 1, stiffness = 220, dampening = 25.2 })  -- 0.85 / 220
hl.curve("niriWorkspace",  { type = "spring", mass = 1, stiffness = 180, dampening = 22.8 })  -- 0.85 / 180
hl.curve("niriViewMove",   { type = "spring", mass = 1, stiffness = 220, dampening = 26.7 })  -- 0.90 / 220
hl.curve("niriOverview",   { type = "spring", mass = 1, stiffness = 280, dampening = 25.1 })  -- 0.75 / 280
hl.curve("niriPopup",      { type = "spring", mass = 1, stiffness = 80,  dampening = 12.5 })  -- 0.70 / 80

-- niri: window-open/close 500ms ease-out-expo
hl.animation({ leaf = "global",        enabled = true,  speed = 10,  bezier = "default" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 5,   bezier = "easeOutExpo",  style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 5,   bezier = "easeOutExpo",  style = "popin 87%" })
-- niri: window-movement spring 0.85/220
hl.animation({ leaf = "windows",       enabled = true,  speed = 5,   spring = "niriMove" })
-- niri: horizontal-view-movement spring 0.9/220
hl.animation({ leaf = "layers",        enabled = true,  speed = 4,   spring = "niriViewMove" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,   bezier = "easeOutExpo",  style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5, bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "almostLinear" })
-- niri: workspace-switch spring 0.85/180
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 2,   spring = "niriWorkspace" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 2,   spring = "niriWorkspace", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 2,   spring = "niriWorkspace", style = "fade" })

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
        column_width             = 0.5, -- niri: default-column-width proportion 0.50
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
        -- niri clipboard: disable-primary
        middle_click_paste      = false, -- Hyprland has no primary selection by default on Wayland
        -- niri hotkey-overlay: skip-at-startup
        disable_hyprland_guiutils_check = true,
    },
    cursor = {
        -- niri cursor: hide-after-inactive-ms 500
        inactive_timeout = 0.5,
        hide_on_touch    = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        -- niri: layout us,ara; grp:ctrl_space_toggle,numpad:mac
        kb_layout     = "us,ara",
        kb_variant    = "",
        kb_model      = "",
        kb_options    = "grp:ctrl_space_toggle,numpad:mac",
        kb_rules      = "",

        -- niri: repeat-delay 200, repeat-rate 40
        repeat_delay  = 200,
        repeat_rate   = 40,

        -- niri: numlock
        numlock_by_default = true,

        -- niri: focus-follows-mouse
        follow_mouse  = 1,

        sensitivity   = 0,

        touchpad = {
            -- niri: click-method clickfinger, tap
            tap_to_click       = true,
            clickfinger_behavior = true,
            -- niri accel-speed has no global equivalent; use hl.device({ name = ..., sensitivity = ... }) per device
            natural_scroll     = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace"
})


---------------------
---- AUTOSTART ----
---------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("qs")
    hl.exec_cmd("pipewire")
    hl.exec_cmd("pipewire-pulse")
    hl.exec_cmd("wireplumber")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("eww daemon")
    hl.exec_cmd("swaync")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Launchers
hl.bind(mainMod .. " + space",         hl.dsp.exec_cmd("rofi -show run"))
hl.bind(mainMod .. " + V",             hl.dsp.exec_cmd("~/.config/rofi/cliphist/launcher.sh || pkill rofi"))
hl.bind(mainMod .. " + G",             hl.dsp.exec_cmd("~/.config/rofi/wallpaper-changer/launcher.sh || pkill rofi"))
hl.bind(mainMod .. " + SHIFT + S",     hl.dsp.exec_cmd("~/.config/niri/shaders/pick.sh"))
hl.bind(mainMod .. " + Return",        hl.dsp.exec_cmd("foot"))
hl.bind(mainMod .. " + C",             hl.dsp.exec_cmd("librewolf"))
hl.bind(mainMod .. " + SHIFT + Q",     hl.dsp.exec_cmd("hyprlock"))

-- Windows
hl.bind(mainMod .. " + X",             hl.dsp.window.close())
hl.bind(mainMod .. " + N",             hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",             hl.dsp.exec_cmd("hyprctl dispatch fullscreen 0"))          -- niri: fullscreen-window
hl.bind(mainMod .. " + S",             hl.dsp.exec_cmd("hyprctl dispatch fullscreen 1"))          -- niri: maximize-column

-- Focus
hl.bind(mainMod .. " + left",          hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right",         hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",            hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",          hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + H",             hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L",             hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + J",             hl.dsp.exec_cmd("hyprctl dispatch cyclenext"))             -- niri: focus-window-or-workspace-down
hl.bind(mainMod .. " + K",             hl.dsp.exec_cmd("hyprctl dispatch cycleprev"))             -- niri: focus-window-or-workspace-up

-- Move windows
hl.bind(mainMod .. " + CTRL + left",   hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind(mainMod .. " + CTRL + right",  hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
hl.bind(mainMod .. " + CTRL + up",     hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
hl.bind(mainMod .. " + CTRL + down",   hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))
hl.bind(mainMod .. " + CTRL + H",      hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind(mainMod .. " + CTRL + L",      hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
hl.bind(mainMod .. " + CTRL + J",      hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))
hl.bind(mainMod .. " + CTRL + K",      hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
hl.bind(mainMod .. " + SHIFT + H",     hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind(mainMod .. " + SHIFT + L",     hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))

-- Workspaces
hl.bind(mainMod .. " + Page_Down",     hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + Page_Up",       hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + U",             hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + I",             hl.dsp.focus({ workspace = "e-1" }))
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i,     hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + CTRL + U",      hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace e+1"))
hl.bind(mainMod .. " + CTRL + I",      hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace e-1"))

-- Mouse
hl.bind(mainMod .. " + mouse_down",    hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",      hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",     hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",     hl.dsp.window.resize(), { mouse = true })

-- Resize (approximation of niri preset widths / +/-5%)
hl.bind(mainMod .. " + R",             hl.dsp.exec_cmd("hyprctl dispatch resizeactive exact 50 50"))
hl.bind(mainMod .. " + Minus",         hl.dsp.exec_cmd("hyprctl dispatch resizeactive -40 0"))
hl.bind(mainMod .. " + Equal",         hl.dsp.exec_cmd("hyprctl dispatch resizeactive 40 0"))
hl.bind(mainMod .. " + SHIFT + Minus", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -40"))
hl.bind(mainMod .. " + SHIFT + Equal", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 40"))

-- Wallpaper / misc
hl.bind(mainMod .. " + SHIFT + W",     hl.dsp.exec_cmd("~/.local/bin/wallpaper random"))
hl.bind(mainMod .. " + SHIFT + N",     hl.dsp.exec_cmd("~/.config/hypr/scripts/monochrome_wallpaper.sh"))

-- Window switcher (niri recent-windows)
hl.bind("ALT + Tab",                   hl.dsp.exec_cmd("hyprctl dispatch cyclenext"))
hl.bind("ALT + SHIFT + Tab",           hl.dsp.exec_cmd("hyprctl dispatch cycleprev"))
hl.bind(mainMod .. " + Tab",           hl.dsp.exec_cmd("hyprctl dispatch cyclenext"))
hl.bind(mainMod .. " + SHIFT + Tab",   hl.dsp.exec_cmd("hyprctl dispatch cycleprev"))

-- Screenshots / session
hl.bind("PRINT",                       hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh"))
hl.bind(mainMod .. " + SHIFT + E",     hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind("CTRL + ALT + Delete",         hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))

-- Laptop multimedia keys for volume and LCD brightness (niri: 10% steps, light)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("light -A 10"),  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("light -U 10"),  { locked = true, repeating = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    -- Ignore maximize requests from all apps.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- niri: match app-id rofi -> open-floating false, open-focused true
hl.window_rule({
    name  = "rofi-focused",
    match = { class = "^rofi$" },

    float          = false,
    focus_on_activate = true,
})

-- niri: xdg-desktop-portal-gtk -> floating, min 400x600
hl.window_rule({
    name  = "portal-gtk-floating",
    match = { class = "xdg-desktop-portal-gtk" },

    float = true,
    size  = "400 600",
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})
