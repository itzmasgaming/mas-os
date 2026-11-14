# MAS OS ISO builder (v0.1)

This folder turns into the **MAS OS ISO** (a disk image you can start in a virtual machine or from a USB stick).
It builds MAS on top of Arch Linux with a KDE Plasma desktop that is restyled with your logo.

> **Status: reviewed and fixed, but still not booted by the author.** The scripts were checked line by line and
> dry-run against the real archiso profile, but a full build and boot could not be run. If the build stops
> or the desktop does not appear, send the error text (or the output of `mas-debug`) and it will be fixed.

## What the ISO contains

| You asked for | How it is done |
|---|---|
| Linux base, fast, no preinstalled apps | Arch Linux + a minimal KDE Plasma. Only a file manager (Dolphin), terminal (Konsole), archive tool (Ark) and Settings are included |
| `.exe` / `.msi` apps and games | **Wine** (double-click a `.exe`) |
| `.zip` `.rar` `.7z` | Ark, unzip, unrar, 7zip |
| `.apk` Android apps and games | **Waydroid** (double-click an `.apk`; Android is downloaded, about 1 GB, the first time) |
| "Ubuntu LTS" icon opens a small command window | `Ubuntu LTS` launcher: a 100x28 terminal running an Ubuntu container (Distrobox). First open downloads Ubuntu |
| Brave included | `Brave` launcher installs Brave from Flathub the first time you open it (needs internet) and makes it the default browser |
| Protected, no one can connect in | `nftables` firewall: all incoming connections are blocked, replies to your own connections are allowed |
| Dot in the top-right when something connects | **MAS Shield** (`mas-shield`): an amber dot appears in the top-right corner while something is connected in, plus a notification |
| Windows-style right-click menus, window buttons, light/dark mode | Built into KDE Plasma. Light/dark: Settings > Colors & Themes. The MAS wallpaper switches with it |
| Logo as default background | `MAS` wallpaper (dark and light versions), also on the login screen and the start button |
| Sandbox VM that resets when closed | `Sandbox` launcher: a throw-away QEMU virtual machine. Put an `.iso`, `.qcow2` or `.img` in `~/Sandbox` first |
| Restore points | Btrfs + Snapper. A snapshot is taken before every update (installed Btrfs system only; set up by the installer step) |
| Live session RAM space | The live session has 2 GB of RAM space for downloads (Brave, Ubuntu). Use 6 GB+ of VM RAM, or install to disk |
| Install it on a disk | `Install MAS` icon on the live desktop |

## Step 1 - Build the ISO

You need **Arch Linux** to build it. Pick one way.

### Option A - GitHub does the building (nothing to install on Windows)

1. Create a **public** repository on GitHub and upload everything in this folder (keep the `.github` folder).
2. Open the repository's **Actions** tab, choose **Build MAS ISO**, press **Run workflow**.
3. Wait (about 30 to 60 minutes). When it turns green, open the run and download the **MAS-ISO** file at the bottom. It is a zip with the `.iso` inside. It is about 2.5 to 3 GB.

### Option B - Build on an Arch Linux machine or Arch VM

```
sudo pacman -S git
# copy this folder to the machine, then inside it:
sudo bash build-mas.sh
```

The ISO appears in `out/` (for example `out/mas-2026.11.13-x86_64.iso`). It needs about 15 GB of free disk space.

### Option C - Ubuntu (or any Linux that is not Arch), using Docker

Open a terminal inside this folder and type:

```
bash run-docker.sh
```

It installs Docker if needed, builds the ISO in a temporary Arch container, and leaves the ISO in `out/`.

## Step 2 - Try it in VirtualBox (your Windows files are not touched)

1. VirtualBox > **New**. Type: Linux, Version: Arch Linux (64-bit).
2. 4 GB RAM or more, 2 CPUs or more, a 40 GB virtual disk.
3. Settings > System > tick **Enable EFI**.
4. Settings > Display: Graphics Controller **VMSVGA**, Video Memory **128 MB**, and leave **Enable 3D Acceleration OFF** (MAS draws with the CPU inside a virtual machine, which is the reliable way in VirtualBox).
5. Settings > Storage: put the MAS ISO in the optical drive. Start the VM.
6. Pick **MAS OS install medium**. After a minute you get the MAS desktop with your logo.

Inside a virtual machine MAS switches to "safe drawing" on its own (`mas-gfx`), so the desktop is slower and has fewer visual effects than on a real computer. On a real computer it uses the graphics card as normal.

Android apps (Waydroid) and heavy games need real hardware or a GPU. Expect them not to work inside VirtualBox.

### Black screen with only a mouse cursor?

The cause is nearly always the desktop (KDE Plasma on Wayland) failing to draw on the virtual graphics card.
This version protects against it in three ways:

1. **Automatic fallback.** In a VM, the live session tries the X11 desktop first (the most compatible), then Wayland with
   CPU drawing, then basic CPU drawing. If the desktop is not up after about 2.5 minutes, it switches to the next
   one by itself and restarts the login. Just wait a few minutes.
2. **Boot menu entries.** The boot menu now has **MAS OS - safe graphics: X11**, **Wayland CPU drawing**,
   **basic**, and **text mode only**. If the first entry shows black, reboot and pick the X11 entry.
3. **Manual control** from a text console: `sudo mas-gfx x11` (or `soft`, `basic`, `normal`, `auto`), then
   `sudo systemctl restart sddm`.

VM settings that help: Graphics Controller **VMSVGA**, Video Memory **128 MB**, 3D Acceleration **off**.
Still black? Press **Right Ctrl + F3** for a text console, log in as `mas` (no password), run `mas-debug`
and send a screenshot (it also saves `~/mas-debug.txt`).

## Step 3 - Install it on a disk

On the live desktop, double-click **Install MAS** and follow the steps. It starts the Arch installer, then adds MAS on top.
**It erases the disk you choose.** In a VM that is only the virtual disk.

## Not done yet

- Plasma 6.8 and newer drop the X11 session. If the `plasma-x11-session` package is no longer in Arch, the build skips it and
  the fallback ladder uses only the two Wayland CPU-drawing modes (the build log says "optional package not found").
- A performance kernel (Zen/XanMod). It uses the normal Arch kernel for now so that it boots reliably.
- AppArmor.
- NVIDIA drivers (open-source AMD and Intel graphics are included).
- Secure Boot. Turn Secure Boot off in the firmware.
- A ready-made Sandbox image: bring your own ISO.
- The Shield dot is a simple overlay. It sees incoming connections only. It cannot detect a program on this computer that connects OUT to someone, because that is how normal apps (and some malware) work.
- The Sandbox network is "internet only" in spirit, but the virtual machine can still reach network services that run on the host's loopback address. Use `MAS_SANDBOX_NET=none` for no network.

## If the build fails

Copy the last 30 lines of the output and send them. The most likely causes are a package that was renamed in Arch, or a small boot-configuration difference between archiso versions.
