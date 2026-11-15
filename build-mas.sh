#!/usr/bin/env bash
# build-mas.sh - builds the MAS OS ISO.
# Run it on Arch Linux (or inside an Arch Linux container) as root:
#     sudo bash build-mas.sh
# The finished ISO is written to ./out/
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${WORK:-/var/tmp/mas-build}"
OUT="${OUT:-$HERE/out}"
PROFILE="$WORK/profile"

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root:  sudo bash build-mas.sh" >&2
  exit 1
fi
if ! command -v pacman >/dev/null 2>&1; then
  echo "This script must run on Arch Linux (or in an Arch Linux container)." >&2
  exit 1
fi
if [[ -z "$WORK" || "$WORK" == "/" ]]; then
  echo "WORK must not be empty or /" >&2
  exit 1
fi

echo "==> Installing build tools (archiso)"
pacman -Syu --noconfirm --needed archiso

echo "==> Preparing a clean build folder: $WORK"
rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"
cp -r /usr/share/archiso/configs/releng "$PROFILE"

echo "==> Branding the ISO"
sed -i 's/^iso_name=.*/iso_name="mas"/' "$PROFILE/profiledef.sh"
sed -i 's/^iso_label=.*/iso_label="MAS_$(date +%Y%m)"/' "$PROFILE/profiledef.sh"
sed -i 's/^iso_publisher=.*/iso_publisher="MAS OS"/' "$PROFILE/profiledef.sh"
sed -i 's/^iso_application=.*/iso_application="MAS OS live and installer"/' "$PROFILE/profiledef.sh"
for d in syslinux grub efiboot; do
  if [[ -d "$PROFILE/$d" ]]; then
    grep -rl "Arch Linux" "$PROFILE/$d" 2>/dev/null | xargs -r sed -i 's/Arch Linux/MAS OS/g' || true
  fi
done
if [[ -f "$HERE/assets/splash.png" && -f "$PROFILE/syslinux/splash.png" ]]; then
  cp "$HERE/assets/splash.png" "$PROFILE/syslinux/splash.png"
fi

echo "==> Boot logo: hide the boot messages and show the MAS logo (Plymouth)"
for d in syslinux grub efiboot; do
  if [[ -d "$PROFILE/$d" ]]; then
    grep -rl 'archisosearchuuid=%ARCHISO_UUID%' "$PROFILE/$d" 2>/dev/null \
      | xargs -r sed -i 's/archisosearchuuid=%ARCHISO_UUID%/& quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0/' || true
  fi
done
# the plymouth hook has to be in the initramfs, after udev (and after kms when it is there)
MKCONF=""
for f in "$PROFILE/airootfs/etc/mkinitcpio.conf.d/archiso.conf" "$PROFILE/airootfs/etc/mkinitcpio.conf"; do
  if [[ -f "$f" ]] && grep -q '^HOOKS=' "$f"; then MKCONF="$f"; break; fi
done
if [[ -n "$MKCONF" ]]; then
  if ! grep '^HOOKS=' "$MKCONF" | grep -qw plymouth; then
    if grep '^HOOKS=' "$MKCONF" | grep -qw kms; then
      sed -i -E '/^HOOKS=/ s/\bkms\b/kms plymouth/' "$MKCONF"
    else
      sed -i -E '/^HOOKS=/ s/\budev\b/udev plymouth/' "$MKCONF"
    fi
  fi
  grep '^HOOKS=' "$MKCONF" | grep -qw plymouth || echo "    (warning: could not add the plymouth hook to $MKCONF - the boot logo will not show)"
else
  echo "    (warning: no mkinitcpio HOOKS line found in the archiso profile - the boot logo will not show)"
fi

echo "==> Enabling the 32-bit (multilib) repository for Wine and games"
sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' "$PROFILE/pacman.conf"
if ! grep -q '^\[multilib\]' "$PROFILE/pacman.conf"; then
  printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> "$PROFILE/pacman.conf"
fi

echo "==> Choosing packages"
PKGFILE="$PROFILE/packages.x86_64"
if [[ -n "$(tail -c1 "$PKGFILE")" ]]; then echo >> "$PKGFILE"; fi
{
  echo "# --- MAS OS packages ---"
  grep -vE '^\s*(#|$)' "$HERE/packages.txt"
} >> "$PKGFILE"
HAVE_WAYDROID=0
while read -r pkg; do
  if pacman -Si "$pkg" >/dev/null 2>&1; then
    echo "$pkg" >> "$PKGFILE"
    if [[ "$pkg" == "waydroid" ]]; then HAVE_WAYDROID=1; fi
  else
    echo "    (optional package not found, skipping: $pkg)"
  fi
done < <(grep -vE '^\s*(#|$)' "$HERE/optional.txt")
sort -u -o "$PKGFILE.sorted" <(grep -vE '^\s*(#|$)' "$PKGFILE") && mv "$PKGFILE.sorted" "$PKGFILE"

