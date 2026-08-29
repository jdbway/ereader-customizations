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
plugin was first added — see each device folder's README (and
`kobo/BASE_SETUP.md`) for the current snapshot.

See `kindle/README.md` and `kobo/README.md` / `kobo/BASE_SETUP.md` for
per-device details.

## Layout — where does a given file belong?

```
shared/                    genuinely cross-device components — see below
  koreader-plugins/networkextras.koplugin/   ours — Tailscale controls
  koreader-plugins/immichupload.koplugin/    ours — uploads new screenshots to Immich
kindle/
  koreader-plugins/        Kindle-specific + not-yet-audited-for-portability plugins
  koreader-settings/       settings-file backups (passwords blanked)
  tailscale/               Kindle's tailscale scripts + watchers (dns_watch.sh, etc.)
  boot-hooks/              upstart job configs
kobo/
  BASE_SETUP.md            the reference build: full component list + install order
  koreader-plugins/        Kobo-specific + not-yet-audited-for-portability plugins
  koreader-settings/       settings-file backups (passwords blanked)
  tailscale/                Kobo's tailscale scripts
  nickelmenu/               NickelMenu config
backup/backup_koreader.sh  ours — Kodi-style raw snapshot: pulls the whole
                            plugins/ install + top-level settings/*.lua off a
                            device (gitignored output, see backup/README.md)
backup/restore_koreader.sh ours — pushes a backup_koreader.sh snapshot onto a
                            fresh/replacement device
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
*deliberately engineered* to run correctly on every device, not merely
copied identically to both `kindle/` and `kobo/` folders. In practice that
means: no hardcoded device-specific paths, explicit auto-detection where
paths genuinely differ (see `networkextras.koplugin`'s `TS_CANDIDATES`
table, or `immichupload.koplugin`'s use of `DataStorage:getFullDataDir()`
instead of a hardcoded screenshots path), and no untested assumptions.

Plugins that happen to be byte-identical between `kindle/` and `kobo/`
right now (`bookshelf.koplugin`, `bookends.koplugin`, `crossbill.koplugin`,
`cwasync.koplugin`, `appstore.koplugin`) are **not** in `shared/` — they
were vendored as plain copies on the assumption they're cross-platform
(reasonable, since they're pure KOReader-API plugins with no device
mount-point assumptions of their own visible on inspection), but that
assumption hasn't been explicitly verified the way the two `shared/`
plugins were. `simpleui.koplugin` is a known counter-example: it still has
a couple of `Device:isKindle()` / `/mnt/us` references never audited for
Kobo correctness (see `kobo/BASE_SETUP.md`), so treat "currently identical
files" as a weaker signal than "confirmed device-agnostic" — promote a
plugin to `shared/` only once it's actually been checked, not just because
`diff` says the two copies currently match.

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
`vocabdeck.koplugin`, `AnnotationSync.koplugin`, `suspendhack.koplugin`,
etc.) keeps its own upstream license in its own subdirectory's `LICENSE`
file — check that file, not the root one, for terms on those.

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
