-- A.T.L.A.S Protocols: keeps the active protocol's border colors and cursor across
-- Hyprland reloads. atlas-protocol writes ~/.local/state/atlas-protocol/state.conf
-- (outside ~/.config/hypr, so switching never triggers an auto-reload) and applies
-- the same values live; this file only re-applies them at load.

local s = {}
local f = io.open(os.getenv("HOME") .. "/.local/state/atlas-protocol/state.conf", "r")
if f then
  for line in f:lines() do
    local key, value = line:match("^(%w+)=(.*)$")
    if key then s[key] = value end
  end
  f:close()
end

local hex = "^%x%x%x%x%x%x$"
if s.name and s.name ~= "standard" and (s.accent or ""):match(hex) and (s.ice or ""):match(hex) and (s.deep or ""):match(hex) then
  hl.config({
    general = {
      col = {
        active_border = { colors = { "rgba(" .. s.ice .. "ee)", "rgba(" .. s.accent .. "ee)", "rgba(" .. s.deep .. "dd)" }, angle = 45 },
        inactive_border = { colors = { "rgba(" .. s.deep .. "55)", "rgba(" .. s.deep .. "33)" }, angle = 45 },
        nogroup_border_active = { colors = { "rgba(" .. s.ice .. "ee)", "rgba(" .. s.accent .. "ee)" }, angle = 45 },
        nogroup_border = "rgba(" .. s.deep .. "33)",
      },
    },
  })
end

hl.env("XCURSOR_THEME", (s.cursor and s.cursor:match("^[%w%-]+$")) and s.cursor or "Atlas-Cyan")
