-- A.T.L.A.S windows: Windows-style floating windows with title bars and snapping.
-- Snapping itself is ~/.local/bin/atlas-snap (drag watcher + keyboard zones), with its
-- preview drawn by the com.plancher-labs.atlas-snap shell plugin.

-- ── Title bars (hyprbars) ──────────────────────────────────────────────────
-- Built from source for this exact Hyprland build; see
-- ~/.local/share/hyprland-plugins/README.txt when it stops loading after an update.
local hyprbars_path = os.getenv("HOME") .. "/.local/share/hyprland-plugins/hyprbars.so"
local hyprbars_loaded = false
for _, plugin in pairs(hl.get_loaded_plugins() or {}) do
  if plugin.name == "hyprbars" then hyprbars_loaded = true end
end
-- Never load the plugin from the config: at a cold start (login) the plugin load
-- hangs Hyprland before the desktop appears. Only configure it if already loaded.
-- Instead, load it in the background once the desktop is up, then reload so the
-- settings and buttons below apply.
o.exec_on_start("sleep 3 && hyprctl plugin load " .. hyprbars_path .. " && hyprctl reload")

if hyprbars_loaded and hl.plugin.hyprbars then
  local snap = os.getenv("HOME") .. "/.local/bin/atlas-snap"

  hl.config({
    plugin = {
      hyprbars = {
        bar_height = 30,
        bar_color = "rgba(0a141ee6)",
        col = { text = "rgba(bfefffff)" },
        bar_text_font = "JetBrainsMono Nerd Font",
        bar_text_size = 11,
        bar_text_align = "left",
        bar_padding = 12,
        bar_button_padding = 9,
        bar_part_of_window = true,
        bar_precedence_over_border = true,
        on_double_click = snap .. " maximize",
      },
    },
  })

  -- Buttons are right-aligned; the first one added sits furthest right.
  hl.plugin.hyprbars.add_button({ bg_color = "rgba(ff5f57ee)", fg_color = "rgba(0a141eff)", size = 14, icon = "󰅖",
    action = "hyprctl dispatch 'hl.dsp.window.close()'" })
  hl.plugin.hyprbars.add_button({ bg_color = "rgba(35c4ffee)", fg_color = "rgba(0a141eff)", size = 14, icon = "󰊓",
    action = snap .. " maximize" })
  hl.plugin.hyprbars.add_button({ bg_color = "rgba(ffbd2eee)", fg_color = "rgba(0a141eff)", size = 14, icon = "󰖰",
    action = snap .. " minimize" })
end

-- ── Float every window, like Windows ───────────────────────────────────────
-- SUPER+T still switches a window to tiled.
o.window(".*", { float = true })
-- Omarchy's apps/browser.lua tiles Chromium browsers (Edge, Chrome, Brave), which beat the rule
-- above and kept them out of atlas-snap's auto-arrange. Float them like everything else.
o.window({ tag = "chromium-based-browser" }, { float = true, tile = false })

-- ── Snappy window landing ──────────────────────────────────────────────────
-- A quick glide with a slight overshoot when a window is snapped, maximized or restored
-- (Omarchy's default moves are a slower easeOutQuint).
hl.curve("atlasSnap", { type = "bezier", points = { { 0.18, 1.18 }, { 0.32, 1 } } })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.6, bezier = "atlasSnap" })

-- ── Live border + movement ─────────────────────────────────────────────────
-- The focused window's border is a 3-stop A.T.L.A.S gradient; rotating its angle forever makes
-- it read as a live HUD frame instead of a static glow. Only the focused window's border
-- repaints, so the cost is small, but it never idles — drop `style = "loop"` to freeze it.
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "linear", style = "loop" })

-- Switching workspaces slides instead of cutting (Omarchy ships this disabled), and the hidden
-- minimized workspace drops in from above.
hl.animation({ leaf = "workspaces", enabled = true, speed = 4.2, bezier = "atlasSnap", style = "slidefade 12%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.6, bezier = "atlasSnap", style = "slidevert" })

-- The snap preview overlay does its own animation; Hyprland's layer fade would fight it, and
-- skipping it lets the overlay be mapped only while a zone is shown (less compositing = less heat).
hl.layer_rule({ match = { namespace = "atlas-snap-preview" }, no_anim = true, animation = "none" })
