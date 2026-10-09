#!/usr/bin/env python3
"""atlas-beat: music mode output, and the --mic voice-ring mode against a virtual microphone.

Needs a running PipeWire session. Creates a temporary null sink whose monitor acts as the
"mic" (nothing is audible), plays a test tone into it, and removes it afterwards.
"""
import json, math, os, struct, subprocess, sys, tempfile, threading, time, wave

BEAT = os.environ.get("ATLAS_BEAT", os.path.expanduser("~/.local/bin/atlas-beat"))
passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
    else:
        failed += 1
        print(f"  ✗ {name}{': ' + detail if detail else ''}")


def collect(cmd, seconds, env=None):
    """Run cmd for `seconds`, return parsed JSON frames with timestamps."""
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, env=env)
    frames, t0 = [], time.monotonic()

    def read():
        for line in p.stdout:
            try:
                frames.append((time.monotonic() - t0, json.loads(line)))
            except ValueError:
                frames.append((time.monotonic() - t0, {"bad": line}))
    th = threading.Thread(target=read, daemon=True); th.start()
    return p, frames


def tone_wav(path, seconds=4, freqs=(220, 880, 2500), amp=0.25):
    """Speech-like test signal: 300 ms bursts with 200 ms gaps (about -25 dBFS per tone)."""
    def sample(i):
        if (i % 24000) >= 14400:                 # 300 ms on, 200 ms off
            return 0
        return int(32767 * amp * sum(math.sin(2 * math.pi * f * i / 48000) for f in freqs) / len(freqs))
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(48000)
        w.writeframes(b"".join(struct.pack("<h", sample(i)) for i in range(int(48000 * seconds))))


def noisy_room_wav(path, noise_s=5, talk_s=4, noise_amp=0.08, burst_amp=0.35, freqs=(220, 880, 2500)):
    """A fan-like room (white noise whose level wanders +-30%), then speech-like bursts on top."""
    import random
    rnd = random.Random(7)
    frames = []
    for i in range(int(48000 * (noise_s + talk_s))):
        wander = 1 + 0.3 * math.sin(2 * math.pi * 0.7 * i / 48000) * math.sin(2 * math.pi * 0.13 * i / 48000 + 1)
        x = rnd.gauss(0, noise_amp * wander)
        if i >= 48000 * noise_s and (i % 24000) < 14400:
            x += burst_amp * sum(math.sin(2 * math.pi * f * i / 48000) for f in freqs) / len(freqs)
        frames.append(struct.pack("<h", max(-32767, min(32767, int(32767 * x)))))
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(48000)
        w.writeframes(b"".join(frames))


def children(pid):
    """cava processes started by this atlas-beat (the HUD's own analyzers are not ours to judge)."""
    out = subprocess.run(["pgrep", "-P", str(pid), "-x", "cava"], capture_output=True, text=True).stdout.split()
    return set(out)


def alive(pids):
    return {p for p in pids if os.path.exists(f"/proc/{p}")}


print("atlas-beat")

# ── Music mode (unchanged contract the HUD relies on) ──
p, frames = collect([BEAT], 2.5)
time.sleep(2.5); mine = children(p.pid); p.terminate(); p.wait(3)
good = [f for _, f in frames if "bad" not in f]
check("music mode prints frames", len(good) > 20, f"{len(good)} frames")
check("music frames: 32 bands + l/beat/drop", all(len(f.get("b", [])) == 32 and {"l", "beat", "drop"} <= set(f) for f in good))
time.sleep(0.5)
check("music mode started its own cava", len(mine) == 1, str(mine))
check("music mode leaves no cava behind", not alive(mine), str(alive(mine)))

# ── Mic mode against a virtual mic ──
sink = "atlas_test_mic"
mod = subprocess.run(["pactl", "load-module", "module-null-sink", f"sink_name={sink}",
                      "sink_properties=device.description=AtlasTestMic"], capture_output=True, text=True).stdout.strip()
