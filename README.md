# ereader-customizations

Custom KOReader/Tailscale setup for e-readers reaching a self-hosted
Calibre-Web NextGen library (`calibre.truepob.com`) over a tailnet — one
device at a time, starting with a Kindle Paperwhite 5, eventually a small
fleet of Kobos for family members.

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

## What's deliberately not in this repo

- Full source of independently-maintained third-party plugins we didn't
  write and haven't vendored (`bookshelf.koplugin`, `bookends.koplugin`,
  `simpleui.koplugin`) — linked from `kindle/README.md` instead.
- Any secrets: Tailscale auth key, SSH host keys, Tailscale node state file,
  Immich API key, VocabDeck's AI-provider API keys/config. Each has a note
  in `kindle/README.md`'s Secrets section covering exact path, what it
  holds, and how to regenerate/repopulate it.
