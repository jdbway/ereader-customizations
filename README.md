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
  tailscale/dns_watch.sh                     ours — self-healing MagicDNS watcher
  tailscale/start_tailscale.sh               ours — modified to launch the watcher
kobo/                                        not started yet
```

## What's deliberately not in this repo

- Full source of independently-maintained third-party plugins we didn't
  write (`bookshelf.koplugin`, `bookends.koplugin`, `simpleui.koplugin`) —
  linked from `kindle/README.md` instead.
- Any secrets: Tailscale auth keys, SSH host keys, node state files.
