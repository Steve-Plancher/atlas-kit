-- Managed by A.T.L.A.S Display (~/.local/bin/atlas-display). Do not edit by hand:
-- change displays from the Display panel on the bar, or its Arrange button.
-- Source of truth: ~/.config/hypr/atlas-monitors.json (monitors are matched by model and
-- serial number, so each keeps its settings on any port, dock or reconnect).
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

-- Monitors not listed below: preferred mode, placed automatically.
local omarchy_monitor_scale = "auto"
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- AU Optronics 0x4599 (last seen as eDP-1)
hl.monitor({ output = "desc:AU Optronics 0x4599", mode = "1920x1080@60.05", position = "0x457", scale = 1.25, transform = 0 })

-- GIGA-BYTE TECHNOLOGY CO. LTD. G32QC A 21340B007589 (last seen as DP-6)
hl.monitor({ output = "desc:GIGA-BYTE TECHNOLOGY CO. LTD. G32QC A 21340B007589", mode = "2560x1440@164.84", position = "3760x0", scale = 1.25, transform = 0 })

-- GIGA-BYTE TECHNOLOGY CO. LTD. G32QC A 21340B010048 (last seen as DP-5)
hl.monitor({ output = "desc:GIGA-BYTE TECHNOLOGY CO. LTD. G32QC A 21340B010048", mode = "2560x1440@165.00", position = "1536x0", scale = 1.25, transform = 0 })

-- Lenovo Group Limited E27q-20 V5WYM323 (last seen as HDMI-A-1)
hl.monitor({ output = "desc:Lenovo Group Limited E27q-20 V5WYM323", mode = "2560x1440@59.95", position = "0x0", scale = 1.6, transform = 0 })

-- Lenovo Group Limited R27q-30 U533CZVW (last seen as HDMI-A-1)
hl.monitor({ output = "desc:Lenovo Group Limited R27q-30 U533CZVW", mode = "2560x1440@144.0", position = "0x0", scale = 1.6, transform = 2 })

-- GDK_SCALE: whole-number factor GTK draws its own UI at (X11/XWayland apps).
local omarchy_gdk_scale = 2
hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