echo "==> Adding the MAS layer (branding, launchers, firewall, shield)"
AIR="$PROFILE/airootfs"
cp -a "$HERE/overlay/." "$AIR/"
cp -a "$HERE/live/." "$AIR/"
# Copy used later by the installer (mas-install / mas-apply)
mkdir -p "$AIR/usr/share/mas-layer"
cp -a "$HERE/overlay" "$AIR/usr/share/mas-layer/overlay"
cp "$HERE/packages.txt" "$HERE/optional.txt" "$AIR/usr/share/mas-layer/"

# Makes the "Add a password or not?" screen (mas-welcome) appear in the live session
mkdir -p "$AIR/var/lib/mas"
: > "$AIR/var/lib/mas/firstrun-pending"
# The live account "mas" has no password and is never asked for an administrator password
: > "$AIR/var/lib/mas/default-open"

echo "==> Creating the live user 'mas'"
ensure_line() { # file, key, line  (adds the line if no line starts with "key:")
  touch "$1"
  grep -q "^$2:" "$1" || printf '%s\n' "$3" >> "$1"
}
ensure_line "$AIR/etc/passwd"  root 'root:x:0:0:root:/root:/usr/bin/bash'
ensure_line "$AIR/etc/shadow"  root 'root::14871::::::'
ensure_line "$AIR/etc/group"   root 'root:x:0:root'
ensure_line "$AIR/etc/gshadow" root 'root:!*::root'
ensure_line "$AIR/etc/passwd"  mas  'mas:x:1000:1000:MAS:/home/mas:/bin/bash'
ensure_line "$AIR/etc/shadow"  mas  'mas::14871::::::'
ensure_line "$AIR/etc/group"   mas  'mas:x:1000:'
ensure_line "$AIR/etc/gshadow" mas  'mas:!*::'

echo "==> Turning on services"
SYS="$AIR/etc/systemd/system"
mkdir -p "$SYS/multi-user.target.wants"
# MAS uses NetworkManager, so remove the network services the base ISO enables
find "$SYS" \( -name 'systemd-networkd*' -o -name 'dbus-org.freedesktop.network1.service' -o -name 'iwd.service' \) -delete 2>/dev/null || true
ln -sf /usr/lib/systemd/system/graphical.target       "$SYS/default.target"
ln -sf /usr/lib/systemd/system/sddm.service           "$SYS/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$SYS/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/nftables.service       "$SYS/multi-user.target.wants/nftables.service"
# picks safe drawing inside virtual machines (fixes the black screen) - the unit file comes from overlay/
ln -sf /etc/systemd/system/mas-gfx.service            "$SYS/multi-user.target.wants/mas-gfx.service"
# live only: asks at boot which graphics mode to use (the unit skips itself on an installed system)
ln -sf /etc/systemd/system/mas-gfx-ask.service        "$SYS/multi-user.target.wants/mas-gfx-ask.service"
# the boot logo goes away when the system is up (the units come with the plymouth package)
ln -sf /usr/lib/systemd/system/plymouth-quit.service  "$SYS/multi-user.target.wants/plymouth-quit.service"
# remembers which accounts have no password, so the login screen can show "Sign In" instead of a password box
ln -sf /etc/systemd/system/mas-loginstate.service     "$SYS/multi-user.target.wants/mas-loginstate.service"
ln -sf /etc/systemd/system/mas-loginstate.path        "$SYS/multi-user.target.wants/mas-loginstate.path"
if [[ $HAVE_WAYDROID -eq 1 ]]; then
  ln -sf /usr/lib/systemd/system/waydroid-container.service "$SYS/multi-user.target.wants/waydroid-container.service"
fi

echo "==> File permissions"
PERMS="$WORK/perms.txt"
{
  echo '  ["/etc/sudoers.d/mas-live"]="0:0:0440"'
  echo '  ["/etc/sudoers.d/mas-welcome"]="0:0:0440"'
  echo '  ["/etc/sudoers.d/10-mas-wheel"]="0:0:0440"'
  echo '  ["/home/mas"]="1000:1000:0750"'
  echo '  ["/home/mas/.config"]="1000:1000:0755"'
  echo '  ["/home/mas/.config/kscreenlockerrc"]="1000:1000:0644"'
  echo '  ["/home/mas/Desktop"]="1000:1000:0755"'
  echo '  ["/home/mas/Desktop/install-mas.desktop"]="1000:1000:0755"'
  for f in "$HERE"/overlay/usr/local/bin/*; do
    echo "  [\"/usr/local/bin/$(basename "$f")\"]=\"0:0:0755\""
  done
} > "$PERMS"
sed -i '/^file_permissions=(/r '"$PERMS" "$PROFILE/profiledef.sh"

echo "==> Building the ISO (this takes a while)"
mkarchiso -v -w "$WORK/tmp" -o "$OUT" "$PROFILE"

( cd "$OUT" && sha256sum mas-*.iso > SHA256SUMS )
echo
echo "Done. Your ISO:"
ls -lh "$OUT"/mas-*.iso
