#!/usr/bin/env python3
"""atlas-power rules and Energy Saver effects, plus the thermal guard's per-profile threshold.

Runs against a fake machine in a throwaway HOME: nothing on the real desktop is touched.
"""
import importlib.machinery, importlib.util, json, os, sys, tempfile
from pathlib import Path

BIN = Path(os.environ.get("ATLAS_BIN", os.path.expanduser("~/.local/bin")))
os.environ["HOME"] = tempfile.mkdtemp(prefix="atlas-power-test.")
HOME = Path(os.environ["HOME"])
passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
    else:
        failed += 1
        print(f"  ✗ {name}{': ' + str(detail) if detail else ''}")


def load(name):
    loader = importlib.machinery.SourceFileLoader(name.replace("-", "_"), str(BIN / name))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


ap = load("atlas-power")
guard = load("atlas-thermal-guard")
check("module paths live in the test HOME", str(ap.SAVED).startswith(str(HOME)))


class FakeSystem:
    def __init__(self):
        self.calls = []
        self.hypr = {"animations:enabled": True, "decoration:blur:enabled": False,
                     "decoration:shadow:enabled": True}
        self.units = {"voxtype.service": True, "omarchy-tailscale-receive.service": False}
        self.bt = True
        self.lights = {ap.SCREEN: [96000, 96000], ap.KEYBOARD: [1, 2]}
        self.notes = []

    def hypr_get(self, option): return self.hypr[option]
    def hypr_eval(self, lua): self.calls.append(("eval", lua)); return True
    def unit_active(self, unit): return self.units[unit]

    def unit(self, verb, unit):
        self.calls.append((verb, unit)); self.units[unit] = verb == "start"; return True

    def bluetooth_on(self): return self.bt
    def bluetooth(self, state): self.calls.append(("bt", state)); self.bt = state == "on"; return True
    def light(self, device): return tuple(self.lights[device]) if device in self.lights else None

    def set_light(self, device, value):
        self.calls.append(("light", device, value)); self.lights[device][0] = value; return True

    def notify(self, glyph, title, body): self.notes.append(title)


class FakePower:
    def __init__(self, on_battery=False, percent=100.0, profile="balanced"):
        self.batt, self.pct, self.prof, self.sets = on_battery, percent, profile, []

    def on_battery(self): return self.batt
    def percent(self): return self.pct
    def profile(self): return self.prof
    def set_profile(self, name): self.sets.append(name); self.prof = name; return True


CFG = {"LOW": 15, "BRIGHTNESS": 40, "NOTIFY": 1}


def reset():
    for p in (ap.SAVED, ap.HYPR_FLAG, ap.SCREENSAVER_OFF, ap.GUARD_STATE,
              ap.OMARCHY_PROFILES / "ac", ap.OMARCHY_PROFILES / "battery"):
        p.unlink(missing_ok=True)


# ── Pure rules ──
check("15% on battery is low", ap.is_low(True, 15.0, 15))
check("16% on battery is not low", not ap.is_low(True, 16.0, 15))
check("10% while plugged in is not low", not ap.is_low(False, 10.0, 15))
check("no battery reading is not low", not ap.is_low(True, None, 15))
check("power-saver wants the effects", ap.saver_wanted("power-saver", False))
check("guard cooling is not Energy Saver", not ap.saver_wanted("power-saver", True))
check("balanced wants no effects", not ap.saver_wanted("balanced", False))
lua = ap.hypr_lua({o: False for o in ap.HYPR_OPTIONS})
check("hypr lua", lua == "hl.config({ animations = { enabled = false }, decoration = "
      "{ blur = { enabled = false }, shadow = { enabled = false } } })", lua)

# ── Omarchy's remembered profiles are held at the rules ──
reset()
ap.OMARCHY_PROFILES.mkdir(parents=True, exist_ok=True)
(ap.OMARCHY_PROFILES / "ac").write_text("balanced\n")
(ap.OMARCHY_PROFILES / "battery").write_text("performance\n")
ctl = ap.Controller(FakeSystem(), FakePower(), CFG)
ctl.pin()
check("ac pinned to performance", (ap.OMARCHY_PROFILES / "ac").read_text() == "performance\n")
check("battery pinned to balanced", (ap.OMARCHY_PROFILES / "battery").read_text() == "balanced\n")

