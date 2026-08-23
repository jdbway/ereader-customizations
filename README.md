# ereader-customizations

An up-to-date mirror of the actual configuration running on my e-readers —
KOReader plugins (ours and vendored third-party), boot hooks, Tailscale
scripts, and settings-file backups — for a self-hosted Calibre-Web NextGen
library (`calibre.truepob.com`) reached over a tailnet. One device family at
a time: a Kindle Paperwhite 5 today, a small Kobo fleet for family members
once that's underway.

**Why this exists**: so a new or replacement device can be brought back to
the current working setup by copying files out of here, instead of
re-deriving the whole configuration from memory. That's also *why* it needs
to track what's actually on each device, not just what was true the day a
plugin was first added — see each device folder's README for the current
snapshot.

See `kindle/README.md` and `kobo/README.md` for per-device details.

## Layout

```
kindle/
  koreader-plugins/networkextras.koplugin/   ours — Tailscale + framework-mode controls
  koreader-plugins/suspendhack.koplugin/     third-party (vendored, see its SOURCE.md)
  koreader-plugins/vocabdeck.koplugin/       third-party (vendored, see its README.md)
  koreader-plugins/AnnotationSync.koplugin/  third-party — cross-device highlight sync via WebDAV
  koreader-plugins/crossbill.koplugin/       third-party — syncs highlights to a Crossbill web UI
  tailscale/dns_watch.sh                     ours — self-healing MagicDNS watcher
  tailscale/start_tailscale.sh               ours — modified to launch both watchers
  tailscale/immich_upload_watch.sh           ours — uploads new KOReader screenshots to Immich
kobo/                                        not started yet
scripts/                                     git submodules — each a standalone public repo, linked
                                              here so they're browsable alongside the device configs
                                              that use them
  vocabdeck-anki-export/                     VocabDeck -> Anki (.apkg) one-shot export
  vocabdeck-crossbill-export/                VocabDeck -> Crossbill (direct API) one-shot push
  koreader-joplin-sync/                      KOReader highlights/notes/VocabDeck -> Joplin ETL
```

Cloning this repo? Add `--recurse-submodules`, or run
`git submodule update --init` afterward — otherwise `scripts/*` show up as
empty directories.

## Licensing

The root `LICENSE` (MIT) covers only the code/content authored here —
`networkextras.koplugin`, the `tailscale/` scripts, and the
`koreader-settings/` backups (all marked "ours" below). Every vendored
third-party plugin under `kindle/koreader-plugins/` keeps its own upstream
license in its own subdirectory's `LICENSE` file — check that file, not the
root one, for terms on those.

## What's deliberately not in this repo

- Full source of independently-maintained third-party plugins we didn't
  write and haven't vendored (`bookshelf.koplugin`, `bookends.koplugin`,
  `simpleui.koplugin`) — linked from `kindle/README.md` instead.
- Any secrets: Tailscale auth key, SSH host keys, Tailscale node state file,
  Immich API key, VocabDeck's AI-provider API keys/config. Each has a note
  in `kindle/README.md`'s Secrets section covering exact path, what it
  holds, and how to regenerate/repopulate it.
