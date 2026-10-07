-- A.T.L.A.S smart app placement and startup hooks.
-- Keep this light: exact snap placement stays manual, defaults just improve first launch sizing.

-- Browsers: large left/center work area for research.
o.window("(?i)(brave-browser|google-chrome|chromium|firefox|zen|browser)", { float = true, size = "62% 86%", center = true })
-- Code editors: generous left/center focus panel.
o.window("(?i)(code|codium|cursor|windsurf|zed|jetbrains|claude)", { float = true, size = "64% 88%", center = true })
-- Terminals: right-side operator panel size.
o.window("(?i)(Alacritty|kitty|ghostty|org.wezfurlong.wezterm|foot)", { float = true, size = "46% 82%", center = true })
-- Chat/assistant panels: compact side-card behavior.
o.window("(?i)(discord|telegram|signal|slack|teams)", { float = true, size = "38% 84%", center = true })
