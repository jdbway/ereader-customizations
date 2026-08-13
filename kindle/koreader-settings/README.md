# KOReader settings — server configs only

Backups of the KOReader settings files that hold server URLs/credentials you'd
otherwise have to type in by hand on every new device. **Not** a backup of
KOReader's settings directory in general — most files there (reading
statistics, vocabulary DB, book covers cache, per-book state, etc.) are
device-specific junk you don't want copied to a new device anyway. Only the
files below qualify, after a full sweep of `koreader/settings/` for anything
else matching this pattern (checked `cloudstorage.lua` too — empty, nothing
configured there).

**All passwords are blanked out before committing** — never pulled into this
repo in the first place for `cwasync` (see `cwasync-NOTE.md`), and manually
stripped for the other two. Re-enter them after copying.

- `wallabag.lua` → copy to `koreader/settings/wallabag.lua`. Password blank,
  everything else (server URL, username, OAuth client id/secret) intact.
- `opds.lua` → copy to `koreader/settings/opds.lua`. Only the Calibre entry's
  password is blank; the public feeds (Gutenberg, Standard Ebooks, etc.) have
  no credentials.
- `kosync.lua` → copy to `koreader/settings/kosync.lua`. No credentials
  stored in this file at all — safe as committed.
- `cwasync-NOTE.md` → not a settings file. `cwasync.koplugin` stores its
  config inside KOReader's global `settings.reader.lua` instead of its own
  file, so there's nothing clean to copy — this note has the 3 values
  (server/username/password) and where to enter them in KOReader's menu.
