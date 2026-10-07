# 🛰️ A.T.L.A.S Kit

Steve's complete **A.T.L.A.S** desktop look and tools, packed so they can be put onto a fresh
[Omarchy](https://omarchy.org) install in one go.

> **Settings only.** No personal files, passwords, logins, browser data or SSH keys are in here.

---

## 📋 Contents

1. [Before you start](#1-before-you-start)
2. [Install Omarchy on the spare drive](#2-install-omarchy-on-the-spare-drive)
3. [First boot checks](#3-first-boot-checks)
4. [Install the A.T.L.A.S kit](#4-install-the-atlas-kit)
5. [After installing](#5-after-installing)
6. [Everyday use](#6-everyday-use)
7. [Switching between Windows and A.T.L.A.S](#7-switching-between-windows-and-atlas)
8. [Updating the kit later](#8-updating-the-kit-later)
9. [Undo / troubleshooting](#9-undo--troubleshooting)
10. [What's in this repo](#10-whats-in-this-repo)

---

## 1. Before you start

You'll need:

- ✅ The **Alienware**, with its **empty spare drive** installed
- ✅ A **USB stick** (8 GB or more; it gets erased)
- ✅ Internet (Wi-Fi or cable)
- ✅ Your **GitHub** login

### ⚠️ Do these first, in Windows

**1. Save your BitLocker recovery key.** Changing BIOS settings can make Windows ask for it.
Get it from <https://account.microsoft.com/devices/recoverykey>, or in Windows run (as admin):

```powershell
manage-bde -protectors -get C:
```

Write the 48-digit key down somewhere that isn't this laptop.

**2. Note the size of each drive,** so you pick the right one later. In Windows:
**Start → type "Disk Management" → open it.** Write down the Windows drive's size and the empty drive's size.

> 🚨 The Omarchy installer **erases the entire drive you pick**. Picking the Windows drive by mistake wipes Windows.

---

## 2. Install Omarchy on the spare drive

### 2.1 Make the USB installer

1. Download the Omarchy ISO from **<https://omarchy.org>**.
2. Write it to the USB stick with **[balenaEtcher](https://etcher.balena.io)** or **[Rufus](https://rufus.ie)** (in Rufus, choose *DD mode* if it asks).

### 2.2 BIOS settings

1. Restart and tap **F2** to open the BIOS.
2. Set **Secure Boot → Disabled**.
3. If there's a **SATA/Storage mode** option, make sure it's **AHCI** (not RAID/RST). If you change it, Windows may need a fix later, so skip this if it's already AHCI.
4. Save and exit (**F10**).

### 2.3 Boot the installer

1. Plug in the USB stick.
2. Restart and tap **F12** for the boot menu.
3. Pick the **USB stick**.

### 2.4 Run the installer

- Pick your keyboard layout, username and password.
- **Use the username `steve`** if you like. The kit works with any username, but `steve` matches the old laptop exactly.
- When it asks for the **disk**, choose the **empty drive** (match the size you wrote down). **Not the Windows one.**
- Let it finish, remove the USB stick, and reboot.

---

## 3. First boot checks

Open a terminal with **Super + Enter** and run these:

```bash
# Internet working?
ping -c 3 github.com

# NVIDIA graphics working? (should show your GPU and driver version)
nvidia-smi

# Everything up to date
omarchy update
```

> If `nvidia-smi` says "command not found" or errors, the NVIDIA driver didn't install. Fix that
> before going further (see [Troubleshooting](#9-undo--troubleshooting)).

---

## 4. Install the A.T.L.A.S kit

### 4.1 Get the tools and sign in to GitHub

```bash
omarchy pkg add github-cli rsync
gh auth login
```

For `gh auth login` choose: **GitHub.com → HTTPS → Yes → Login with a web browser**, then
enter the code it shows in the browser.

### 4.2 Download the kit

```bash
gh repo clone Steve-Plancher/atlas-kit ~/atlas-kit
```

### 4.3 Run the installer

```bash
~/atlas-kit/install.sh
```

What it does, in order:

| Step | What happens |
|---|---|
| 1 | Backs up anything it will replace → `~/atlas-kit-backup-<date>/` |
| 2 | Copies the A.T.L.A.S settings, scripts, themes and wallpapers |
| 3 | Installs the extra apps (asks for your password) |
| 4 | Downloads the third-party bar plugins |
| 5 | Builds the protocol colors and cursors, applies the A.T.L.A.S theme |
| 6 | Starts services and reloads the desktop |

> 💡 Only want the look, without the extra apps? Run `~/atlas-kit/install.sh --no-apps`

### 4.4 Log out and back in

Press **Super + Escape → Logout** (or reboot), so every app picks up the new cursor and colors.

---

## 5. After installing

### Set up your screens

The old laptop's monitor layout is **not** copied. Arrange the Alienware's screens with:

```bash
nwg-displays
```

### Things that won't be there (on purpose)

| Item | Why |
|---|---|
| Thermal guard / fan control | Made for the old Intel laptop. The Alienware has its own cooling |
| Fingerprint setup | Different hardware |

The laptop-only files are kept in [`machine-specific/`](machine-specific) if you ever want them.

**Optional:** the dock/monitor helper service:

```bash
cp ~/atlas-kit/machine-specific/home/.config/systemd/user/atlas-display-dock.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now atlas-display-dock
```

---

## 6. Everyday use

| Want to… | Do this |
|---|---|
| Change color protocol | Click **STANDBY** in the bar, or left double-click the desktop and pick a colored A.T.L.A.S |
| Change wallpaper only | **Left double-click** the desktop |
| Change the whole theme | **Right double-click** the desktop. ⚠️ This replaces the A.T.L.A.S look. Choose **Hackerman** to get it back |
| See-through windows | Glass icon in the bar |
| Voice typing | Hold **F9** and talk |

Protocols from a terminal:

```bash
atlas-protocol                 # which one is active
atlas-protocol code-red        # standby | code-red | clean-slate | house-party
atlas-protocol next            # cycle to the next one
```

---

## 7. Switching between Windows and A.T.L.A.S

Each system lives on its own drive and they don't touch each other.

- Restart and tap **F12** → pick **Windows Boot Manager** or **Omarchy/Linux**.
- To change which one starts by default: **F2 (BIOS) → Boot sequence** → move your favorite to the top.

---

## 8. Updating the kit later

**On the old laptop**, after changing your setup, ask Claude to *"refresh the atlas-kit and push it"*.

**On the Alienware**, pull the changes and re-apply:

```bash
cd ~/atlas-kit
git pull
./install.sh --no-apps
```

---

## 9. Undo / troubleshooting

### Put back what the installer replaced

```bash
ls ~ | grep atlas-kit-backup                          # find the backup folder
rsync -a ~/atlas-kit-backup-<date>/ ~/                # restore it
omarchy restart shell
```

### The bar looks wrong or widgets are missing

```bash
omarchy restart shell
```

### The A.T.L.A.S theme or wallpaper didn't apply

```bash
omarchy theme set hackerman
omarchy-theme-bg-set ~/.config/omarchy/backgrounds/hackerman/00-atlas.png
```

### The cursor is still the default arrow

```bash
hyprctl setcursor Atlas-Cyan 24
```

Then log out and back in.

### NVIDIA problems (black screen, flicker, `nvidia-smi` fails)

```bash
omarchy update                       # newest drivers
lspci -k | grep -A3 -i nvidia        # shows which driver is loaded
```

If it still misbehaves, open Claude on the Alienware and paste the output.

### Hyprland config errors (red error bar at the top)

```bash
hyprctl configerrors
```

---

## 10. What's in this repo

| Folder / file | What it is |
|---|---|
| `home/` | Settings and tools, laid out exactly where they go in your home folder |
| `apps.txt` | Extra apps (official repos) |
| `apps-aur.txt` | Extra apps (AUR) |
| `plugins.txt` | Third-party bar plugins, downloaded fresh from GitHub at a pinned version |
| `machine-specific/` | Things tuned to the old laptop, **not installed automatically** |
| `install.sh` | The installer |

**Included:** A.T.L.A.S blue theme colors · A.T.L.A.S wallpapers · live HUD · Protocols (Standby,
Code Red, Clean Slate, House Party; colors only) · bar layout and custom widgets · glass · snap and
title bars · lock screen · notifications · agents widget · Atlas-Cyan animated cursor · window look
and keybindings · terminal configs · Voxtype config.
