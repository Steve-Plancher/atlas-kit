# A.T.L.A.S titlebar native chrome notes

The universal A.T.L.A.S bar is a Quickshell overlay aligned to the active Hyprland window.
Native/client-side titlebars are app-controlled, so this rollout does not force fragile global CSD removal.

Current safe strategy:
- Browser/Electron apps: prefer their built-in "use system title bar and borders" / custom decorations settings when available.
- GTK/libadwaita apps: leave native headerbars alone unless an app-specific reversible setting exists.
- Quickshell/Omarchy shell surfaces, launchers, lock screens, notification surfaces, and tooltips are excluded from overlay coverage.

Add app-specific reversible rules here after visual verification.
