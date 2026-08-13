# Kindle setup

Kindle Paperwhite 5, jailbroken, running KOReader + Tailscale + a self-hosted
Calibre-Web NextGen library. Goal: reach the OPDS catalog and sync progress
over the tailnet from anywhere, with the Amazon framework disabled most of
the time to save power.

## Layout

- `koreader-plugins/networkextras.koplugin/` — **ours.** Adds a "Network
  Extras" entry to KOReader's main menu with:
  - **Framework Mode**: reboot with the Amazon framework enabled (needed to
    switch Wi-Fi networks — see below) or reboot back to low-power
    frameworkless mode.
  - **Start/Stop Tailscale**: manual control without leaving KOReader.

  Wi-Fi network switching used to be a menu item here too, but KOReader's own
  network picker calls into Amazon's framework layer, which is a no-op with
  the framework disabled, and driving `wpa_supplicant` directly proved
  unreliable against `wifid`'s own reconnect logic. Rebooting into framework
  mode to switch networks turned out to be the only deterministic path, so
  the unreliable in-KOReader picker was removed entirely.

- `koreader-plugins/suspendhack.koplugin/` — **third-party**, see its
  `SOURCE.md`. Required for normal suspend/resume while frameworkless.

- `tailscale/dns_watch.sh`, `tailscale/start_tailscale.sh` — **ours.** The
  Kindle's own `wifid` overwrites `/etc/resolv.conf` with DHCP-provided
  nameservers on every Wi-Fi reconnect (which happens often — Kindles sleep
  Wi-Fi aggressively), fighting Tailscale's MagicDNS (`CorpDNS`). `wifid` is
  a closed Amazon binary, so instead of hooking its write point, `dns_watch.sh`
  is a small loop that re-asserts `nameserver 100.100.100.100` every 10s.
  It's launched from `start_tailscale.sh` (which already runs at boot via the
  existing `/etc/upstart/tailscale.conf` job) — no read-only-filesystem edits
  needed. Verified to survive a real reboot and self-heal a forced overwrite.

## Not included here (third-party, installed but not vendored)

These are separately-maintained plugins installed on the device. Not
republished here — check their own repos/licenses if reproducing this setup:

- [`bookshelf.koplugin`](https://github.com/AndyHazz/bookshelf.koplugin) —
  home-screen replacement (the active one on this device).
- [`bookends.koplugin`](https://github.com/AndyHazz/bookends.koplugin)
- [`simpleui.koplugin`](https://github.com/doctorhetfield-cmd/simpleui.koplugin)
  — an earlier home-screen replacement, no longer the default, but still
  installed: it contributes a standalone persistent toolbar widget
  (Wi-Fi/brightness/power toggles) independent of its home-screen role.
  Confirmed by direct testing that deleting it breaks that widget AND
  `suspendhack.koplugin`'s FileManager widget registration, even though
  neither has a visible code-level dependency on it — keep it installed.
- `cwasync.koplugin` — **not third-party in the usual sense**: vendored
  directly from KOReader's own mainline repo
  (https://github.com/koreader/koreader/tree/master/plugins/cwasync.koplugin),
  not a separate author's project. Handles progress sync *and* two-way
  highlights/annotations sync with Calibre-Web NextGen (`sync_logic.lua`
  has a real last-write-wins merge engine, not just percentage push). Note:
  annotation sync is opt-in and manual — check "Sync KOReader highlights" in
  its menu, then tap "Sync highlights now" each time; it does not currently
  hook into automatic/periodic sync.

## Tailscale binary itself — deliberately not vendored

`/mnt/us/extensions/tailscale/bin/{tailscale,tailscaled}` are Tailscale's own
official prebuilt binaries, not something authored here. Currently version
**1.102.2**, architecture **armv7l** (32-bit ARM, matches Kindle Paperwhite
5's CPU). ~67MB combined — deliberately not committed to this repo (binary
blobs bloat every future clone permanently, and it's trivially re-obtained).

To reproduce: download the matching static build from Tailscale's own
release archive (`https://pkgs.tailscale.com/stable/`, `linux_arm` variant)
at the version above, or newer, and place `tailscale`/`tailscaled` at that
path. `start_tailscale.sh` and `dns_watch.sh` in this repo assume that exact
path (`/mnt/us/extensions/tailscale/bin/`).

## Secrets — deliberately excluded, do not add these

`auth.key` (Tailscale auth key), `ssh_host_*_key` (dropbear host keys), and
`tailscaled.state` (contains the node's private key) all live under
`/mnt/us/extensions/tailscale/bin/` on the device and must never be committed
here.

## SSH access

- Port 2222: KOReader's own dropbear SSH plugin, pubkey-only, `-o
  IdentitiesOnly=yes` required when multiple keys are offered.
- Port 22: Tailscale SSH (`tailscale set --ssh=true/false`), tailnet-only —
  confirmed unreachable over plain LAN. Left enabled by choice, since access
  is already gated behind Tailscale's own identity auth.
