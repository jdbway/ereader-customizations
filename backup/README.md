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

**Never commit a raw snapshot's contents as-is.** `backup/kindle/` (where
`backup_koreader.sh` writes by default) is gitignored for exactly this
reason. If you want something from a snapshot reflected in the curated,
public `kindle/` folder, copy it over by hand and scrub it the same way the
existing files there were (see `kindle/koreader-settings/README.md` for
what was kept vs. dropped and why).

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

```
# Back up (from a machine with SSH reach to the device, e.g. over Tailscale):
KINDLE_HOST=root@kindle ./backup_koreader.sh
# -> writes to backup/kindle/<timestamp>/

# Restore onto a fresh/replacement device:
./restore_koreader.sh backup/kindle/<timestamp> root@newkindle
```

Both scripts assume a plain `ssh <host>` (no extra flags) already works —
put port (dropbear on 2222, or Tailscale SSH on 22 — see kindle/README.md's
"SSH access" section) and key config in `~/.ssh/config` under whatever host
alias you pass, rather than passing flags to these scripts.

Kobo equivalents don't exist yet — no Kobo device to back up. When that
starts, this'll need a `backup_kobo.sh`/`restore_kobo.sh` pair with
Kobo-specific paths (Nickel's plugin/config layout differs from the Kindle
jailbreak's `/mnt/base-us/koreader`).
