#!/usr/bin/env python3
"""The bar's Protocols panel (plugin com.plancher-labs.atlas-protocol): install, bar wiring and the
controls it must offer. Clicking through it on the real desktop is part of the live verification.

Usage: test-protocol-panel.py
"""
import json, os, re, subprocess, sys

HOME = os.path.expanduser("~")
PID = "com.plancher-labs.atlas-protocol"
PLUGIN = f"{HOME}/.config/omarchy/plugins/{PID}"
SHELL_JSON = f"{HOME}/.config/omarchy/shell.json"
MENU = f"{HOME}/.config/omarchy/extensions/omarchy-menu.jsonc"
QMLLINT = "/usr/lib/qt6/bin/qmllint"
SCAN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools", "qt612-color-scan.py")
passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
    else:
        failed += 1
        print(f"  ✗ {name}{': ' + detail if detail else ''}")


def strip_jsonc(text):
    # Drop // comments outside strings, then trailing commas.
    out, i, in_str = [], 0, False
    while i < len(text):
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\":
                out.append(text[i + 1]); i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True; out.append(c)
        elif text.startswith("//", i):
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        else:
            out.append(c)
        i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def load(path, jsonc=False):
    try:
        text = open(path, encoding="utf-8").read()
        return json.loads(strip_jsonc(text) if jsonc else text)
    except Exception as e:
        return e


print("protocol panel")

# ── Plugin install ────────────────────────────────────────────────────────
m = load(f"{PLUGIN}/manifest.json")
check("manifest.json parses", isinstance(m, dict), str(m))
m = m if isinstance(m, dict) else {}
check("manifest id", m.get("id") == PID, str(m.get("id")))
check("manifest is a bar widget", m.get("kinds") == ["bar-widget"], str(m.get("kinds")))
entry = (m.get("entryPoints") or {}).get("barWidget", "")
check("manifest entry point exists", bool(entry) and os.path.isfile(f"{PLUGIN}/{entry}"), entry)
check("one protocol button only", (m.get("barWidget") or {}).get("allowMultiple") is False)

qml = open(f"{PLUGIN}/{entry}", encoding="utf-8").read() if entry and os.path.isfile(f"{PLUGIN}/{entry}") else ""

# ── Bar wiring: the panel replaces the old command module in the same spot ─
s = load(SHELL_JSON)
right = [w.get("id") for w in s["bar"]["layout"]["right"]] if isinstance(s, dict) else []
check("panel is on the bar", PID in right, str(right))
check("old command-module button is gone", "atlas-protocol" not in right)
if PID in right:
    i = right.index(PID)
    check("panel sits where the old button was (after network, before glass)",
          right[i - 1:i + 2] == ["omarchy.network", PID, "com.plancher-labs.atlas-glass"], str(right[i - 1:i + 2]))
check("panel is not disabled", PID not in (s.get("disabledPlugins") or []) if isinstance(s, dict) else False)

# ── Old menu rows removed (nothing opens that menu any more) ──────────────
menu = load(MENU, jsonc=True)
check("menu file still parses", isinstance(menu, dict), str(menu))
if isinstance(menu, dict):
    left = [k for k in menu if k == "protocol" or k.startswith("protocol.")]
    check("protocol rows removed from the Omarchy menu", not left, str(left))
check("panel never summons the old menu", "omarchy menu summon" not in qml)

# ── Controls the panel must offer ─────────────────────────────────────────
check("tiles come from atlas-protocol list --json", '"list", "--json"' in qml)
check("tiles engage through atlas-protocol", "/.local/bin/atlas-protocol" in qml)
check("switches go through atlas-vibe", "/.local/bin/atlas-vibe" in qml)
toggles = re.findall(r"\bToggle\s*\{", qml)
check("three on/off switches (not checkmarks)", len(toggles) == 3, f"found {len(toggles)}")
for label in ("Music Ring", "Voice Ring", "Now Playing"):
    check(f'switch "{label}"', f'label: "{label}"' in qml)
for sw in ("music", "voice", "nowplaying"):
    check(f"switch {sw} is wired to atlas-vibe", re.search(rf'"{sw}"', qml) is not None)
check("no ✓ checkmarks", "✓" not in qml)
check("keyboard panel (Esc closes)", "KeyboardPanel" in qml and "onCloseRequested" in qml)
# PanelKeyCatcher swallows Tab, arrows, Space and Enter and only emits signals: the panel must
# drive its own cursor from them, or the keyboard does nothing (found by panel-keys-check.sh).
for sig in ("onTabRequested", "onMoveRequested", "onActivateRequested"):
    check(f"keyboard: handles {sig}", sig in qml)
check("keyboard: every switch shows the cursor", len(re.findall(r"hasCursor:\s*root\.cursor\s*===", qml)) >= 3)
check("2×2 tile grid", re.search(r"GridLayout\s*\{[^}]*columns:\s*2", qml, re.S) is not None)
check("follows state changed elsewhere (voice, terminal)", "FileView" in qml)

# ── Lint: Qt 6 syntax and the Qt 6.12 palette rule ────────────────────────
if qml:
    r = subprocess.run([QMLLINT, f"{PLUGIN}/{entry}"], capture_output=True, text=True)
    bad = [ln for ln in (r.stdout + r.stderr).splitlines() if "[syntax]" in ln or ln.startswith("Error")]
    check("qmllint: no syntax errors", not bad, "; ".join(bad[:3]))
    r = subprocess.run([sys.executable, "-I", SCAN, PLUGIN], capture_output=True, text=True)
    check("qt612 palette scan clean", r.returncode == 0, r.stdout.strip()[-200:])

print(f"  {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
