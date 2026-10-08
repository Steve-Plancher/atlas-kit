#!/usr/bin/env python3
"""Keep the window title before the workspaces on the bar's left side.

rosakodu.dock rewrites shell.json into its own "canonical" section order whenever
it saves, which forces menu · workspaces · window title. This adds
omarchy.active-window to its left-order list so it keeps Steve's order:
menu · window title · workspaces. Idempotent.

    tools/dock-order-fix.py ~/.config/omarchy/plugins/rosakodu.dock
"""
import os, re, sys

path = os.path.join(os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else
                                       "~/.config/omarchy/plugins/rosakodu.dock"), "DockWidgets.js")
if not os.path.exists(path):
    sys.exit(0)
text = open(path).read()
pat = re.compile(r'("left": \[\s*"omarchy\.menu",)(\s*)("omarchy\.workspaces")')
new, n = pat.subn(lambda m: m.group(1) + m.group(2) + '"omarchy.active-window",' + m.group(2) + m.group(3), text)
if n:
    open(path, "w").write(new)
print(f"dock-order-fix: patched {n} place(s) in {path}")
