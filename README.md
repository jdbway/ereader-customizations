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
  tailscale/dns_watch.sh                     ours — self-healing MagicDNS watcher
  tailscale/start_tailscale.sh               ours — modified to launch both watchers
  tailscale/immich_upload_watch.sh           ours — uploads new KOReader screenshots to Immich
kobo/                                        not started yet
```

## What's deliberately not in this repo

- Full source of independently-maintained third-party plugins we didn't
  write and haven't vendored (`bookshelf.koplugin`, `bookends.koplugin`,
  `simpleui.koplugin`) — linked from `kindle/README.md` instead.
- Any secrets: Tailscale auth key, SSH host keys, Tailscale node state file,
  Immich API key, VocabDeck's AI-provider API keys/config. Each has a note
  in `kindle/README.md`'s Secrets section covering exact path, what it
  holds, and how to regenerate/repopulate it.
