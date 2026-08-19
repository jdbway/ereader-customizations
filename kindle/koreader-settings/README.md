# KOReader settings

Backups of KOReader settings files worth carrying to a new device — either
because they hold server URLs/credentials you'd otherwise retype, or because
they're deliberate UI/behaviour customization that'd otherwise need
re-clicking through menus from scratch. **Not** a backup of KOReader's
settings directory in general — most files there (reading statistics,
vocabulary DB, book covers cache, per-book reading progress, changelog/OPDS
caches, lookup/Wikipedia history, battery stats, the untouched
`directory_defaults.lua` template, empty `profiles.lua`) are device-specific
junk or transient state, not configuration, and aren't copied here. Every
file in `koreader/settings/` was swept and sorted into one of these two
buckets before anything was added.

## Server configs (credentials blanked)

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
- `cloudstorage.lua` → copy to `koreader/settings/cloudstorage.lua`. Holds
  the WebDAV account `AnnotationSync.koplugin` binds to. Password blank,
  everything else (address, username, start folder) intact.
- `annotationsync-NOTE.md` → not a settings file. `AnnotationSync.koplugin`
  also needs a step inside `settings.reader.lua`'s `annotation_sync_plugin`
  block that isn't backed up (same reasoning as `cwasync-NOTE.md`) — this
  note covers both halves and the shared-infrastructure WebDAV server it
  points at.
- `crossbill-NOTE.md` → not a settings file. `crossbill.koplugin` stores its
  config inside `settings.reader.lua`'s `crossbill_sync` block, same
  situation as `cwasync`.

## UI / behaviour customization (no credentials involved)

Checked for embedded secrets (password/token/key patterns) before adding —
none found in any of these; nothing was blanked.

- `bookshelf.lua` → copy to `koreader/settings/bookshelf.lua`. Chip bar
  layout, hero card template, colors, start menu.
- `bookshelf_micromodules.lua` → copy alongside it. Per-module config for the
  home-screen/start-menu micro-modules.
- `bookends.lua` → copy to `koreader/settings/bookends.lua`. Overlay presets
  and styling.
- `gestures.lua` → copy to `koreader/settings/gestures.lua`. Gesture-to-action
  bindings.
- `collection.lua` → copy to `koreader/settings/collection.lua`. Built-in
  collection ordering (Favourites/To Be Read) — no book membership data, just
  display order.
- `bookshortcuts.lua` → copy to `koreader/settings/bookshortcuts.lua`. Tiny —
  just the folder-shortcut directory-action preference.
- `text_editor.lua` → copy to `koreader/settings/text_editor.lua`. Font/size
  and behaviour prefs for the text editor plugin. Contains one device-specific
  path (`last_path`) that won't apply as-is on another device — harmless, just
  re-set it if it bothers you.

## Plugin source — checked, nothing to add

`bookshelf.koplugin`, `bookends.koplugin`, `simpleui.koplugin`,
`readinginsights.koplugin`, and `ReadMastery.koplugin` were all diffed
file-by-file against their upstream releases (hash comparison, with a
content-only re-check on any mismatch to rule out line-ending noise from a
`git clone` on Windows). All five are unmodified — every customization lives
in the settings files above, not in patched plugin code. Re-check this if you
ever hand-edit a plugin file directly.
