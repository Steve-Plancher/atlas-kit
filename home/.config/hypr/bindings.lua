-- Disable Omarchy zoom-in chord; it conflicts with A.T.L.A.S snap-guide expectations.
hl.unbind("SUPER + CTRL + Z")
-- A.T.L.A.S Snap Assist bindings
-- SUPER+Z = Windows 11-style snap picker. SUPER+ALT arrows = quick halves.

o.bind("SUPER + Z", "A.T.L.A.S Snap Layouts", "atlas-snap menu")
o.bind("SUPER + ALT + LEFT", "Snap active window left half", "atlas-snap left")
o.bind("SUPER + ALT + RIGHT", "Snap active window right half", "atlas-snap right")
o.bind("SUPER + ALT + UP", "Snap active window center focus", "atlas-snap center-focus")
o.bind("SUPER + ALT + DOWN", "Snap active window max work area", "atlas-snap max")
o.bind("SUPER + CTRL + LEFT", "Snap active window left third", "atlas-snap third-left")
o.bind("SUPER + CTRL + UP", "Snap active window center third", "atlas-snap third-center")
o.bind("SUPER + CTRL + RIGHT", "Snap active window right third", "atlas-snap third-right")
-- Moved off SUPER+CTRL+Z because Hyprland/Omarchy uses that chord for zoom.
o.bind("SUPER + SHIFT + Z", "Show A.T.L.A.S snap guide", "atlas-snap-overlay")
-- Windows-style minimize (title bar minimize does the same). Minimized windows come back only
-- from the Minimized widget on the bar, by Steve's choice.
o.bind("SUPER + M", "Minimize window", os.getenv("HOME") .. "/.local/bin/atlas-snap minimize")

-- F12 locks the screen (opens on the A.T.L.A.S standby screen, see steve.lock plugin).
o.bind("F12", "Lock screen", "omarchy-system-lock")
