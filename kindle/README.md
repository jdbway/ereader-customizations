# Kindle setup

Kindle Paperwhite 5, jailbroken, running KOReader + Tailscale + a self-hosted
Calibre-Web NextGen library. Goal: reach the OPDS catalog and sync progress
over the tailnet from anywhere, with the Amazon framework disabled most of
the time to save power.

## Jailbreak

Jailbroken via **[SpringBreak](https://kindlemodding.org/jailbreaking/SpringBreak/)**.
Everything below — the `DONT_START_FRAMEWORK` flag convention, KUAL,
`mntroot rw`/`ro`, the MRPI/KUAL bridge scaffolding (`kmc.conf`) — is part of
the broader Kindle jailbreak ecosystem this method sets up, not specific to
this repo. If reproducing this setup on another Kindle, start there; the
specific jailbreak method used can affect exact file locations/mechanisms
(e.g. other jailbreaks may not use `/etc/upstart/framework.conf`'s stock
`DONT_START_FRAMEWORK` check the same way), so treat the boot-hook details
in this repo as SpringBreak-specific until verified otherwise.

## Layout

- `assistant.koplugin` — **not vendored here, deliberately.** AI Helper
  plugin (Claude/GPT/Gemini/DeepSeek/Ollama while reading — the "Add to
  Note"/"Save" conversation features underpinning most of the AI
  highlights/notes on this device). Tracked in its own repo instead,
  [jdbway/assistant.koplugin](https://github.com/jdbway/assistant.koplugin)
  (a real fork of
  [omer-faruq/assistant.koplugin](https://github.com/omer-faruq/assistant.koplugin),
  with at least one PR merged upstream from it) — that repo is the
  definitive copy with real history, so it's linked from here rather than
  duplicated.

- `koreader-plugins/networkextras.koplugin/` — **ours.** Adds a "Network
  Extras" entry to KOReader's main menu with:
  - **Framework Mode**: reboot with the Amazon framework enabled (needed to
    switch Wi-Fi networks — see below) or reboot back to low-power
    frameworkless mode.
  - **Start/Stop/Update Tailscale**: manual control without leaving KOReader,
    including checking for and installing newer Tailscale binaries (via
    `update_tailscale.sh`, backs up the old binaries as `*.bak` first; a
    Stop then Start afterward picks up the new version).

  Wi-Fi network switching used to be a menu item here too, but KOReader's own
  network picker calls into Amazon's framework layer, which is a no-op with
  the framework disabled, and driving `wpa_supplicant` directly proved
  unreliable against `wifid`'s own reconnect logic. Rebooting into framework
  mode to switch networks turned out to be the only deterministic path, so
  the unreliable in-KOReader picker was removed entirely.

  The "Framework Mode" reboot options are always tappable now (previously the
  option matching the *current* mode was greyed out, which was more
  confusing than useful). The whole "Network Extras" menu also now sets
  `sorting_hint = "tools"` so it lands under KOReader's Tools (wrench) menu,
  matching where every other plugin-added menu on this device shows up,
  instead of the unrelated default bucket it fell into before.

- `koreader-plugins/suspendhack.koplugin/` — **third-party**, see its
  `SOURCE.md`. Required for normal suspend/resume while frameworkless.

- `koreader-plugins/vocabdeck.koplugin/` — **third-party**
  ([yupmoon/vocabdeck.koplugin](https://github.com/yupmoon/vocabdeck.koplugin)),
  vendored directly. Vocabulary deck/flashcard plugin with optional AI
  enrichment. **This copy has local customizations** — bug fixes and
  behavior changes on top of upstream, see its own `CUSTOMIZATIONS.md` for
  the full list and why. **Its real `vocabdeck_apikeys.lua` and
  `vocabdeck_configuration.lua` are excluded** (per the plugin's own
  `.gitignore`) — see its `README.md` for how to populate them from the
  committed `.sample` files. Any updates made to this plugin from another
  chat/session won't be reflected here until re-synced from the device —
  this repo only has whatever was last copied over.

- `koreader-plugins/bookshelf.koplugin/` — **third-party**
  ([AndyHazz/bookshelf.koplugin](https://github.com/AndyHazz/bookshelf.koplugin)),
  vendored directly. Home-screen replacement — the active one on this device
  (**Start with → Bookshelf** in KOReader's file-manager menu). Installed via
  `git clone` on the device itself (for its in-app dev-branch update
  feature), so the nested `.git/` was stripped before committing here — a
  copy pulled from this repo is a plain file tree, not a git checkout of
  upstream.

- `koreader-plugins/bookends.koplugin/` — **third-party**
  ([AndyHazz/bookends.koplugin](https://github.com/AndyHazz/bookends.koplugin)),
  vendored directly. Overlay presets/styling; also supplies Bookshelf's
  richer font-preview and extra progress-bar styles when both are installed
  together.

- `koreader-plugins/simpleui.koplugin/` — **third-party**
  ([doctorhetfield-cmd/simpleui.koplugin](https://github.com/doctorhetfield-cmd/simpleui.koplugin)),
  vendored directly. An earlier home-screen replacement, no longer the
  default (Bookshelf is), but still installed: it contributes a standalone
  persistent toolbar widget (Wi-Fi/brightness/power toggles) independent of
  its home-screen role. Confirmed by direct testing that deleting it breaks
  that widget AND `suspendhack.koplugin`'s FileManager widget registration,
  even though neither has a visible code-level dependency on it — keep it
  installed.

- `koreader-plugins/cwasync.koplugin/` — **not third-party in the usual
  sense**: vendored directly from KOReader's own mainline repo
  (https://github.com/koreader/koreader/tree/master/plugins/cwasync.koplugin),
  not a separate author's project. Handles progress sync *and* two-way
  highlights/annotations sync with Calibre-Web NextGen (`sync_logic.lua` has
  a real last-write-wins merge engine, not just percentage push). Note:
  annotation sync is opt-in and manual — check "Sync KOReader highlights" in
  its menu, then tap "Sync highlights now" each time; it does not currently
  hook into automatic/periodic sync.

- `koreader-plugins/AnnotationSync.koplugin/` — **third-party**
  ([dani84bs/AnnotationSync.koplugin](https://github.com/dani84bs/AnnotationSync.koplugin)),
  vendored directly, unmodified (v2.0.0). Cross-device highlight/note/
  bookmark sync via WebDAV, with smart last-write-wins merging and a trash
  bin for recovering accidental deletions. Binds to a Cloud storage+ WebDAV
  account rather than holding its own connection — config split across two
  files, see `koreader-settings/annotationsync-NOTE.md`. The WebDAV server
  itself is self-hosted (`rclone serve webdav`, `homelab-rclone` repo) and
  shared across every device, not per-device config.

  This is the practical fix for the stock KOReader → Joplin exporter being
  unfit for purpose (creates a new note per re-export instead of updating in
  place) — annotations land here first, in one KOReader-native shape, then
  get pulled from the shared WebDAV store into whatever downstream tool
  needs them, instead of each tool needing its own per-device sync story.

- `koreader-plugins/crossbill.koplugin/` — **third-party**
  ([Crossbill-App/koreader-plugin](https://github.com/Crossbill-App/koreader-plugin)),
  vendored directly, unmodified. Syncs highlights to a self-hosted
  [Crossbill](https://github.com/Crossbill-App/crossbill-web) instance for
  a real web UI — browsing highlights, AI chapter summaries, flashcards.
  Menu only appears in Tools while a document is open (`is_doc_only = true`
  in its `main.lua`). Config in `settings.reader.lua`, see
  `koreader-settings/crossbill-NOTE.md` — including a known upstream gap
  where highlight notes don't currently make it into Crossbill (tracked in
  that note).

- `koreader-settings/` — **ours.** Backups of the KOReader settings files
  that hold server URLs/credentials (Wallabag, Calibre OPDS, kosync), so a
  new device can be configured by copying files instead of retyping
  everything. Passwords are blanked before committing — see its own README.

- `tailscale/dns_watch.sh`, `tailscale/start_tailscale.sh` — **ours.** The
  Kindle's own `wifid` overwrites `/etc/resolv.conf` with DHCP-provided
  nameservers on every Wi-Fi reconnect (which happens often — Kindles sleep
  Wi-Fi aggressively), fighting Tailscale's MagicDNS (`CorpDNS`). `wifid` is
  a closed Amazon binary, so instead of hooking its write point, `dns_watch.sh`
  is a small loop that re-asserts `nameserver 100.100.100.100` every 10s.
  It's launched from `start_tailscale.sh` (which already runs at boot via the
  existing `/etc/upstart/tailscale.conf` job) — no read-only-filesystem edits
  needed. Verified to survive a real reboot and self-heal a forced overwrite.

- `tailscale/immich_upload_watch.sh` — **ours.** Polls
  `/mnt/us/koreader/screenshots` every 30s and uploads any new file to a
  self-hosted [Immich](https://immich.app) instance via its REST API
  (`POST /api/assets`), tracking what's already been uploaded in a local
  state file so nothing re-uploads. Also launched from `start_tailscale.sh`
  alongside `dns_watch.sh`. Reads the server URL from the top of the script
  itself and the API key from `immich_api.key` (see Secrets below) —
  **generate that key with only the `asset.upload` permission**, nothing
  broader.

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

## Boot hooks

See `boot-hooks/README.md` — backed-up copies of the two upstart job files
that live on the read-only root filesystem: `kor.conf` (KOReader autolaunch,
from a third-party KUAL extension) and `tailscale.conf` (Tailscale + the DNS
watcher). Neither can be reproduced by a normal git checkout — they require
an `mntroot rw` remount to place back, documented there.

## Secrets — deliberately excluded, do not add these

Every secret file below lives only on the device, is never committed here,
and must be recreated by hand if setting this up fresh. For each one: the
exact path, what it holds, and how to (re)populate it.

- **`/mnt/us/extensions/tailscale/bin/auth.key`** — Tailscale auth key, plain
  text, single line, no trailing newline required. Generate one at
  https://login.tailscale.com/admin/settings/keys and paste it in. Read by
  `start_tailscale.sh` as a fallback when a plain `tailscale up` reconnect
  fails (first-time registration or after a reset).
- **`/mnt/us/extensions/tailscale/bin/ssh_host_*_key`** — dropbear SSH host
  keys. Don't hand-populate these; delete them and let dropbear regenerate
  fresh ones on next start (`dropbear -R`, already the flag used here).
- **`/mnt/us/extensions/tailscale/bin/tailscaled.state`** — contains the
  node's Tailscale private key. Not something you write by hand; it's
  created automatically the first time `tailscale up --auth-key=...`
  succeeds. Deleting it forces the device to re-register as a "new" node.
- **`/mnt/us/extensions/tailscale/bin/immich_api.key`** — Immich API key,
  plain text, single line, no trailing newline required. Generate one from
  the Immich **web UI** (not the Android app) under Account Settings → API
  Keys → New API Key, with **only the `asset.upload` permission** checked —
  nothing else. Read by `immich_upload_watch.sh`.
- **`kindle/koreader-plugins/vocabdeck.koplugin/vocabdeck_apikeys.lua`** and
  **`vocabdeck_configuration.lua`** — AI-provider API keys for VocabDeck's
  optional enrichment feature. Copy the committed `.sample` files to these
  names and fill them in; see that plugin's own `README.md` for the exact
  format per provider.

## SSH access

- Port 2222: KOReader's own dropbear SSH plugin, pubkey-only, `-o
  IdentitiesOnly=yes` required when multiple keys are offered.
- Port 22: Tailscale SSH (`tailscale set --ssh=true/false`), tailnet-only —
  confirmed unreachable over plain LAN. Left enabled by choice, since access
  is already gated behind Tailscale's own identity auth.
