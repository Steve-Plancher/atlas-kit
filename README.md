# A.T.L.A.S Kit

Steve's A.T.L.A.S desktop look and tools, packed so they can be put onto a fresh Omarchy install,
for example the Alienware. It holds **settings and customizations only**: no personal files,
passwords, logins, browser data or SSH keys.

## Install on a new machine

1. Install **Omarchy** normally from its official installer (it sets up the right drivers, such as NVIDIA).
2. Open a terminal and download the kit:
   ```bash
   gh auth login                      # sign in to GitHub once
   gh repo clone Steve-Plancher/atlas-kit ~/atlas-kit
   ```
3. Run the installer:
   ```bash
   ~/atlas-kit/install.sh             # or: ~/atlas-kit/install.sh --no-apps
   ```
4. Log out and back in.

Anything the installer replaces is first copied to `~/atlas-kit-backup-<date>/`.

## What's inside

| Folder / file | What it is |
|---|---|
| `home/` | Settings and tools, laid out exactly where they go in your home folder |
| `apps.txt` / `apps-aur.txt` | Extra apps installed on top of stock Omarchy |
| `plugins.txt` | Third-party bar plugins, downloaded fresh from their GitHub pages |
| `machine-specific/` | Things tuned to the old laptop. **Not installed automatically** |
| `install.sh` | Does all of the above |

Included: Hackerman/A.T.L.A.S blue theme colors, A.T.L.A.S wallpapers, live HUD, Protocols
(Standby, Code Red, Clean Slate, House Party; colors only), bar layout and custom widgets,
glass, snap and title bars, lock screen, notifications, agents widget, Atlas-Cyan animated cursor,
window look and keybindings, terminal configs, Voxtype config.

## After installing on the Alienware

- **Screens:** the old laptop's monitor layout isn't copied. Set the new screens up with
  `nwg-displays` (or Omarchy's display settings).
- **Heat:** `atlas-thermal-guard` / `atlas-fan` were written for the old Intel laptop and aren't
  installed. The Alienware has its own cooling.

## Updating the kit

The kit is a snapshot. After changing your setup on the laptop, ask Claude to refresh the kit
and push the update.
