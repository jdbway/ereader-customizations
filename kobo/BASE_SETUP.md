# Kobo base setup

This is the reference build for every Kobo in the fleet (currently
`kobo-sabrina`; template for the nephew Kobos too). Everything installable
as plain files lives under this `kobo/` folder; things distributed as
prebuilt binaries or third-party installers are documented here with their
source instead of vendored wholesale.

## Components

### System utilities
- **curl** — the OCP package's base image ships BusyBox `wget` but no
  `curl` at all. Not strictly required (`update_tailscale.sh` uses `wget`
  specifically because of this — see its own comment), but handy to have
  for manual debugging/ad hoc use, so it's part of the base install
  regardless. Not vendored (static binary, third-party build) — install:
  ```sh
  wget -q -O /usr/bin/curl 'https://github.com/moparisthebest/static-curl/releases/latest/download/curl-armhf'
  chmod +x /usr/bin/curl
  mkdir -p /etc/ssl/certs
  wget -q -O /etc/ssl/certs/ca-certificates.crt 'https://curl.se/ca/cacert.pem'
  ```
  The CA bundle step matters: unlike this device's BusyBox `wget` (which
  skips certificate verification entirely — worth knowing as its own
  security caveat, not just a curl quirk), `curl` verifies TLS certs by
  default and fails (exit 77, "problem with the local SSL certificate")
  without a CA store, since the device has none at all otherwise. `armhf`
  is correct for Kobo's hard-float ARM userspace (confirmed working on
  2026-08-29; `moparisthebest/static-curl` doesn't publish a soft-float
  ARM build, so there's no alternative to try if this ever stops
  matching).

### Core jailbreak / launcher — bootstrapping a factory-fresh device
- **KOReader + KFMon + NickelMenu, bundled** — not vendored (large
  prebuilt binary release). On a factory-fresh device (nothing sideloaded
  yet — this is the actual from-scratch path used to rebuild
  `kobo-sabrina` on 2026-08-29), use the community "one-click package"
  rather than installing KOReader and NickelMenu separately:
  1. Download the current package from the first post of the
     [MobileRead KOReader-on-Kobo thread](https://www.mobileread.com/forums/showpost.php?p=3797095&postcount=1)
     — as of 2026-08-29 this is
     [OCP-KOReader-v2026.03.zip](https://storage.gra.cloud.ovh.net/v1/AUTH_2ac4bfee353948ec8ea7fd1710574097/kfmon-pub/OCP-KOReader-v2026.03.zip)
     (~41.6MB). **Check that forum post for a newer version before reusing
     this link** — the filename/version changes over time and the link
     above will go stale.
  2. Connect the Kobo via USB. **Extract the zip to a local folder on
     your computer first**, then copy the *contents* of that extracted
     folder (`.adds`, `.kobo`, `.kobo-images`, `fonts`, `kfmon.png`,
     `koreader.png`, etc.) directly into the root of the Kobo's drive —
     not the zip file itself, and not the extracted top-level folder
     as a single item. Extracting straight onto the device with
     "Extract Here" risks landing everything inside an extra
     zip-named subfolder depending on the archive tool; extracting
     locally first and verifying the file list before copying avoids
     that ambiguity. Confirmed working this way on 2026-08-29.
  3. Safely eject, then unplug. The device shows "processing a book,"
     then **restarts on its own** to apply it — let it run, don't
     interrupt.
  4. After it settles at the Nickel home screen, a **KOReader** tile
     appears on Home/Library (NickelMenu + the launcher entry are part of
     this same package — no separate NickelMenu install needed for this
     path).
  5. Tap **KOReader** once to launch it, then enable remote access:
     KOReader's own menu → gear icon → **Network** → toggle **SSH
     server** on (starts `dropbear` on port 2222 — this is what every
     `ssh root@<device-ip> -p 2222` command in this repo's notes connects
     to). Note the device's IP shown on that same screen.
  6. From here on, everything below (plugins, settings, Tailscale) can be
     deployed over that SSH connection instead of USB.
- For a device that **already has NickelMenu but not KOReader** (not the
  fresh-device case above), see
  [pgaskin/NickelMenu](https://github.com/pgaskin/NickelMenu) for the
  separate NickelMenu installer, and add the entry from
  `nickelmenu/koreader` in this folder (→
  `/mnt/onboard/.adds/nm/koreader`) once KOReader itself is installed
  from [koreader.rocks](https://koreader.rocks/) or the
  [koreader/koreader releases](https://github.com/koreader/koreader/releases)
  page.

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
- **wallabag.lua** — Wallabag article sync
  (`https://wallabag.truepob.com`, username `jon`). **Password
  intentionally blanked before committing** — fill in on-device.
  `client_id`/`client_secret` (this Wallabag instance's OAuth app
  credentials, not tied to one user) also need filling in on-device —
  get them from the Wallabag instance itself. Points at the
  `Books/Wallabag` library folder below.

### Home / library folder (create on `/mnt/onboard`, not under `.adds`)
Kobo's Nickel scans `/mnt/onboard` itself for content, unlike Kindle's
dedicated `koreader/epubs/books/` convention — so the library lives at
top level, not inside the koreader install:
- `/mnt/onboard/Books/` — general library root; point `bookshelf.koplugin`
  and KOReader's own file browser home directory here.
- `/mnt/onboard/Books/Wallabag/` — where `wallabag.koplugin` downloads
  synced articles (matches `wallabag.lua`'s `directory` above); has its
  own `archive/` subfolder created automatically by the plugin.
- Adjust the folder name if a different convention is wanted — `Books` is
  just a reasonable default, not something KOReader/Nickel requires.

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
1. Bootstrap via the one-click package (USB) per "Core jailbreak /
   launcher" above — gets KOReader + KFMon + NickelMenu on in one step on
   a factory-fresh device.
2. Launch KOReader once via its new Home/Library tile, enable its SSH
   server (Network settings menu), note the device IP. Everything from
   here on can go over that SSH connection instead of USB.
3. Install curl + CA bundle per "System utilities" above.
4. (Skip if using the one-click package above — only needed when adding
   KOReader to a device that already has NickelMenu some other way.)
   Copy `nickelmenu/koreader` config in, restart Nickel/reboot so the menu
   entry appears, launch KOReader once via NickelMenu.
5. Copy each `koreader-plugins/*.koplugin` folder into
   `.adds/koreader/plugins/`, restart KOReader.
6. Create `/mnt/onboard/Books/` and `/mnt/onboard/Books/Wallabag/` (see
   "Home / library folder" above), point KOReader's file browser and
   `bookshelf.koplugin` at `Books/`.
7. Copy `koreader-settings/opds.lua` and `wallabag.lua` into
   `.adds/koreader/settings/`, fill in the Calibre password and the
   Wallabag password/client_id/client_secret on-device.
8. Set up Tailscale: create `.adds/tailscale/bin/up.args`, run
   `update_tailscale.sh` to install the binaries, then use
   `networkextras.koplugin`'s Start Tailscale action from KOReader.
9. Configure Crossbill server URL/credentials via KOReader's own Tools →
   Crossbill → Settings menu (see the NOTE file referenced above for why
   this can't just be copied as a file).
10. Configure `cwasync.koplugin` against the Calibre-Web-Automated
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
