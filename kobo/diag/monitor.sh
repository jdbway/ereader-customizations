#!/bin/sh
# Lightweight on-device health logger for the MediaTek (kobov5) fault the
# Clara BW shows in Nickel: btservice burning CPU, duplicate wmt_launcher
# processes wedged on WMT_open, and Wi-Fi dropping while wpa_state=COMPLETED.
#
# Writes to real storage (/mnt/onboard) so it survives dmesg wrapping,
# KOReader sessions and (until it does) reboots. It does NOT auto-start after
# a reboot -- relaunch manually, or call it from a boot hook.
#
# Columns: bts = btservice utime+stime ticks (100Hz; delta => CPU%),
#          launchers = live wmt_launcher count, wmt = cumulative WMT_open -EIO
#          count in dmesg, load1, wpa = wpa_state, ip = wlan0 IPv4,
#          dstate = D-state tasks with their wchan.
LOG=/mnt/onboard/diag/monitor.log
mkdir -p /mnt/onboard/diag

while true; do
    ts=$(date '+%H:%M:%S')
    pid=$(pgrep -f '/usr/bin/btservice' | head -1)
    if [ -n "$pid" ]; then
        set -- $(awk '{print $14,$15}' /proc/$pid/stat)
        t=$(( $1 + $2 ))
    else
        t=-1
    fi
    la=$(ps -e | grep -c '[w]mt_launcher')
    wmt=$(dmesg | grep -c 'WMT_open.*-EIO')
    l=$(cut -d' ' -f1 /proc/loadavg)
    st=$(wpa_cli -i wlan0 status 2>/dev/null | sed -n 's/^wpa_state=//p')
    ip=$(ip -4 addr show wlan0 2>/dev/null | grep -oE 'inet [0-9.]+' | cut -d' ' -f2)
    ds=""
    for p in /proc/[0-9]*; do
        s=$(awk '{print $3}' $p/stat 2>/dev/null)
        [ "$s" = D ] && ds="$ds $(cat $p/comm 2>/dev/null)/$(cat $p/wchan 2>/dev/null)"
    done
    echo "$ts bts=$t launchers=$la wmt=$wmt load1=$l wpa=$st ip=${ip:-none} dstate:$ds" >> "$LOG"
    sleep 5
done
