#!/usr/bin/env python3
"""Read-only Qt 6.12 lint: list QML lines that still use the unqualified `Color` palette
(which Qt 6.12's built-in Color type shadows). Exit 1 if any are found.

    tools/qt612-color-scan.py /usr/share/omarchy/shell ~/.config/omarchy/plugins
"""
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("fx", os.path.join(os.path.dirname(os.path.abspath(__file__)), "qt612-color-fix.py"))
fx = importlib.util.module_from_spec(spec); spec.loader.exec_module(fx)
tot = {}
for base in sys.argv[1:]:
    for root, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules") and not d.startswith(".")]
        for f in files:
            if not f.endswith(".qml"): continue
            p = os.path.join(root, f); n = 0
            for line in open(p, errors="replace"):
                s = line.lstrip()
                if s.startswith(("import ", "pragma ")): continue
                if fx.patch_line(line) != line: n += 1
            if n: tot[p] = n
for p, n in sorted(tot.items(), key=lambda x: -x[1]): print(f"{n:4d} {p}")
print("files:", len(tot), "lines:", sum(tot.values()))
sys.exit(1 if tot else 0)
