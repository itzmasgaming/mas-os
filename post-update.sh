#!/bin/bash
# runs as root after the files of an update are in place
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable mas-keyblink.service >/dev/null 2>&1 || true
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
# accounts that already exist: use the busy pointer / new Files app in their desktop icons and taskbar buttons
for h in /home/*; do
  for f in "$h"/Desktop/*.desktop "$h"/.config/xfce4/panel/launcher-*/*.desktop; do
    [ -f "$f" ] || continue
    sed -i -E 's#^Exec=thunar$#Exec=/usr/local/bin/mas-files#; s#^Exec=mas-files$#Exec=/usr/local/bin/mas-files#; /mas-launch/! s#^Exec=(/usr/local/bin/mas-(brave|files|restore|sandbox|ubuntu))#Exec=/usr/local/bin/mas-launch \1#' "$f" 2>/dev/null || true
  done
done
exit 0
