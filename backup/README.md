# backup/

A Kodi-style "back up the whole app + addon config, restore it onto a new
device" pair of scripts — `backup_koreader.sh` pulls, `restore_koreader.sh`
pushes. Treats KOReader itself as the "OS": what gets backed up is the full
`plugins/` install plus top-level `settings/*.lua` config, nothing else.

## How this differs from `kindle/koreader-plugins/` and `kindle/koreader-settings/`

Those are the **curated, public, documented** subset of the same
information: hand-picked plugins with upstream links and customization
notes, settings files with passwords blanked before committing. They're
meant to be read and browsed, and they're git-tracked.

This `backup/` tooling instead produces a **raw, personal, disaster-recovery
snapshot** — everything in `plugins/` and every top-level `settings/*.lua`
file, unfiltered, straight off the device. That means it also picks up real
secrets that the curated files deliberately strip out:

- `vocabdeck.koplugin/vocabdeck_apikeys.lua` and `vocabdeck_configuration.lua`
  (AI provider API keys), if populated on the device.
- Plaintext credentials embedded in `settings.reader.lua` — `crossbill_sync`,
  `annotation_sync_plugin`, `cwasync`, and anything else a plugin stores
  there instead of its own file.

**Never commit a raw snapshot's contents as-is.** `backup/kindle/` and
`backup/kobo/` (where `backup_koreader.sh` writes, split by `DEVICE`) are
both gitignored for exactly this reason. If you want something from a
snapshot reflected in the curated, public `kindle/` or `kobo/` folder,
copy it over by hand and scrub it the same way the existing files there
were (see `kindle/koreader-settings/README.md` for what was kept vs.
dropped and why on Kindle — same reasoning applies to `kobo/`).

## What's excluded on purpose

- **Book-specific data**: no `epubs/books`, no VocabDeck card databases
  (`vocabdeck/*.sqlite3`). This backs up the app and its configuration, not
  your library or reading history. `koreader-joplin-sync`'s
  `extract/pull_kindle.sh` is the tool for annotation/vocab data specifically.
- **Reading statistics, per-book progress (`docsettings/`), caches, lookup
  history, battery stats, the stock (unused) Vocabulary Builder db** — same
  device-specific-junk reasoning `kindle/koreader-settings/README.md`
  already documents for the curated files; this backup just applies it
  automatically by only grabbing top-level `settings/*.lua`.
- **Boot hooks** (`kor.conf`, `tailscale.conf`) — these live on the
  read-only root filesystem and can't be safely scripted the same way (a
  bad upstart job can affect boot). Still manual, still `mntroot rw`-gated
  — see `kindle/boot-hooks/README.md`.

## Usage

One script pair for both devices — set `DEVICE=kindle` (the default) or
`DEVICE=kobo`, which picks the right default host alias and remote
KOReader path (`/mnt/base-us/koreader` vs. `/mnt/onboard/.adds/koreader` —
Nickel's plugin/config layout differs from the Kindle jailbreak's). Not a
forked `backup_kobo.sh`, since the only real difference is those two
defaults.

```
# Kindle (from a machine with SSH reach, e.g. over Tailscale):
KINDLE_HOST=root@kindle ./backup_koreader.sh
# -> writes to backup/kindle/<timestamp>/

# Kobo:
DEVICE=kobo ./backup_koreader.sh
# -> writes to backup/kobo/<timestamp>/

# Restore onto a fresh/replacement device:
./restore_koreader.sh backup/kindle/<timestamp> root@newkindle
DEVICE=kobo ./restore_koreader.sh backup/kobo/<timestamp> root@newkobo
```

Both scripts assume a plain `ssh <host>` (no extra flags) already works —
put port and key config in `~/.ssh/config` under whatever host alias you
pass, rather than passing flags to these scripts. Kindle: dropbear on
2222, or Tailscale SSH on 22 (see `kindle/README.md`'s "SSH access"
section). Kobo: dropbear on 2222 over LAN only — Tailscale there is a
manual toggle by design (battery reasons, see `kobo/BASE_SETUP.md`), so
its MagicDNS name isn't reliably up; point the alias at the LAN IP
directly instead, e.g.:
```
Host kobo-sabrina
    HostName 192.168.5.93
    Port 2222
    User root
```
