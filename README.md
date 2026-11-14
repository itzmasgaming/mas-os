# MAS OS ISO builder (v0.1)

This folder turns into the **MAS OS ISO** (a disk image you can start in a virtual machine or from a USB stick).
It builds MAS on top of Arch Linux with a KDE Plasma desktop that is restyled with your logo.

> **Status: untested.** This kit was written without being able to run a build or boot the result.
> The first build may stop with an error. If it does, send the error text and it will be fixed.

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
| Restore points | Btrfs + Snapper. A snapshot is taken before every update (installed system only) |
| First-time screen: add a password or not | `mas-welcome`: a window at the first login with **Add password / No password / Ask me later**. It also appears in the live session (every time you start the ISO) so you can see it. Live passwords are empty: just press Enter. The live session never locks itself |
| Default account with no password | The account **mas** has no password, in the live session and on an installed MAS. You are never asked for an administrator password while you use it. It signs in by itself on an installed MAS. When you press **Add password** in the welcome window, all of that switches off and the account is protected like any other |
| Create and delete accounts | Start menu > **Accounts (create or delete)**. Log in as **mas**, create your own administrator account, log out, log in as your new account, and delete **mas** if you do not want it. It refuses to delete an account that is signed in, or the last administrator |
| The password is also the root password | When you press **Add password**, MAS sets that same password for your account and for `root`. **No password** clears both |
| Recovery key (forgot password) | After you add a password, a window shows a **recovery key** and a **QR code** (scan it with your phone to save a copy). On an installed MAS, press **R** within 3 seconds at the "Forgot your password?" message that shows before the login screen, type the key, and choose a new password. The old key then stops working and you get a new one. In the live session use Start menu > **Reset password (recovery key)**. A camera can scan the QR code if the computer has one. Make a new key any time: `sudo mas-recovery new` |
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

After the first boot menu, MAS shows its own menu on a text screen: **How should the desktop start?**

- **1** Automatic (nothing pressed for 12 seconds also means 1)
- **2** Safe: Plasma drawn by the CPU. Try this if the screen goes black.
- **3** OpenGL on the CPU
- **4** Graphics card (real computers)
- **5** Simple desktop: **XFCE** instead of Plasma. It works in every virtual machine, so use it if 1 and 2 stay black. Same apps, same launchers, same wallpaper, plainer look.
- **6** Troubleshoot: starts normally, stops the desktop after about a minute and prints a report about what went wrong on the second text console (Right Ctrl + F2 shows it again).

Why: KDE Plasma 6.8 and newer is Wayland only, and VirtualBox's virtual graphics card is known to break it. XFCE runs on X11 and does not have that problem.

To skip that menu or set the mode by hand:

1. Shut the VM down, then in Display settings make sure 3D Acceleration is **off** and Graphics Controller is **VMSVGA**.
2. Start it again. At the boot menu press **e** (UEFI) or **Tab** (BIOS) and add one of these to the end of the line, then continue the boot:
   - `mas.gfx=basic` (CPU drawing, most reliable)
   - `mas.gfx=soft` (OpenGL on the CPU)
   - `mas.gfx=normal` (use the virtual graphics card as is)
3. Still black? Press **Right Ctrl + F3** to get a text console, log in as `mas` (no password) and run `mas-debug`. Send a screenshot of what it prints.

On a text console you can also change the mode for good with `sudo mas-gfx basic` (or `soft`, `normal`, `auto`) followed by `sudo systemctl restart sddm`.

## Step 3 - Install it on a disk

On the live desktop, double-click **Install MAS** and follow the steps. It starts the Arch installer, then adds MAS on top.
**It erases the disk you choose.** In a VM that is only the virtual disk.

## Not done yet

- Plasma 6.8 and newer have no X11 session, so MAS is Wayland only. Weak virtual graphics cards are handled by `mas-gfx`, not by an X11 fallback.
- A performance kernel (Zen/XanMod). It uses the normal Arch kernel for now so that it boots reliably.
- AppArmor.
- NVIDIA drivers (open-source AMD and Intel graphics are included).
- Secure Boot. Turn Secure Boot off in the firmware.
- A ready-made Sandbox image: bring your own ISO.
- The Shield dot is a simple overlay. It sees incoming connections only. It cannot detect a program on this computer that connects OUT to someone, because that is how normal apps (and some malware) work.
- The Sandbox network is "internet only" in spirit, but the virtual machine can still reach network services that run on the host's loopback address. Use `MAS_SANDBOX_NET=none` for no network.

## If the build fails

Copy the last 30 lines of the output and send them. The most likely causes are a package that was renamed in Arch, or a small boot-configuration difference between archiso versions.
