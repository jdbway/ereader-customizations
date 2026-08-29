# Kindle base setup

The reference build for the Kindle Paperwhite 5: KOReader + Tailscale + a
self-hosted Calibre-Web NextGen library, reached over the tailnet, with the
Amazon framework disabled most of the time to save power. Mirrors
`kobo/BASE_SETUP.md`'s structure so the two devices' setup is directly
comparable — read that file's intro for the general Components /
Install-order shape this follows.

This folder (plus `koreader-settings/` and `boot-hooks/`) should match
what's actually installed and configured on the physical device right now.
When the device changes, re-sync this folder from it — see `backup/`'s
`backup_koreader.sh` for pulling a raw snapshot to diff against.

## Components

### Jailbreak

Jailbroken via **[SpringBreak](https://kindlemodding.org/jailbreaking/SpringBreak/)**.
Everything below it sets up — the `DONT_START_FRAMEWORK` flag convention,
KUAL, `mntroot rw`/`ro`, the MRPI/KUAL bridge scaffolding (`kmc.conf`) — is
part of the broader Kindle jailbreak ecosystem, not specific to this repo.
Reproducing this on another Kindle: start there. Other jailbreak methods may
not use `/etc/upstart/framework.conf`'s stock `DONT_START_FRAMEWORK` check
the same way, so treat the boot-hook details here as SpringBreak-specific
until verified otherwise.

### KOReader plugins

KOReader ships **~35 plugins bundled by default** with any release — SSH,
statistics, kosync, opds, coverbrowser, autosuspend/autodim/autowarmth,
vocabbuilder, hello, profiles, exporter, terminal, texteditor, japanese,
qrclipboard, newsdownloader, movetoarchive, keepalive, hotkeys, gestures,
externalkeyboard, docsettingtweak, cloudstorage, batterystat,
archiveviewer, timesync, xray, readtimer, perceptionexpander,
httpinspector, systemstat, wallabag, calibre, bookshortcuts, and more.
**These need no separate install step or entry here** — they come with
KOReader itself. This section only tracks the custom/third-party layer on
top:

- `../shared/koreader-plugins/networkextras.koplugin/` — Manual
  Start/Stop/Update Tailscale, plus **Framework Mode** (reboot with the
  Amazon framework enabled — needed to switch Wi-Fi networks, since
  KOReader's own network picker calls into the framework layer and is a
  no-op with it disabled — or back to low-power frameworkless mode).
  Framework Mode is gated behind `Device:isKindle()` in the plugin's own
  code, so it's a no-op on Kobo, not a separate code path to maintain.
- `../shared/koreader-plugins/bookshelf.koplugin/` — the active home
  screen (**Start with → Bookshelf** in KOReader's file-manager menu).
  Installed via `git clone` on-device (for its in-app dev-branch update
  feature), so the nested `.git/` was stripped before committing here.
  See "Bookshelf home screen" below for chip bar / micromodule setup.
- `../shared/koreader-plugins/bookends.koplugin/` — overlay
  presets/styling; also supplies Bookshelf's richer font-preview and
  extra progress-bar styles when both are installed together.
- `../shared/koreader-plugins/simpleui.koplugin/` — an earlier home
  screen, no longer the default (Bookshelf is), but still installed: it
  contributes a standalone persistent toolbar widget (Wi-Fi/brightness/
  power toggles) independent of its home-screen role. Confirmed by direct
  testing that removing it breaks that widget AND `suspendhack.koplugin`'s
  FileManager widget registration, even though neither has a visible
  code-level dependency on it — keep it installed.
- `../shared/koreader-plugins/cwasync.koplugin/` — vendored from
  KOReader's own mainline repo, not a third-party author's project.
  Handles progress sync *and* two-way highlights/annotations sync with
  Calibre-Web NextGen (`sync_logic.lua` has a real last-write-wins merge
  engine, not just percentage push). Annotation sync is opt-in and
  manual — check "Sync KOReader highlights" in its menu, then tap "Sync
  highlights now" each time; it does not currently hook into
  automatic/periodic sync.
- `../shared/koreader-plugins/crossbill.koplugin/` — syncs highlights to
  a self-hosted [Crossbill](https://github.com/Crossbill-App/crossbill-web)
  instance for a real web UI. Menu only appears in Tools while a document
  is open. Config in `settings.reader.lua`, see
  `koreader-settings/crossbill-NOTE.md` — including a known upstream gap
  where highlight notes don't currently make it into Crossbill.
- `../shared/koreader-plugins/readinginsights.koplugin/` — powers the
  "Reading insights" popup (goal progress, achievements, calendar,
  records) and registers the Dispatcher actions behind it — required for
  the Bookshelf Reading streak micromodule's "Reading insight" tap
  option (see "Bookshelf home screen" below).
- `../shared/koreader-plugins/immichupload.koplugin/` — uploads new
  screenshots to a self-hosted [Immich](https://immich.app) instance.
  Checks the screenshots folder locally on a 30s timer (zero network
  cost) and only calls KOReader's own `NetworkMgr` Wi-Fi-on-demand flow
  once it finds something new — fully decoupled from Tailscale's
  lifecycle. Needs an Immich API key at
  `<koreader settings dir>/immich_api.key` (see Secrets below).
- `../shared/koreader-plugins/AnnotationSync.koplugin/`
  ([dani84bs/AnnotationSync.koplugin](https://github.com/dani84bs/AnnotationSync.koplugin)),
  vendored directly, unmodified (v2.0.0). Cross-device highlight/note/
  bookmark sync via WebDAV, smart last-write-wins merging, a trash bin
  for recovering accidental deletions. Config split across two files —
  see `koreader-settings/annotationsync-NOTE.md`. The WebDAV server
  itself (`rclone serve webdav`, `homelab-rclone` repo) is shared
  infrastructure, not per-device config. This is the practical fix for
  the stock KOReader → Joplin exporter being unfit for purpose (creates
  a new note per re-export instead of updating in place) — annotations
  land here first, then get pulled from the shared WebDAV store into
  whatever downstream tool needs them.
- `../shared/koreader-plugins/vocabdeck.koplugin/`
  ([yupmoon/vocabdeck.koplugin](https://github.com/yupmoon/vocabdeck.koplugin)),
  vendored with local customizations — bug fixes and behavior changes on
  top of upstream, see its own `CUSTOMIZATIONS.md`. Vocabulary
  deck/flashcard plugin with optional AI enrichment. **Its real
  `vocabdeck_apikeys.lua` and `vocabdeck_configuration.lua` are
  excluded** — see its own `README.md` for populating them from the
  committed `.sample` files.
- `koreader-plugins/suspendhack.koplugin/` — **Kindle-only by design**
  (self-disables via `Device:isKindle()` in its own code). Required for
  normal suspend/resume while frameworkless — see its `SOURCE.md`.
- `koreader-plugins/wifiwatchdogtune.koplugin/` — **Kindle-only by
  design**: patches constants directly inside KOReader's own
  `frontend/ui/network/networklistener.lua` at a hardcoded
  `/mnt/us/koreader/...` path (only makes sense bundled with the exact
  KOReader tree it's patching), and toggles Amazon's `phd` "phone home"
  telemetry daemon via `initctl` — both genuinely Kindle-specific
  concepts with no Kobo equivalent. Adds a "Wi-Fi Auto-off Tuning" menu
  for adjusting KOReader's idle-Wi-Fi-off watchdog timing and stopping
  `phd` (background telemetry traffic that can keep the watchdog from
  ever triggering).
- `assistant.koplugin` — **not vendored here, no local customizations.**
  AI Helper plugin (Claude/GPT/Gemini/DeepSeek/Ollama while reading).
  Installed straight from upstream,
  [omer-faruq/assistant.koplugin](https://github.com/omer-faruq/assistant.koplugin).

### Not yet audited/documented (found 2026-08-29, needs your input)

Four more third-party plugins are live and actively configured (their
gesture bindings are in `koreader-settings/gestures.lua`) but were never
documented anywhere in this repo — found while cross-referencing a fresh
device backup against this file:

- **`ReadMastery.koplugin`** — "Gamify your reading experience with XP,
  Levels, Streaks, and Achievements." Bound to `tap_left_bottom_corner`
  (`readmastery_show_stats`). Already confirmed unmodified-from-upstream
  in `koreader-settings/README.md`'s plugin-source audit, just never got
  its own bullet here.
- **`glimpse.koplugin`** — "Peek at maps, family trees and other
  reference images from anywhere in the book." Also bound to
  `tap_left_bottom_corner` (`glimpse_show`).
- **`homeassistant.koplugin`** — lets KOReader control Home Assistant
  entities via its REST API. Likely needs a URL + long-lived access
  token, same secret-handling story as Immich's API key — not yet
  identified where that's stored on-device.
- **`heartbeat.koplugin`** — sends KOReader's current state (book info,
  battery level) to a Home Assistant binary sensor.

None of these are vendored or have a plugin-list bullet with real detail
yet. Do that in a follow-up once there's confirmation on whether they're
keepers.

### KOReader settings (`koreader-settings/`, copy into
`/mnt/us/koreader/settings/` — or `/mnt/base-us/koreader/settings/`, same
underlying data, see "Two valid mount points" under SSH access below)

Every file in `koreader/settings/` was swept and sorted into "worth
carrying to a new device" vs. "device-specific junk/transient state,
not configuration" before anything was added here — see
`koreader-settings/README.md` for the full sweep and reasoning per file.
Summary:

- **Server configs, credentials blanked**: `wallabag.lua`, `opds.lua`
  (only the Calibre entry has a password; the public feeds don't),
  `kosync.lua` (no credentials in this file at all), `cloudstorage.lua`
  (the WebDAV account `AnnotationSync.koplugin` binds to). Re-enter
  passwords after copying.
- **Config that isn't a clean file to copy**: `cwasync-NOTE.md`,
  `annotationsync-NOTE.md`, `crossbill-NOTE.md` — these three plugins
  store their config inside KOReader's global `settings.reader.lua`
  instead of their own file, so there's nothing clean to copy; each NOTE
  has the exact values and where to enter them in KOReader's menu.
- **UI/behavior customization, no credentials**: `bookshelf.lua` +
  `bookshelf_micromodules.lua` (chip bar, hero card, colors, start menu,
  micromodules — see "Bookshelf home screen" below), `bookends.lua`
  (overlay presets), `gestures.lua` (gesture-to-action bindings),
  `collection.lua` (built-in collection ordering, no book membership
  data), `bookshortcuts.lua` (folder-shortcut preference), `text_editor.lua`
  (font/size prefs; contains one device-specific `last_path`, harmless).

### Home / library folder

Kindle's own convention: `/mnt/us/koreader/epubs/books/` — unlike Kobo,
where Nickel scans `/mnt/onboard` itself so the library has to live at
top level, KOReader's own dedicated books folder works fine here since
nothing else on the device needs to see it. Point OPDS/Wallabag downloads
and Bookshelf's Home source here.

**Set `download_dir` explicitly on the Calibre OPDS chip** —
`/mnt/us/koreader/epubs/books` — even though downloads currently land
there correctly by luck (the global "last used" folder happens to already
be this one). See the per-chip download folder warning in
`../shared/koreader-plugins/bookshelf.koplugin/SETUP.md`: this is the
exact same silent-fallback trap that broke downloads on the Kobo rebuild,
just not yet triggered here because nothing has knocked the "last used"
folder over to Wallabag's. Don't rely on that luck holding.

### Bookshelf home screen (gestures, start menu, chip bar, micromodules)

The mechanism — chip bar, per-chip download folder, micromodules — is
pure `bookshelf.koplugin` behavior, documented once in
**[`../shared/koreader-plugins/bookshelf.koplugin/SETUP.md`](../shared/koreader-plugins/bookshelf.koplugin/SETUP.md)**.
Read that first. This device's specifics:

- **Gesture corner used here**: **Bottom Right** (`tap_right_bottom_corner`
  → `bookshelf_open_start_menu`). Unlike Kobo, this corner had no
  conflicting default action to uncheck.
- **Start menu contents**: a large, deliberately curated set — quote of
  the day, Restart KOReader, Bookshelf menu, reading calendar, AI Book
  Recap, Wallabag Pull, Vocabulary Cards, AI Book Insights, X-Ray, App
  Store, Close book, Start/Stop/Status Tailscale, Calibre Sync (progress
  push, with and without an active document). See
  `koreader-settings/bookshelf.lua`'s `start_menu_items` for the exact
  block if reproducing this on another Kindle.
- **Chip bar**: Home, Recent, Calibre (OPDS, `source.id = "504150a3"` —
  same catalog/hash as Kobo's, since it's the same Calibre-Web server).
  Series/Latest/Authors/etc. all disabled.
- **Micromodules**: Clock (digital) + Reading streak (tap action:
  Reading insight, via `readinginsights.koplugin` — this is the
  reference behavior the Kobo setup was matched against).

### Tailscale binary itself — deliberately not vendored

`/mnt/us/extensions/tailscale/bin/{tailscale,tailscaled}` are Tailscale's
own official prebuilt binaries. Currently version **1.102.2**,
architecture **armv7l** (32-bit ARM, matches Kindle Paperwhite 5's CPU).
~67MB combined — deliberately not committed (binary blobs bloat every
future clone permanently, and it's trivially re-obtained).

To reproduce: download the matching static build from
`https://pkgs.tailscale.com/stable/` (`linux_arm` variant) at the version
above or newer, and place `tailscale`/`tailscaled` at that path.
`tailscale/start_tailscale.sh` and `dns_watch.sh` assume that exact path.

The Kindle's own `wifid` overwrites `/etc/resolv.conf` with DHCP-provided
nameservers on every Wi-Fi reconnect (frequent — Kindles sleep Wi-Fi
aggressively), fighting Tailscale's MagicDNS. `wifid` is a closed Amazon
binary, so instead of hooking its write point, `tailscale/dns_watch.sh`
is a small loop that re-asserts `nameserver 100.100.100.100` every 10s,
launched from `start_tailscale.sh`. Verified to survive a real reboot and
self-heal a forced overwrite.

### Boot hooks

See `boot-hooks/README.md` for the full detail — this is the one part of
the setup that genuinely can't be reproduced by a normal file copy (both
files live on the read-only root filesystem, requiring an `mntroot rw`
remount to place back). Summary of what's live:

- `kor.conf` — KOReader autolaunch on boot, via a third-party KUAL
  extension. Fires in both framework and frameworkless boots.
- `tailscale.conf` — Tailscale + the DNS watcher, on boot.
- `tailscale-watchdog.conf` and `phd.conf` — both **disabled 2026-08-27**
  (renamed to `.disabled`, not deleted): the watchdog was silently
  undoing manual Tailscale stops within 5 minutes, and `phd` (Amazon's
  telemetry daemon) was found sending a UDP heartbeat every ~27s, enough
  on its own to defeat KOReader's idle-Wi-Fi-off watchdog. See
  `boot-hooks/README.md` for the packet-capture root-cause work behind
  both.
- `wifiwatch.conf` — added 2026-08-27, keeps the Wi-Fi-state monitoring
  set up for that investigation running across reboots.

## Secrets — deliberately excluded, do not add these

- **`/mnt/us/extensions/tailscale/bin/auth.key`** — Tailscale auth key,
  plain text, single line. Generate at
  https://login.tailscale.com/admin/settings/keys.
- **`/mnt/us/extensions/tailscale/bin/ssh_host_*_key`** — dropbear SSH
  host keys. Don't hand-populate; delete and let dropbear regenerate
  fresh ones on next start (`dropbear -R`).
- **`/mnt/us/extensions/tailscale/bin/tailscaled.state`** — the node's
  Tailscale private key. Created automatically on first successful
  `tailscale up --auth-key=...`. Deleting it forces re-registration as a
  "new" node.
- **`/mnt/us/koreader/settings/immich_api.key`** — Immich API key, plain
  text, single line. Generate from the Immich **web UI** (not the
  Android app), Account Settings → API Keys → New API Key, with **only
  `asset.upload`** checked.
- **`shared/koreader-plugins/vocabdeck.koplugin/vocabdeck_apikeys.lua`**
  and **`vocabdeck_configuration.lua`** — AI provider API keys for
  VocabDeck's optional enrichment. Copy the
  committed `.sample` files and fill them in.

## SSH access

- Port 2222: KOReader's own dropbear SSH plugin, pubkey-only, `-o
  IdentitiesOnly=yes` required when multiple keys are offered.
- Port 22: Tailscale SSH (`tailscale set --ssh=true/false`), tailnet-only
  — confirmed unreachable over plain LAN. Left enabled by choice, since
  access is already gated behind Tailscale's own identity auth.
- **Two valid mount points for the same data**: `/mnt/us/koreader` (a
  FUSE passthrough, `fsp`) and `/mnt/base-us/koreader` (the real
  underlying vfat mount) both resolve to identical content — confirmed
  via matching plugin counts. `backup_koreader.sh` defaults to
  `/mnt/base-us/koreader`; either works.

## Install order (rough)

1. Jailbreak via SpringBreak, install KOReader per its own instructions.
2. Enable KOReader's SSH server (gear icon → Network → SSH server),
   note the device IP or confirm Tailscale MagicDNS resolves `kindle`.
3. Install Tailscale binaries (see "Tailscale binary itself" above),
   set up `tailscale/up.args`, boot hook, and DNS watcher.
4. Copy each `../shared/koreader-plugins/*.koplugin` folder plus
   `koreader-plugins/suspendhack.koplugin` and
   `koreader-plugins/wifiwatchdogtune.koplugin` into
   `/mnt/us/koreader/plugins/`, restart KOReader.
5. Create `/mnt/us/koreader/epubs/books/`, point KOReader's file browser
   and `bookshelf.koplugin` at it.
6. Copy `koreader-settings/*.lua` into `/mnt/us/koreader/settings/`, fill
   in blanked passwords on-device, and follow the three `*-NOTE.md`
   files for the settings that live inside `settings.reader.lua` instead.
7. Set up the `kor.conf` boot hook per `boot-hooks/README.md` if
   boot-time autolaunch is wanted (read the full incident/rationale
   history there first — this is a read-only-filesystem edit).
8. Bookshelf home screen: gestures, start menu, chip bar, micromodules —
   see that section above.
9. Investigate and decide on the four undocumented plugins (see "Not yet
   audited/documented" above) before treating this file as complete.
