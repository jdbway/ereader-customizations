# ereader-customizations

An up-to-date mirror of the actual configuration running on my e-readers —
KOReader plugins (ours and vendored third-party), boot hooks, Tailscale
scripts, and settings-file backups — for a self-hosted Calibre-Web NextGen
library (`calibre.truepob.com`) reached over a tailnet. Two device families:
a Kindle Paperwhite 5, and a growing Kobo fleet (`kobo-sabrina` today, more
planned for family members — see `kobo/BASE_SETUP.md` for the repeatable
base image).

**Why this exists**: so a new or replacement device can be brought back to
the current working setup by copying files out of here, instead of
re-deriving the whole configuration from memory. That's also *why* it needs
to track what's actually on each device, not just what was true the day a
plugin was first added — see each device's `BASE_SETUP.md` for the
current snapshot.

See `kindle/README.md` / `kindle/BASE_SETUP.md` and `kobo/README.md` /
`kobo/BASE_SETUP.md` for per-device details — same structure in both,
Components + Install order, so the two are directly comparable.

## Layout — where does a given file belong?

```
shared/                    genuinely cross-device components — see below
  koreader-plugins/        every plugin confirmed to run correctly on both
                            devices (12 as of 2026-08-29) — see "The
                            shared/ rule" below for what "confirmed" means.
                            Notably: networkextras.koplugin and
                            immichupload.koplugin (ours), readinginsights.koplugin
                            (vendored — powers the Reading streak
                            micromodule's "Reading insight" tap action),
                            bookshelf.koplugin/SETUP.md (device-agnostic
                            home-screen setup instructions, referenced by
                            both kindle/BASE_SETUP.md and kobo/BASE_SETUP.md
                            instead of duplicated in each)
kindle/
  BASE_SETUP.md            the reference build: full component list + install order
  koreader-plugins/        genuinely Kindle-only plugins (2 as of 2026-08-29:
                            suspendhack.koplugin, wifiwatchdogtune.koplugin —
                            both touch Amazon-framework-specific mechanisms
                            with no Kobo equivalent)
  koreader-settings/       settings-file backups (passwords blanked)
  tailscale/               Kindle's tailscale scripts + watchers (dns_watch.sh, etc.)
  boot-hooks/              upstart job configs
kobo/
  BASE_SETUP.md            the reference build: full component list + install order
  koreader-plugins/        empty as of 2026-08-29 — every plugin Kobo
                            currently uses turned out to be device-agnostic
  koreader-settings/       settings-file backups (passwords blanked)
  tailscale/                Kobo's tailscale scripts
  nickelmenu/               NickelMenu config
backup/backup_koreader.sh  ours — Kodi-style raw snapshot: pulls the whole
                            plugins/ install + top-level settings/*.lua off a
                            device (DEVICE=kindle|kobo, gitignored output,
                            see backup/README.md)
backup/restore_koreader.sh ours — pushes a backup_koreader.sh snapshot onto a
                            fresh/replacement device (same DEVICE switch)
scripts/                   git submodules — each a standalone public repo, linked
                            here so they're browsable alongside the device configs
                            that use them
  vocabdeck-anki-export/   VocabDeck -> Anki (.apkg) one-shot export
  vocabdeck-crossbill-export/ VocabDeck -> Crossbill (direct API) one-shot push
  koreader-joplin-sync/    KOReader highlights/notes/VocabDeck -> Joplin ETL
```

Cloning this repo? Add `--recurse-submodules`, or run
`git submodule update --init` afterward — otherwise `scripts/*` show up as
empty directories.

### The `shared/` rule (read this before adding or editing a plugin)

A plugin goes in **`shared/koreader-plugins/`** only if it's been
*deliberately engineered or explicitly audited* to run correctly on every
device — no hardcoded device-specific paths, explicit auto-detection
where paths genuinely differ (see `networkextras.koplugin`'s
`TS_CANDIDATES` table, or `immichupload.koplugin`'s use of
`DataStorage:getFullDataDir()` instead of a hardcoded screenshots path),
and no untested assumptions. It does **not** require the plugin to
currently be installed on both devices — `AnnotationSync.koplugin` and
`vocabdeck.koplugin`, for example, are only installed on Kindle today but
live in `shared/` because their code has been checked and found clean;
nothing stops a future Kobo from installing them too.

As of the 2026-08-29 full-repo audit, every plugin that's been checked
this way lives in `shared/` — `kindle/koreader-plugins/` holds only the
two that failed the check for a genuine reason (see the Layout tree
above), and `kobo/koreader-plugins/` is empty. `simpleui.koplugin` was a
real counter-example caught by this process: it had a hardcoded
`/mnt/us/...` fallback path in `sui_updater.lua`, fixed before being
moved to `shared/` (see `kobo/BASE_SETUP.md`). Treat "currently identical
files between `kindle/` and `kobo/`" as a weaker signal than "confirmed
device-agnostic" if you ever find a plugin duplicated instead of shared —
that's a sign it hasn't been audited yet, not that it can't be.

**When you fix or extend something in `shared/`, the fix applies to every
device by construction — there's only one copy.** When you touch something
still duplicated per-device, sync both copies deliberately and say so in
the commit message and any linked issue (name both devices explicitly,
don't just describe the device you happened to test on) — a commit that
only mentions one device when it actually touched both is exactly the kind
of ambiguity this section exists to prevent.

## Licensing

The root `LICENSE` (MIT) covers only the code/content authored here —
everything under `shared/`, `networkextras.koplugin`/`immichupload.koplugin`
wherever else referenced, the `tailscale/` scripts, the `koreader-settings/`
backups, and the `backup/` scripts. Every vendored third-party plugin
(`bookshelf.koplugin`, `bookends.koplugin`, `simpleui.koplugin`,
`crossbill.koplugin`, `cwasync.koplugin`, `appstore.koplugin`,
`readinginsights.koplugin`, `vocabdeck.koplugin`, `AnnotationSync.koplugin`,
`suspendhack.koplugin`, etc.) keeps its own upstream license in its own
subdirectory's `LICENSE` file — check that file, not the root one, for
terms on those.

## What's deliberately not in this repo

- KOReader itself and NickelMenu's own installer binary — large prebuilt
  third-party releases, not something to vendor in git. See
  `kobo/BASE_SETUP.md` for exact sources/versions.
- Tailscale's own binaries — `update_tailscale.sh` fetches the current
  release itself (works for first install too, not just updates).
- Any secrets: Tailscale auth keys, SSH host keys, Tailscale node state
  files, Immich API keys, Crossbill/Wallabag/Calibre passwords, VocabDeck's
  AI-provider API keys/config. Each has a note in the relevant device
  folder covering exact path, what it holds, and how to regenerate/
  repopulate it (search for "blanked" / "NOTE.md" in `koreader-settings/`).
