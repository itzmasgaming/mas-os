#!/bin/bash
# runs as root after the files of an update are in place
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable mas-keyblink.service >/dev/null 2>&1 || true
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
exit 0
