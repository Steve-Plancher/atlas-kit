-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.atlas_windows")
require("hypr.atlas_glass")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.

-- A.T.L.A.S overrides: ~/.local/share/atlas/bin goes first on PATH so its forked
-- omarchy-screensaver (HUD effects + blue palette) wins over the packaged one.
do
  local atlas_bin = os.getenv("HOME") .. "/.local/share/atlas/bin"
  local kept = { atlas_bin }
  for entry in (os.getenv("PATH") or "/usr/local/bin:/usr/bin"):gmatch("[^:]+") do
    if entry ~= atlas_bin then table.insert(kept, entry) end
  end
  hl.env("PATH", table.concat(kept, ":"))
end
-- o.window("qemu", { workspace = "5" })

-- A.T.L.A.S cursor theme + protocol border colors (Atlas-Cyan unless a protocol is engaged).
require("hypr.atlas_protocol")
