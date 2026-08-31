# Wi-Fi debug capture — retired 2026-08-30

`wifiwatch.sh` + `pktlog.lua`, with the `wifiwatch.conf` upstart job that
kept them alive across reboots. Added 2026-08-27 for a multi-day passive
investigation into `auto_disable_wifi` misbehaving — raw packet capture on
`wlan0` plus interface up/down logging, running continuously so nothing was
missed between check-ins. See `../../boot-hooks/README.md`'s `phd.conf`
section for the actual root cause this found (Amazon's `phd` telemetry
daemon heartbeating every ~27s, defeating KOReader's idle-Wi-Fi-off
watchdog) and the fix (disabling `phd.conf`).

That investigation is done and the fix shipped. This kept running anyway —
`wifiwatch.conf` was never disabled after the fix landed, so the sniffer sat
there burning CPU/battery/flash-I/O on every boot for no reason. Disabled
on-device 2026-08-30 (`/etc/upstart/wifiwatch.conf.disabled`, processes
killed, `pktlog.txt`/`wifiwatch.log` cleared) and moved here rather than
just deleted, in case a future Wi-Fi investigation needs the same approach
again.

A third piece of the same investigation turned up separately, after the
above cleanup, missed by the original boot-hooks documentation entirely: a
`* * * * *` crontab entry appended to `/etc/crontab/root` logging `wlan0`
TX packet counts every 5s. See `crontab-txwatch.txt` — removed the same day
for the same reason.

**Not part of the live install set.** Unlike `kindle/tailscale/` and
`kindle/boot-hooks/`, nothing here should be copied back onto the device by
a normal reinstall — reference only. If reviving this for a new
investigation, treat it as a fresh temporary debug session (remember to
disable it again when done, unlike last time).