# ── Power source rules ──
reset()
sysf, pw = FakeSystem(), FakePower(on_battery=False, profile="balanced")
ctl = ap.Controller(sysf, pw, CFG)
ctl.start()
check("start plugged in -> performance", pw.prof == "performance", pw.sets)
pw.batt, pw.pct = True, 80.0
ctl.power_changed()
check("unplug at 80% -> balanced", pw.prof == "balanced", pw.sets)
check("automatic switches notify", sysf.notes[-1] == "Balanced mode", sysf.notes)
pw.prof = "performance"           # picked by hand on battery
ctl.battery_changed()
check("a hand-picked profile is left alone on battery", pw.prof == "performance")
pw.pct = 15.0
ctl.battery_changed()
check("15% -> energy saver", pw.prof == "power-saver", pw.sets)
ctl.reconcile()
check("energy saver effects on", ap.Saver.active())
pw.prof = "balanced"              # picked by hand after the low-battery switch
ctl.battery_changed(); pw.pct = 12.0; ctl.battery_changed()
check("low battery switches only once per discharge", pw.prof == "balanced", pw.sets)
ctl.reconcile()
check("leaving energy saver by hand removes the effects", not ap.Saver.active())
pw.batt = False
ctl.power_changed()
check("plug in -> performance", pw.prof == "performance")
pw.batt, pw.pct = True, 9.0
ctl.power_changed()
check("unplug already low -> energy saver", pw.prof == "power-saver", pw.sets)
n = len(pw.sets)
ctl.power_changed()
check("a repeated signal changes nothing", len(pw.sets) == n)
ap.Saver(sysf, CFG).leave()

# ── Energy Saver effects ──
reset()
sysf = FakeSystem()
sv = ap.Saver(sysf, CFG)
sv.enter()
saved = json.loads(ap.SAVED.read_text())
check("hyprland options saved", saved["hypr"] == {"animations:enabled": True, "decoration:blur:enabled": False,
                                                   "decoration:shadow:enabled": True}, saved["hypr"])
check("animations/blur/shadow switched off live", ("eval", lua) in sysf.calls)
check("hyprland reload keeps them off", ap.HYPR_FLAG.read_text().strip().endswith(lua))
check("screensaver off", ap.SCREENSAVER_OFF.exists())
check("voxtype paused", ("stop", "voxtype.service") in sysf.calls)
check("inactive taildrop not touched", ("stop", "omarchy-tailscale-receive.service") not in sysf.calls)
check("bluetooth off", sysf.bt is False)
check("screen dimmed to 40%", sysf.lights[ap.SCREEN][0] == 38400, sysf.lights)
check("keyboard light off", sysf.lights[ap.KEYBOARD][0] == 0)
calls = len(sysf.calls)
sv.enter()
check("entering twice does nothing", len(sysf.calls) == calls)
sysf.lights[ap.KEYBOARD][0] = 2   # turned back on by hand during Energy Saver
sv.leave()
check("animations restored to saved values",
      ("eval", "hl.config({ animations = { enabled = true }, decoration = { blur = { enabled = false }, "
               "shadow = { enabled = true } } })") in sysf.calls, sysf.calls[-6:])
check("hypr flag removed", not ap.HYPR_FLAG.exists())
check("screensaver back", not ap.SCREENSAVER_OFF.exists())
check("voxtype restarted", sysf.units["voxtype.service"])
check("taildrop still off", not sysf.units["omarchy-tailscale-receive.service"])
check("bluetooth back on", sysf.bt)
check("screen brightness restored", sysf.lights[ap.SCREEN][0] == 96000)
check("hand-changed keyboard light kept", sysf.lights[ap.KEYBOARD][0] == 2)
check("saved state cleared", not ap.SAVED.exists())

reset()
sysf = FakeSystem()
sysf.bt = False
sysf.lights[ap.SCREEN][0] = 20000
ap.SCREENSAVER_OFF.parent.mkdir(parents=True, exist_ok=True); ap.SCREENSAVER_OFF.touch()
sv = ap.Saver(sysf, CFG)
sv.enter(); sv.leave()
check("a dim screen is never brightened", ("light", ap.SCREEN, 38400) not in sysf.calls)
check("bluetooth that was off stays off", not sysf.bt and ("bt", "on") not in sysf.calls)
check("screensaver that was already off stays off", ap.SCREENSAVER_OFF.exists())

reset()
sysf = FakeSystem()
del sysf.lights[ap.KEYBOARD]
ap.Saver(sysf, CFG).enter()
check("a missing keyboard backlight is skipped", ap.KEYBOARD not in json.loads(ap.SAVED.read_text())["lights"])
ap.Saver(sysf, CFG).leave()

# ── Thermal guard: no effects while it cools ──
reset()
pw = FakePower(on_battery=False, profile="power-saver")
ap.GUARD_STATE.parent.mkdir(parents=True, exist_ok=True)
ap.GUARD_STATE.write_text(json.dumps({"engaged": True, "previous": "performance"}))
ctl = ap.Controller(FakeSystem(), pw, CFG)
ctl.reconcile()
check("guard cooling does not trigger energy saver effects", not ap.Saver.active())
ap.GUARD_STATE.write_text("not json")
check("an unreadable guard state counts as idle", ap.guard_engaged() is False)

# ── Thermal guard threshold per profile ──
base = {"HOT": 82, "HOT_PERFORMANCE": 92, "COOL": 65, "NOTIFY": 0}
check("guard HOT in performance", guard.for_profile(base, "performance")["HOT"] == 92)
check("guard HOT in balanced", guard.for_profile(base, "balanced")["HOT"] == 82)
check("guard settings untouched", base["HOT"] == 82)
check("guard default HOT_PERFORMANCE", guard.settings()["HOT_PERFORMANCE"] == 92)

print(f"  {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
