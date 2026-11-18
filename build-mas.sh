#!/usr/bin/env bash
# build-mas.sh - builds the MAS OS ISO (Arch Linux base, XFCE desktop, Wine).
# Boot the ISO: the first-time setup starts by itself and installs MAS. There is no installer to open.
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
# VirtualBox: the full guest tools (clipboard, window resizing) replace the "-nox" ones from the base ISO
if pacman -Si virtualbox-guest-utils >/dev/null 2>&1; then
  sed -i '/^virtualbox-guest-utils-nox$/d' "$PKGFILE"
  echo "virtualbox-guest-utils" >> "$PKGFILE"
fi
HAVE_PLYMOUTH=0
while read -r pkg; do
  if pacman -Si "$pkg" >/dev/null 2>&1; then
    echo "$pkg" >> "$PKGFILE"
    if [[ "$pkg" == "plymouth" ]]; then HAVE_PLYMOUTH=1; fi
  else
    echo "    (optional package not found, skipping: $pkg)"
  fi
done < <(grep -vE '^\s*(#|$)' "$HERE/optional.txt")
sort -u -o "$PKGFILE.sorted" <(grep -vE '^\s*(#|$)' "$PKGFILE") && mv "$PKGFILE.sorted" "$PKGFILE"

echo "==> Adding the MAS layer (setup screen, installer, login screen, launchers, firewall, shield)"
AIR="$PROFILE/airootfs"
cp -a "$HERE/overlay/." "$AIR/"
cp -a "$HERE/live/." "$AIR/"
mkdir -p "$AIR/var/lib/mas" "$AIR/home/mas"
# The live account "mas" has no password and is never asked for an administrator password
: > "$AIR/var/lib/mas/default-open"
# The login screen reads this list to show a "Sign In" button for accounts without a password
echo mas > "$AIR/var/lib/mas/passwordless"
chmod 644 "$AIR/var/lib/mas/passwordless"

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
# The live account is an administrator (group wheel), like an installed "mas"
add_member() { # file group user  (adds the user to the 4th field of the group line)
  awk -F: -v OFS=: -v g="$2" -v u="$3" '$1==g { n=split($4,a,","); f=0; for(i=1;i<=n;i++) if(a[i]==u) f=1; if(!f) $4=($4==""?u:$4","u) } {print}' "$1" > "$1.new"
  cat "$1.new" > "$1"; rm -f "$1.new"
}
ensure_line "$AIR/etc/group"   wheel 'wheel:x:998:'
ensure_line "$AIR/etc/gshadow" wheel 'wheel:!*::'
add_member "$AIR/etc/group"   wheel mas
add_member "$AIR/etc/gshadow" wheel mas

echo "==> Removing remote-login leftovers of the base ISO (no open ports)"
find "$AIR/etc/systemd/system" -name 'sshd.service' -delete 2>/dev/null || true
rm -f "$AIR/etc/ssh/sshd_config.d/10-archiso.conf"

echo "==> Turning on services"
SYS="$AIR/etc/systemd/system"
mkdir -p "$SYS/multi-user.target.wants"
# MAS uses NetworkManager, so remove the network services the base ISO enables
find "$SYS" \( -name 'systemd-networkd*' -o -name 'dbus-org.freedesktop.network1.service' -o -name 'iwd.service' \) -delete 2>/dev/null || true
ln -sf /usr/lib/systemd/system/graphical.target       "$SYS/default.target"
ln -sf /usr/lib/systemd/system/sddm.service           "$SYS/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$SYS/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/nftables.service       "$SYS/multi-user.target.wants/nftables.service"
# live only: if MAS is already installed on a disk, start it instead of showing the setup again
ln -sf /etc/systemd/system/mas-live-boot.service      "$SYS/multi-user.target.wants/mas-live-boot.service"
# login screen safety net: falls back to the plain SDDM login if the MAS login theme is broken
ln -sf /etc/systemd/system/mas-theme-check.service    "$SYS/multi-user.target.wants/mas-theme-check.service"
ln -sf /etc/systemd/system/mas-theme-guard.service    "$SYS/multi-user.target.wants/mas-theme-guard.service"

if [[ $HAVE_PLYMOUTH -eq 1 ]]; then
  echo "==> Boot logo (Plymouth) instead of the [ OK ] text"
  MKCONF="$AIR/etc/mkinitcpio.conf.d/archiso.conf"
  if [[ -f "$MKCONF" ]] && ! grep -q plymouth "$MKCONF"; then
    sed -i '/^HOOKS=/ s/\budev\b/udev plymouth/' "$MKCONF"
  fi
  # "quiet splash" in the boot menus (BIOS syslinux, grub, UEFI systemd-boot)
  for f in "$PROFILE"/syslinux/*.cfg "$PROFILE"/grub/*.cfg "$PROFILE"/efiboot/loader/entries/*.conf; do
    if [[ -f "$f" ]] && grep -q 'archisobasedir=' "$f" && ! grep -q 'splash' "$f"; then
      sed -i 's/archisobasedir=/quiet splash loglevel=3 vt.global_cursor_default=0 rd.udev.log_level=3 systemd.show_status=false rd.systemd.show_status=false archisobasedir=/' "$f"
    fi
  done
fi

echo "==> File permissions"
PERMS="$WORK/perms.txt"
{
  echo '  ["/etc/sudoers.d/mas-live"]="0:0:0440"'
  echo '  ["/etc/sudoers.d/10-mas-wheel"]="0:0:0440"'
  echo '  ["/home/mas"]="1000:1000:0700"'
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
