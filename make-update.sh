#!/usr/bin/env bash
# make-update.sh - makes an update for installed MAS systems.
#
#   ./make-update.sh 0.3.1 "What is new in this version" [reboot=yes|no] [system_upgrade=no|yes]
#
# It writes two files into ./dist/ :
#   mas-update-0.3.1.tar.gz   the changed files (taken from ./overlay)
#   updates.mas               the update list
# Then:
#   1. Make a release called v0.3.1 in the GitHub repo  itzmasgaming/mas-os-updates  and attach mas-update-0.3.1.tar.gz to it.
#   (new programs the update needs:  MAS_UPDATE_PACKAGES="python-xlib bubblewrap" ./make-update.sh ...)
#   2. Put updates.mas in the main branch of that repo (replace the old one).
# Every installed MAS finds it within 24 hours and updates itself.
set -euo pipefail
cd "$(dirname "$0")"
VER="${1:?usage: ./make-update.sh VERSION \"notes\" [reboot=yes|no] [system_upgrade=no|yes]}"
NOTES="${2:-}"
REBOOT="${3:-yes}"
SYSUP="${4:-no}"
REPO="${MAS_UPDATE_REPO:-itzmasgaming/mas-os-updates}"
[[ "$VER" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "VERSION must look like 0.3.1" >&2; exit 1; }

# only these places can be updated (the updater refuses anything else)
PATHS=(usr/local/bin usr/share/mas usr/share/themes usr/share/icons usr/share/applications usr/share/sddm/themes/mas
       usr/share/plymouth/themes/mas etc/skel etc/xdg etc/polkit-1/rules.d/49-mas-default-open.rules)
for f in etc/systemd/system/mas-*.service etc/systemd/system/mas-*.timer etc/sudoers.d/20-mas-*; do
  [[ -e overlay/$f ]] && PATHS+=("$f")
done
EXIST=(); for p in "${PATHS[@]}"; do [[ -e overlay/$p ]] && EXIST+=("$p"); done

mkdir -p dist
OUT="dist/mas-update-$VER.tar.gz"
EXTRA=()
if [[ -f post-update.sh ]]; then
  TMPX="$(mktemp -d)"; mkdir -p "$TMPX/.mas"; cp post-update.sh "$TMPX/.mas/post-update.sh"; chmod 755 "$TMPX/.mas/post-update.sh"; EXTRA=(-C "$TMPX" .mas/post-update.sh)
fi
tar --owner=0 --group=0 --numeric-owner -C overlay -czf "$OUT" "${EXIST[@]}" "${EXTRA[@]}"
SHA="$(sha256sum "$OUT" | cut -d' ' -f1)"
URL="https://github.com/$REPO/releases/download/v$VER/mas-update-$VER.tar.gz"
python3 - "$VER" "$NOTES" "$URL" "$SHA" "$REBOOT" "$SYSUP" "${MAS_UPDATE_PACKAGES:-}" > dist/updates.mas <<'PY'
import json, sys, time
ver, notes, url, sha, reboot, sysup, pk = sys.argv[1:8]
d = {"latest": ver, "released": time.strftime("%Y-%m-%d"), "notes": notes,
     "payload": {"url": url, "sha256": sha}, "reboot": reboot == "yes", "system_upgrade": sysup == "yes"}
if pk.strip(): d["packages"] = pk.split()      # new programs the update needs (installed with pacman)
print(json.dumps(d, indent=2))
PY
echo "Made:"; ls -lh "$OUT" dist/updates.mas
echo
echo "Next: attach $OUT to a GitHub release named v$VER in $REPO, then upload dist/updates.mas to the main branch."