default_sink = subprocess.run(["pactl", "get-default-sink"], capture_output=True, text=True).stdout.strip()
try:
    time.sleep(0.5)
    env = dict(os.environ, ATLAS_MIC_SOURCE=f"{sink}.monitor")
    p, frames = collect([BEAT, "--mic"], 0, env)
    time.sleep(2.5)                          # silence
    t_tone = 2.5
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "tone.wav"); tone_wav(wav)
        subprocess.run(["pw-play", "--target", sink, wav], capture_output=True)  # blocks ~4 s
    time.sleep(1.0)

    # The cava for the mic must ask for the relaxed buffer (Spotify underrun fix).
    dump = json.loads(subprocess.run(["pw-dump"], capture_output=True, text=True).stdout or "[]")
    props = [o["info"]["props"] for o in dump if o.get("type") == "PipeWire:Interface:Node"
             and (o.get("info", {}).get("props") or {}).get("node.name") == "cava"]
    mic = [pr for pr in props if pr.get("target.object")]   # the music cava has no explicit target
    # cava names a monitor by its sink; a real mic is targeted by its own name.
    # (the HUD's own voice ring may be listening to the real mic at the same time)
    check("mic cava listens to the requested source", [pr["target.object"] for pr in mic].count(sink) == 1,
          str([pr.get("target.object") for pr in mic]))
    check("mic cava requests 2048/48000 latency", mic and all(pr.get("node.latency") == "2048/48000" for pr in mic),
          str([pr.get("node.latency") for pr in mic]))
    mine = children(p.pid)
    p.terminate(); p.wait(3)

    good = [(t, f) for t, f in frames if "bad" not in f]
    check("mic mode prints frames", len(good) > 50, f"{len(good)} frames")
    check("mic frames are exactly {v: 24 levels, l}", all(set(f) == {"v", "l"} and len(f["v"]) == 24 for _, f in good),
          str(good[0][1] if good else None))
    check("mic levels are within 0..1", all(0 <= x <= 1 for _, f in good for x in f.get("v", [1])))
    quiet = [max(f.get("v", [0])) for t, f in good if 1.0 < t < t_tone - 0.2]
    loud = [max(f.get("v", [0])) for t, f in good if t_tone + 0.5 < t < t_tone + 3.5]
    check("silence keeps the ring flat", quiet and max(quiet) < 0.1, f"max {max(quiet) if quiet else None}")
    peaks = sorted(loud)[-len(loud) // 3:] if loud else []    # the bursts, not the gaps
    check("speech-like sound lifts the ring", peaks and sum(peaks) / len(peaks) > 0.4, f"burst avg {sum(peaks) / len(peaks) if peaks else None}")
    burst = sum(peaks) / len(peaks) if peaks else 0
    check("the ring pulses: falls below half its burst height between bursts", loud and min(loud) < burst / 2,
          f"min {min(loud) if loud else None} vs burst {burst:.2f}")
    louds = [f["l"] for t, f in good if t_tone + 1.0 < t < t_tone + 3.5]
    check("loudness rises with sound", louds and max(louds) > 0.1, f"max l {max(louds) if louds else None}")
    time.sleep(0.5)
    check("mic mode started its own cava", len(mine) == 1, str(mine))
    check("mic mode leaves no cava behind", not alive(mine), str(alive(mine)))

    # A noisy room: the wandering background must not move the ring; speech on top of it must.
    p, frames = collect([BEAT, "--mic"], 0, env)
    time.sleep(1.0)
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "room.wav"); noisy_room_wav(wav)
        t_play = 1.0
        subprocess.run(["pw-play", "--target", sink, wav], capture_output=True)   # blocks ~9 s
    p.terminate(); p.wait(3)
    good = [(t, f) for t, f in frames if "v" in f]
    noise = sorted(max(f["v"]) for t, f in good if t_play + 2.0 < t < t_play + 5.0)
    talk = sorted(max(f["v"]) for t, f in good if t_play + 5.3 < t < t_play + 9.0)
    p90 = noise[int(len(noise) * 0.9)] if noise else None
    check("a wandering room background keeps the ring (nearly) flat", noise and p90 < 0.15, f"p90 {p90}")
    tpk = talk[-len(talk) // 3:] if talk else []
    check("speech over the room background lifts the ring", tpk and sum(tpk) / len(tpk) > 0.4,
          f"burst avg {sum(tpk) / len(tpk) if tpk else None}")
finally:
    if mod.isdigit():
        subprocess.run(["pactl", "unload-module", mod])
check("default speaker unchanged by the test", subprocess.run(["pactl", "get-default-sink"], capture_output=True, text=True).stdout.strip() == default_sink)
print(f"  {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
