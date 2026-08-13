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
"Framework Mode" (the `DONT_START_FRAMEWORK` flag toggle), and — resolved by
tracing the actual upstart chain — **it fires in frameworkless boots too**,
not just framework-enabled ones. The two mechanisms don't actually interact:

- `/mnt/us/DONT_START_FRAMEWORK` is checked only by stock
  `/etc/upstart/framework.conf` (unmodified, Feb 11 stock timestamp — this
  flag check is genuine Amazon manufacturing/diagnostic functionality that
  jailbreaks repurpose, not a jailbreak patch to that file). When present, it
  cleanly `stop`s *that one job* — the actual CVM/Java app framework — before
  it renders anything.
- `lab126_gui` (what `kor.conf` actually waits on) is a separate upstart
  target defined in stock `/etc/upstart/lab126_gui.conf`, gated on
  `n_ready and langpicker_ready and ekart_ready` — pure boot-orchestration
  milestones, unrelated to whether the CVM framework process itself
  successfully starts.

So `kor.conf`'s `start on started lab126_gui` reaches "started" regardless of
`DONT_START_FRAMEWORK`, which is why KOReader autolaunch works in both modes.

## `kmc.conf` — found during a full boot-hook audit, not vendored

`/etc/init/kmc.conf` (dated Aug 9 01:15, an hour before the Tailscale
binaries first appear) is standard **MRPI/KUAL jailbreak bridge**
scaffolding, not something specific to this setup — its own comments say
*"This USED to be the bridge script"*. It fires on `framework_ready` and
checks for an `/mnt/us/emergency.sh` recovery script (not currently present)
as a jailbreak safety net. Foundational infrastructure from whatever
jailbreak tool was originally used on this device, not authored by us —
noted here for completeness, not vendored.

## Full audit (2026-08-13), nothing else found

Checked `/etc/upstart` (same directory as `/etc/init` — confirmed identical
listing, not two separate locations) in full: only `kor.conf`, `tailscale.conf`,
and `kmc.conf` are non-stock (every other file carries the Feb 11 stock
firmware timestamp). Also checked `/mnt/us/extensions/` (`MRInstaller` and
`koreader` are stock/unmodified jailbreak tooling — generic installer and
KOReader launcher respectively), `/mnt/us/mrpackages/` (empty), and confirmed
no `/mnt/us/emergency.sh` is in use. Nothing else custom exists at the
framework level beyond what's already documented in this repo.

## `tailscale.conf` — Tailscale + DNS watcher on boot

Lives at `/etc/upstart/tailscale.conf`. **Pre-existing when we started
working on this device** (file dated 4 days before any Claude Code session
on this host — origin/install process not documented anywhere we could
find; see the main repo history if this ever gets figured out).

What it does: waits for `lab126` to start, then launches Tailscale in TUN
mode via `start_tailscaled_tun.sh`, then `start_tailscale.sh` (which is
**ours**, modified — see `../tailscale/start_tailscale.sh` — to also launch
`dns_watch.sh`, the self-healing MagicDNS watcher).
