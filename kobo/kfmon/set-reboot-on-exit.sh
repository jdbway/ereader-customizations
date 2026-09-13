#!/bin/sh
# Make KOReader's Exit return to Nickel instead of rebooting the device.
#
# Why: KFMon's koreader.ini ships with `;reboot_on_exit=false` commented out,
# so koreader.sh's grep fails and it runs `/sbin/reboot` on exit -- the older
# OCP-bundle default. Uncommenting the line makes exit restart Nickel
# (`./nickel.sh &`) instead, which is what KFMon >= 0.9.5 defaults to.
# Observed on kobo-sabrina (Clara BW): every KOReader exit did a full reboot
# until this was set.
#
# Idempotent. Run as root on the device.
set -e

INI=/mnt/onboard/.adds/kfmon/config/koreader.ini
[ -f "$INI" ] || { echo "set-reboot-on-exit: $INI not found" >&2; exit 1; }

if grep -q '^reboot_on_exit=false' "$INI"; then
    echo "already set: reboot_on_exit=false"
else
    cp -a "$INI" "$INI.bak.$(date +%Y%m%d%H%M%S)"
    sed 's|^;reboot_on_exit=false|reboot_on_exit=false|' "$INI" > "$INI.new"
    mv "$INI.new" "$INI"
    echo "set: reboot_on_exit=false"
fi
grep -n reboot_on_exit "$INI"
