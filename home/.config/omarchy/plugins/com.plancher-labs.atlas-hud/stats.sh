#!/bin/bash
# One line of raw readings for the HUD. Deltas (CPU, network) are computed in QML.
# Fields: cpuTotal cpuIdle memTotal memAvail tempMilli batPct batState rxBytes txBytes
#         uptimeSec platformProfile pausedFlag screensaverSec screensaverRuns wordmarkMode
#         backgroundName...   (backgroundName stays last: a filename may contain spaces)
read -r _ u n s i w q sq st _ < /proc/stat
total=$((u + n + s + i + w + q + sq + st)); idle=$((i + w))
read -r mt ma < <(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print t+0, a+0}' /proc/meminfo)
temp=0
for z in /sys/class/thermal/thermal_zone*; do
  [[ $(<"$z/type") == x86_pkg_temp ]] && temp=$(<"$z/temp") && break
done
bat=-1; bstate=None
for b in /sys/class/power_supply/BAT*; do
  [[ -r $b/capacity ]] && bat=$(<"$b/capacity") && bstate=$(<"$b/status") && break
done
read -r rx tx < <(awk 'NR>2 && $1!="lo:" {rx+=$2; tx+=$10} END{print rx+0, tx+0}' /proc/net/dev)
up=$(cut -d' ' -f1 /proc/uptime)
profile=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo unknown)
paused=0; [[ -e $HOME/.local/state/atlas-hud/paused ]] && paused=1
# Omarchy's idle settings, so the HUD freezes exactly when the screensaver takes over.
saver=$(jq -r '.idle.screensaver // 150' "$HOME/.config/omarchy/shell.json" 2>/dev/null || echo 150)
saverRuns=1
[[ -e $HOME/.local/state/omarchy/indicators/stay-awake || -e $HOME/.local/state/omarchy/toggles/screensaver-off ]] && saverRuns=0
# Wordmark animation mode, switched live by atlas-wordmark.
wm=$(cat "$HOME/.local/state/atlas-hud/wordmark" 2>/dev/null)
[[ $wm =~ ^(off|power-on|sweep|glitch|reactive|holo)$ ]] || wm=off
bg=$(basename "$(readlink -f "$HOME/.local/state/omarchy/current/background")")
echo "$total $idle $mt $ma $temp $bat ${bstate// /_} $rx $tx $up $profile $paused ${saver:-150} $saverRuns $wm $bg"
