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

## `tailscale-watchdog.conf` — Tailscale keepalive watchdog (**disabled 2026-08-27**)

Lives at `/etc/upstart/tailscale-watchdog.conf`, `respawn`-supervised, execs
`../tailscale/tailscale_watchdog.sh`. Predates this session (found already
present, older than its Aug 26 file mtime suggested — that was just a save,
not creation) but wasn't caught by the 2026-08-13 audit above, so it was
added sometime between the two.

What it does: an infinite loop, `pgrep`-checking every 300s whether
`tailscaled` is running and `tailscale status` reports connected; restarts
whichever piece is down via the same `start_tailscaled_tun.sh` /
`start_tailscale.sh` scripts the boot job uses. Cheap by design — each cycle
is a local process check, not network I/O — but the *effect* of restarting
is a full Tailscale reconnect (STUN probes to multiple DERP-adjacent hosts,
NAT-PMP/UPnP portmap attempts, a DERP/control HTTP(S) round-trip), easily
100+ packets in a few seconds.

**Disabled 2026-08-27** (config renamed to `tailscale-watchdog.conf.disabled`
on-device, process killed) after it was traced as the root cause of an
extended debugging session: every "Tailscale off" test that session kept
mysteriously showing Tailscale-shaped traffic a few minutes in, because this
watchdog was silently un-doing the manual stop within one 5-minute cycle.
Preference going forward is manual Tailscale control via
`networkextras.koplugin`'s Start/Stop menu items, not an always-reconnecting
background process. To re-enable: `mntroot rw`, rename the `.disabled` file
back to `tailscale-watchdog.conf`, `mntroot ro`, reboot (or just re-`exec`
the script directly for a non-persistent test).

## `tailscale.conf` and `phd.conf` - both disabled 2026-08-27

`tailscale.conf` (documented above, plain boot-autostart, not the watchdog)
and stock `/etc/upstart/phd.conf` (`/usr/sbin/phd`, Amazon's own "phone
home" device telemetry daemon - the upstart job's own top comment literally
says `# phone home`, and the binary contains strings like `PHONE_HOME` /
`PHONE_HOME_ACK`) were both renamed to `.disabled` at the user's explicit
request. Root-cause work (raw-socket packet capture via `../archive/wifi-debug-2026-08/
pktlog.lua`) found `phd` sending a UDP heartbeat to an Amazon IP roughly
every 27s, on its own enough to defeat KOReader's `auto_disable_wifi` noise
threshold - confirmed by stopping it and watching the watchdog actually fire
in KOReader's own debug log, cross-validated against `wifiwatch.sh`'s
independent interface-state polling. Same re-enable procedure as
`tailscale-watchdog.conf` above.

## `wifiwatch.conf` - ours, added 2026-08-27, disabled 2026-08-30

`respawn`-supervised, execs `wifiwatch.sh` (originally at
`../tailscale/wifiwatch.sh`, now `../archive/wifi-debug-2026-08/wifiwatch.sh`
— see below). Added so the
Wi-Fi-state/packet-capture monitoring set up for the `auto_disable_wifi`
investigation survives a reboot during multi-day passive monitoring, instead
of silently going dark until someone notices and manually relaunches it.

**Disabled 2026-08-30** (renamed to `wifiwatch.conf.disabled` on-device,
`wifiwatch.sh`/`pktlog.lua` killed, logs cleared). The investigation this
supported concluded when `phd.conf` was identified and disabled (above) —
this just never got turned off afterward, and sat running the packet
sniffer on every boot for three days with nothing left to investigate.
Moved to `../archive/wifi-debug-2026-08/` — no longer part of the live
boot-hooks set; see that directory's README before reviving it.
