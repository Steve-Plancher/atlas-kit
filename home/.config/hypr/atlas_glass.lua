-- A.T.L.A.S Glass: see-through windows. Controlled by the Glass bar widget / atlas-glass.
-- Reads ~/.local/state/atlas-glass/glass.conf with io.open (not require) so saving it
-- does not trigger a Hyprland auto-reload. Formula must match ~/.local/bin/atlas-glass.

local level, blur, fullscreen = 0, false, false
local f = io.open(os.getenv("HOME") .. "/.local/state/atlas-glass/glass.conf", "r")
if f then
  for line in f:lines() do
    local key, value = line:match("^(%w+)=(.*)$")
    if key == "level" then level = math.max(0, math.min(60, tonumber(value) or 0))
    elseif key == "blur" then blur = value == "true"
    elseif key == "fullscreen" then fullscreen = value == "true"
    end
  end
  f:close()
end

if level > 0 then
  local active = 1.0 - level / 100.0
  hl.config({
    decoration = {
      active_opacity = active,
      inactive_opacity = math.max(0.3, active - 0.06),
      fullscreen_opacity = fullscreen and active or 1.0,
      blur = { enabled = blur, size = 5, passes = 2, noise = 0.02, vibrancy = 0.2 },
    },
  })
end

-- Solid (level 0) means truly opaque: this overrides Omarchy's per-app opacity rules
-- (0.985 focused / 0.96 unfocused), which otherwise still let the wallpaper through.
-- Global so atlas-glass can flip it live with set_enabled.
atlas_glass_solid_rule = hl.window_rule({
  name = "atlas-glass-solid",
  match = { class = ".*" },
  opacity = "1 override 1 override 1 override",
  enabled = level == 0,
})
