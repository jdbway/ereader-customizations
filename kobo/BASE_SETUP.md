# Kobo base setup

This is the reference build for every Kobo in the fleet (currently
`kobo-sabrina`; template for the nephew Kobos too). Everything installable
as plain files lives under this `kobo/` folder; things distributed as
prebuilt binaries or third-party installers are documented here with their
source instead of vendored wholesale.

## Components

### Core jailbreak / launcher
- **KOReader** — not vendored (large prebuilt binary release, one per
  device architecture/firmware). Get the current Kobo build from
  [koreader.rocks](https://koreader.rocks/) or the
  [koreader/koreader releases](https://github.com/koreader/koreader/releases)
  page, extract to `/mnt/onboard/.adds/koreader/`.
- **NickelMenu** — not vendored (native binary + install package). Get from
  [pgaskin/NickelMenu](https://github.com/pgaskin/NickelMenu). This repo
  vendors only the config: `nickelmenu/koreader` → copy to
  `/mnt/onboard/.adds/nm/koreader` to add the "KOReader" entry to Nickel's
  menu that launches `koreader.sh`.

### KOReader plugins (`koreader-plugins/`, copy each to
`/mnt/onboard/.adds/koreader/plugins/`)
- **networkextras.koplugin** — this repo's own plugin (also used on
  Kindle). Manual Start/Stop/Update Tailscale + status from KOReader's
  Tools menu. Auto-detects Kindle vs. Kobo paths and control socket; see
  its `main.lua` comments. Tailscale is a **manual toggle by design** —
  no boot-time auto-connect, for battery reasons.
- **crossbill.koplugin** — syncs highlights to the shared Crossbill
  server (`https://crossbill.truepob.com`). Config lives in KOReader's
  own `settings.reader.lua` under the `crossbill_sync` key, not a vendored
  file — see `../kindle/koreader-settings/crossbill-NOTE.md` for the
  exact keys and current known issues.
- **cwasync.koplugin** — the "CWA / Calibre-Web-NextGen" progress-sync
  plugin (upstream: `new-usemame/cwasync.koplugin`). Point it at the
  Calibre-Web-Automated instance's `/kosync` endpoint per its own setup
  UI.
- **bookshelf.koplugin** — the home-screen replacement in use on the
  Kindle fleet; carries a Kobo-aware source module already
  (`lib/bookshelf_kobo_source.lua`).
- **bookends.koplugin** — cosmetic reading-progress/bookend styling.
- **simpleui.koplugin** — alternate home screen (kept installed but
  inactive if `bookshelf` is the active `start_with`, matching the
  Kindle setup — see `../kindle/README.md`). Has a couple of
  `Device:isKindle()` / `/mnt/us` references (`sui_topbar.lua`,
  `sui_updater.lua`) that weren't audited for Kobo correctness before
  vendoring — check those if this is made the *active* home screen here.
- **appstore.koplugin** — the KOReader App Store
  (`omer-faruq/appstore.koplugin`), for browsing/installing/updating
  community plugins from KOReader itself.

### KOReader settings (`koreader-settings/`, copy into
`/mnt/onboard/.adds/koreader/settings/`)
- **opds.lua** — OPDS catalog list, including the Calibre server
  (`https://calibre.truepob.com/opds`). **Password is intentionally
  blanked before committing** — fill in manually on-device after copying.

### Tailscale (`../kobo/tailscale/`, scripts go in
`/mnt/onboard/.adds/tailscale/bin/`)
- Binaries are **not vendored** — `update_tailscale.sh` downloads and
  installs the current release itself (works for first install too, not
  just updates — it detects "no binaries found" and installs fresh).
- Scripts here: `start_tailscale.sh`, `stop_tailscale.sh`,
  `stop_tailscaled.sh`, `update_tailscale.sh`. A `start_tailscaled_boot.sh`-
  style boot script and `up.args` (tailnet flags) still need to be created
  fresh per device — see `../kindle/tailscale/up.args` for the format.

### Still to add
The user has more plugins/components in mind not yet listed here — extend
this file and the `koreader-plugins/` folder as they're identified, don't
let this list go stale.

## Install order (rough)
1. NickelMenu (native install package).
2. KOReader (extract release zip to `.adds/koreader/`).
3. Copy `nickelmenu/koreader` config in, restart Nickel/reboot so the menu
   entry appears, launch KOReader once via NickelMenu.
4. Copy each `koreader-plugins/*.koplugin` folder into
   `.adds/koreader/plugins/`, restart KOReader.
5. Copy `koreader-settings/opds.lua` into `.adds/koreader/settings/`, fill
   in the Calibre password on-device.
6. Set up Tailscale: create `.adds/tailscale/bin/up.args`, run
   `update_tailscale.sh` to install the binaries, then use
   `networkextras.koplugin`'s Start Tailscale action from KOReader.
7. Configure Crossbill server URL/credentials via KOReader's own Tools →
   Crossbill → Settings menu (see the NOTE file referenced above for why
   this can't just be copied as a file).
8. Configure `cwasync.koplugin` against the Calibre-Web-Automated
   instance's `/kosync` endpoint via its own in-KOReader setup screen.

## Important: do not repeat the auto-start incident

An attempt was made (2026-08-28/29) to auto-launch KOReader at boot with a
tap-to-interrupt fallback to Nickel, by inserting a script call into
`/etc/init.d/rcS` right after Nickel's own launch line. It caused a
Nickel/KOReader framebuffer race (garbled, mostly-blank flashing screen)
serious enough that the device's own crash-loop watchdog triggered its
built-in recovery flow, which — with no way to decline partway through —
ran to completion as a **full factory reset**: all sideloaded content
(KOReader, every plugin, Tailscale, this whole setup) and Sabrina's
library/reading data on `/mnt/onboard` were wiped, requiring a from-scratch
device setup and this rebuild.

**Root cause understood afterward**: the hook only waited ~4 seconds after
Nickel started before killing it to hand off to KOReader — nowhere near
enough time for Nickel to finish its own boot rendering on this hardware,
unlike the several-seconds-plus of natural delay before a human manually
taps NickelMenu's entry.

If this is attempted again:
- **Take a real backup first** — not just a copy of the one file being
  edited (that's what was done last time, and it didn't help: the failure
  mode wasn't "wrong file content," it was runtime racing that a static
  file diff can't catch). A full `/mnt/onboard` + relevant system-partition
  backup, ideally to another machine, not just another path on-device.
- **Test on a spare/non-production device first**, never on the device a
  real person is actively using, if at all possible.
- Whatever the settle time and detection approach end up being, verify
  Nickel has actually finished its own startup (not just "N seconds have
  passed") before triggering `koreader.sh`.
- Recognize that this device's own recovery flow, once triggered, appears
  to run to a full factory reset with no way to abort or choose a lighter
  recovery partway through — so "worst case" for any boot-file change on
  this hardware is effectively "full wipe," not "stuck, but fixable via
  SSH."
