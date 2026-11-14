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
# a fresh container has no package signing keys set up yet
pacman-key --init >/dev/null 2>&1 || true
pacman-key --populate archlinux >/dev/null 2>&1 || true

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
    grep -rlI "Arch Linux" "$PROFILE/$d" 2>/dev/null | xargs -r sed -i 's/Arch Linux/MAS OS/g' || true
  fi
done
if [[ -f "$HERE/assets/splash.png" && -f "$PROFILE/syslinux/splash.png" ]]; then
  cp "$HERE/assets/splash.png" "$PROFILE/syslinux/splash.png"
fi

echo "==> Boot menu: more RAM space for downloads, plus black-screen recovery entries"
for d in syslinux grub efiboot; do
  [[ -d "$PROFILE/$d" ]] || continue
  grep -rlI 'archisosearchuuid=%ARCHISO_UUID%' "$PROFILE/$d" 2>/dev/null \
    | xargs -r sed -i 's/archisosearchuuid=%ARCHISO_UUID%/& cow_spacesize=2G/' || true
done
ENTRY_SRC="$PROFILE/efiboot/loader/entries/01-archiso-linux.conf"
if [[ -f "$ENTRY_SRC" ]]; then
  add_efi_entry() { # file sortkey title extra-options
    sed -e "s|^title .*|title    $3|" -e "s|^sort-key .*|sort-key $2|" -e "s|^options .*|& $4|" \
      "$ENTRY_SRC" > "$PROFILE/efiboot/loader/entries/$1"
  }
  add_efi_entry 01b-mas-x11.conf   01b "MAS OS - safe graphics: X11 (try this if the screen is black)" "mas.gfx=x11"
  add_efi_entry 01c-mas-soft.conf  01c "MAS OS - safe graphics: Wayland, CPU drawing" "mas.gfx=soft"
  add_efi_entry 01d-mas-basic.conf 01d "MAS OS - safe graphics: Wayland, basic CPU drawing (slowest)" "mas.gfx=basic"
  add_efi_entry 01e-mas-text.conf  01e "MAS OS - text mode only (for mas-debug)" "systemd.unit=multi-user.target"
fi
SYS_CFG="$PROFILE/syslinux/archiso_sys-linux.cfg"
if [[ -f "$SYS_CFG" ]]; then
  add_sys_entry() { # label title extra-options
    cat >> "$SYS_CFG" <<SYSEOF

LABEL $1
MENU LABEL $2
LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% cow_spacesize=2G $3 %KERNEL_PARAMS%
SYSEOF
  }
  add_sys_entry mas_x11   "MAS OS - safe graphics: X11 (BIOS)"                 "mas.gfx=x11"
  add_sys_entry mas_soft  "MAS OS - safe graphics: Wayland, CPU drawing (BIOS)" "mas.gfx=soft"
  add_sys_entry mas_basic "MAS OS - safe graphics: Wayland, basic (BIOS)"       "mas.gfx=basic"
  add_sys_entry mas_text  "MAS OS - text mode only (BIOS)"                      "systemd.unit=multi-user.target"
fi
GRUB_CFG="$PROFILE/grub/grub.cfg"
if [[ -f "$GRUB_CFG" ]]; then
  GRUB_BLK="$WORK/grub-extra.cfg"
  : > "$GRUB_BLK"
  add_grub_entry() { # id title extra-options
    cat >> "$GRUB_BLK" <<GRUBEOF
menuentry "$2 (\${archiso_platform})" --id '$1' {
    set gfxpayload=keep
    linux /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% cow_spacesize=2G $3 %KERNEL_PARAMS%
    initrd /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
}

GRUBEOF
  }
  add_grub_entry mas-x11   "MAS OS - safe graphics: X11"                  "mas.gfx=x11"
  add_grub_entry mas-soft  "MAS OS - safe graphics: Wayland, CPU drawing" "mas.gfx=soft"
  add_grub_entry mas-basic "MAS OS - safe graphics: Wayland, basic"       "mas.gfx=basic"
  add_grub_entry mas-text  "MAS OS - text mode only"                      "systemd.unit=multi-user.target"
  awk 'FNR==NR{blk=blk $0 "\n"; next} /^menuentry /{n++; if(n==2) printf "%s", blk} {print}' "$GRUB_BLK" "$GRUB_CFG" > "$GRUB_CFG.new"
  if grep -q "mas-x11" "$GRUB_CFG.new"; then mv "$GRUB_CFG.new" "$GRUB_CFG"; else rm -f "$GRUB_CFG.new"; cat "$GRUB_BLK" >> "$GRUB_CFG"; fi
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
cp "$HERE/packages.txt" "$HERE/optional.txt" "$HERE/installed.txt" "$AIR/usr/share/mas-layer/"
# Windows line endings would break the scripts ("bad interpreter"): strip them from every text file
grep -rlI $'\r' "$AIR" 2>/dev/null | xargs -r sed -i 's/\r$//' || true

echo "==> Creating the live user 'mas'"
ensure_line() { # file, key, line  (adds the line if no line starts with "key:")
  touch "$1"
  grep -q "^$2:" "$1" || printf '%s\n' "$3" >> "$1"
}
ensure_line "$AIR/etc/passwd"  root 'root:x:0:0:root:/root:/usr/bin/bash'
ensure_line "$AIR/etc/shadow"  root 'root::14871::::::'
ensure_line "$AIR/etc/passwd"  mas  'mas:x:1000:1000:MAS:/home/mas:/bin/bash'
ensure_line "$AIR/etc/shadow"  mas  'mas::14871::::::'
# Group entries are created at boot by systemd-sysusers (so the system groups from the base are kept)
mkdir -p "$AIR/etc/sysusers.d"
cat > "$AIR/etc/sysusers.d/mas-live.conf" <<'SYSUSERS'
g mas 1000
m mas wheel
m mas video
m mas audio
m mas input
m mas render
SYSUSERS

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
# live only: if the desktop does not come up in a VM, try a safer mode automatically
ln -sf /etc/systemd/system/mas-gfx-watch.service      "$SYS/multi-user.target.wants/mas-gfx-watch.service"
if [[ $HAVE_WAYDROID -eq 1 ]]; then
  ln -sf /usr/lib/systemd/system/waydroid-container.service "$SYS/multi-user.target.wants/waydroid-container.service"
fi

echo "==> File permissions"
PERMS="$WORK/perms.txt"
{
  echo '  ["/etc/sudoers.d/mas-live"]="0:0:0440"'
  echo '  ["/home/mas"]="1000:1000:0750"'
  echo '  ["/home/mas/Desktop"]="1000:1000:0755"'
  echo '  ["/home/mas/Desktop/install-mas.desktop"]="1000:1000:0755"'
  for f in "$HERE"/overlay/usr/local/bin/*; do
    [[ -f "$f" ]] || continue
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
