# Boot hooks

Backed up here for reference/recovery. Both are **upstart job files that
live on the read-only root filesystem** (`/etc/init/`, `/etc/upstart/`) —
they cannot be deployed by just copying them back with the device running
normally. Reproducing either requires:

```sh
mntroot rw
cp <file> /etc/init/   # or /etc/upstart/, matching the original location
mntroot ro
reboot
```

Do this carefully — a bad upstart job can affect boot. Both of these are
known-working, already-live copies pulled directly off the device, not
hand-written from scratch.

## `kor.conf` — KOReader autolaunch on boot

Lives at `/etc/init/kor.conf`. Installed via a **third-party** KUAL
extension, not something we wrote:
[`Kindle-KOReader-On-Boot`](https://github.com/meepcat55/Kindle-KOReader-On-Boot)
(installed at `/mnt/us/extensions/Kindle-KOReader-On-Boot-main/` — its own
`bin/install.sh` is what does the `mntroot rw` + write + `mntroot ro` +
reboot dance; there's a matching `bin/remove.sh` / KUAL menu item to undo it).

What it does: waits for `lab126_gui` (the Amazon framework's GUI service) to
start, sleeps 85s to let the splash screen and framework UI fully finish
loading, then execs `koreader.sh --kual`. It does **not** kill/replace the
stock Kindle UI — KOReader launches on top of it after the delay.

Note this is a different mechanism than `networkextras.koplugin`'s
"Framework Mode" (the `DONT_START_FRAMEWORK` flag toggle) — that controls
whether the Amazon framework boots *at all*; this hook controls whether
KOReader auto-launches *given* the framework is running. In frameworkless
boots, `lab126_gui` likely never starts, so this specific hook wouldn't fire
— frameworkless boots must reach KOReader some other way (not yet
investigated/documented here).

## `tailscale.conf` — Tailscale + DNS watcher on boot

Lives at `/etc/upstart/tailscale.conf`. **Pre-existing when we started
working on this device** (file dated 4 days before any Claude Code session
on this host — origin/install process not documented anywhere we could
find; see the main repo history if this ever gets figured out).

What it does: waits for `lab126` to start, then launches Tailscale in TUN
mode via `start_tailscaled_tun.sh`, then `start_tailscale.sh` (which is
**ours**, modified — see `../tailscale/start_tailscale.sh` — to also launch
`dns_watch.sh`, the self-healing MagicDNS watcher).
