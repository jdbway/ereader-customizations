# Kobo setup

First real device: `kobo-sabrina`, on the tailnet, dropbear (KOReader's
SSH.koplugin) on port 2222 at `192.168.5.93`. Layout mirrors `kindle/`
where it makes sense, adjusted for what's actually different on Kobo —
see below.

- KOReader lives at `/mnt/onboard/.adds/koreader/`. Root's home directory
  here is `/`, not `/root` — `~/.ssh/authorized_keys` resolves to
  `/.ssh/authorized_keys`, which is a red herring: it exists but nothing
  reads it. KOReader's own dropbear (the SSH.koplugin server on 2222) is
  launched with cwd `/mnt/onboard/.adds/koreader` and resolves its
  authorized_keys relative to that — the real file is
  `/mnt/onboard/.adds/koreader/settings/SSH/authorized_keys`.
- **Confirmed**: running Tailscale in real kernel TUN mode
  (`--tun=tailscale0`, `/dev/net/tun` present), not the userspace/SOCKS5
  fallback. Resolves the open question below.
- **Still open**: why MagicDNS apparently needs no watcher script here,
  unlike the Kindle's `dns_watch.sh`. Not yet investigated on this device.
- Tailscale layout differs from Kindle: everything lives under
  `/mnt/onboard/.adds/tailscale/`, boot-launched via
  `bin/start_tailscale_boot.sh` (`start on` a udev/init hook, not upstart —
  Kobo has no upstart). Unlike Kindle there was originally no separate
  stop/update tooling — just the one boot script. `tailscale`/`tailscaled`
  are always invoked with a fixed `--socket=/tmp/tailscaled.sock`; any
  script or plugin action against this daemon has to pass the same flag or
  it can't find it.
- **Incident (2026-08-20 → 2026-08-26)**: `tailscaled` received `SIGTERM`
  and shut down cleanly on 2026-08-20 13:34:36, and nothing brought it back
  since — the boot script only runs at device boot (last boot: 2026-08-12),
  and there's no supervisor to restart a daemon that dies mid-session.
  Restarted manually via SSH on 2026-08-26. Root cause of the `SIGTERM`
  itself wasn't identified.
- Added `koreader-plugins/networkextras.koplugin/` here — the same idea as
  the Kindle's plugin (Start/Stop/Update Tailscale from KOReader's Tools
  menu) but **without** the Framework Mode submenu, since that's a
  Kindle-specific concept (Amazon framework on/off) with no Kobo
  equivalent — KOReader manages Wi-Fi directly here.
- Added `tailscale/start_tailscale.sh`, `stop_tailscale.sh`,
  `stop_tailscaled.sh`, `update_tailscale.sh` (paths:
  `/mnt/onboard/.adds/tailscale/bin/` on-device) to fill the gap noted
  above — ported from the Kindle's equivalents, minus `eips` screen-logging
  (Kindle-only utility) and pointed at the fixed socket path and Kobo's
  binary layout. `update_tailscale.sh` uses `ARCH=arm`, same as Kindle.
- Device Wi-Fi is aggressively flaky from the outside: it drops to where
  pings/SSH time out, sometimes even while the device itself reports an
  active connection and is being used for something else (e.g. browsing
  the Calibre OPDS catalog). Cause not confirmed — ARP resolution to the
  device's real MAC stays correct throughout, so it's not a local ARP/IP
  conflict; more likely Wi-Fi mesh roaming or AP-side power-save handling.
  Worth remembering when scripting against this device: batch multi-step
  SSH work into a single connection (one `sh -s < script.sh` invocation)
  rather than several round-trips, since a mid-sequence connection can
  drop at any point.
- `cwasync.koplugin` (see `../kindle/README.md`) should work here too with
  no Kobo-specific changes — it already ships a `kobo_sqlite_provider.lua`
  for bridging highlights into stock Nickel, though that's unrelated to
  progress sync itself, which is fully cross-platform.
- `crossbill.koplugin` also installed here, pointed at the same shared
  `https://crossbill.truepob.com` instance as the Kindle — see
  `../kindle/koreader-settings/crossbill-NOTE.md` for the config-key
  details (same `settings.reader.lua` / `crossbill_sync` mechanism on
  every device).

Planning notes still open:

- Leaning toward Kobo over buying more Kindles for the nephew e-reader fleet:
  KOReader manages Wi-Fi directly on Kobo (a real network picker, not the
  toggle-only, framework-dependent mess on Kindle), and `advboot`/KSM gives a
  boot-time Nickel-vs-KOReader picker with an autoselect timeout — a lower-risk
  equivalent to the Kindle's Framework Mode reboot toggle, without needing to
  touch upstart/boot files the way Kindle autostart does.
