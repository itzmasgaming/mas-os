# MAS OS ISO builder (v0.2 - automatic setup)

Boot the ISO and MAS sets itself up. **There is no installer to open.**

> **Status: not booted yet.** This kit was written without being able to build or boot an Arch ISO.
> What was tested: the setup screen (rendered at 3 sizes), the login screen (with and without a password),
> and the disk part of the installer on a real loop disk (partitions, Btrfs, copy, fstab, account, recovery key).
> NOT tested: the Arch-only steps (`arch-chroot`, `mkinitcpio`, `grub-install`) and the kexec jump.
> If the first build or boot fails, send the error text (the install log is `/var/log/mas-install.log`).

## What happens now

1. **Boot the ISO.** No menu to answer, no desktop to click through. The **First-time setup** covers the screen.
2. **Step 1** - name your account, pick the disk (it picks the first free one for you).
3. **Step 2** - **Protect this device**: add a password, or skip it.
4. **Step 3** - MAS installs itself (a few minutes, no internet needed). You get the recovery key if you set a password. Press **Restart now**.
5. **Every start after that** shows the MAS login screen: an account **without a password** shows only a **Sign In** button, an account **with a password** shows the password box.

If the VM or PC still boots the ISO after the install, MAS notices it is already installed and jumps into the installed system by itself (kexec). To install again, add `mas.reinstall` to the boot options of the ISO.

"Try MAS without installing" (bottom left of step 1) opens the live XFCE desktop instead. Start menu > **Install MAS** runs the setup again.

## What the screenshot with the mouse was

That was the **XFCE** desktop (the mouse logo is XFCE's). It is the simple desktop that the old ISO started inside VirtualBox, because KDE Plasma 6.8 goes black in virtual machines. The system under it **is** Arch Linux (built with `archiso`). In v0.2 XFCE is the only desktop, so what you see in VirtualBox is what everybody gets.

## What is inside

| Wanted | How |
|---|---|
| Runs `.exe` / `.msi` | **Wine** + Wine Mono + Gecko + winetricks + 32-bit audio/graphics libraries. Double-click a `.exe`. The Wine folder is prepared in the background at the first login |
| Fast, quiet, Linux base | Arch Linux, XFCE on X11, PipeWire audio. No extra apps |
| Closed by default | `nftables` blocks everything coming in. Nothing listens (the ISO's SSH is removed) |
| Dot when something connects | **MAS Shield**: an amber dot at the top right of the screen + a notification |
| Restore points | Btrfs (`@`, `@home`, `@snapshots`) + Snapper |
| Recovery key | Shown after step 3 (text + QR). Reset a forgotten password at the "Forgot your password?" prompt (press **R**) |
| Password = root password | One password for your account and `root`. No password clears both |
| Archives, Ubuntu LTS, Sandbox VM, Brave | `.zip/.rar` (Xarchiver), Ubuntu LTS window (Distrobox), Sandbox (QEMU), Brave (Flatpak, first open) |
| Virtual machines | VirtualBox guest tools (clipboard, window resize), QEMU and VMware agents |

## Build the ISO

**GitHub (nothing to install):** upload this folder to a public repository (keep `.github`), open **Actions > Build MAS ISO > Run workflow**, wait 30-60 minutes, download **MAS-ISO**.

**Arch machine:** `sudo bash build-mas.sh` (needs about 15 GB free). **Ubuntu/other with Docker:** `bash run-docker.sh`. The ISO appears in `out/`.

## Try it in VirtualBox

New VM: Linux / Arch Linux (64-bit), 4 GB RAM or more, 2 CPUs, **40 GB disk**, **Enable EFI** on, Graphics Controller **VMSVGA**, 3D acceleration **off**. Put the ISO in the optical drive and start it. The installer erases the virtual disk only.

## Files you may want to change

| File | What |
|---|---|
| `overlay/usr/local/bin/mas-setup` | The first-time setup screen (GTK4, colours and texts at the top / in `make_css`) |
| `overlay/usr/local/bin/mas-install-auto` | The automatic installer (disk layout, what is copied, boot loader) |
| `overlay/usr/local/bin/mas-live-boot` | Jumps into an installed MAS when the ISO is started again |
| `overlay/usr/share/sddm/themes/mas/Main.qml` | The login screen |
| `packages.txt` / `optional.txt` | Packages |

## Not done yet

- NVIDIA drivers, Secure Boot (turn it off), AppArmor, a performance kernel.
- A time zone picker (the installer guesses it from the internet, else UTC).
- A screen lock (the Lock Screen action is not available).
- The Shield dot only sees incoming connections.
