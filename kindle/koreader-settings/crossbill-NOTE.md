# Crossbill config — not backed up as a file

Same situation as `cwasync-NOTE.md`: `crossbill.koplugin` stores its config
(`base_url`/`username`/`password`/`autosync_enabled`/
`session_tracking_enabled`/`min_reading_session_duration`) inside KOReader's
global `settings.reader.lua` under the `crossbill_sync` key, not its own
settings file — nothing clean to copy, so it's not vendored here.

The server itself (`crossbill-web`, FastAPI + Postgres) is **shared
infrastructure**, not per-device — see the `homelab-crossbill` repo (not
this one) for the actual deployment. Every e-reader should point at the
same instance.

To reproduce on a new device, in KOReader's main menu:

1. **Tools → Crossbill → Settings → Configure Server** — server URL
   `https://crossbill.truepob.com`, username `jon`, password (see Secrets
   below).
2. **Auto-sync** is off by default on this device — the plugin only pushes
   highlights on suspend/exit if this is enabled; otherwise use **Tools →
   Crossbill → Sync Current Book** manually. Flip it on in the same
   Settings menu if automatic behavior is preferred on a given device.

**Known gap (not a misconfiguration, upstream limitation)**: highlight
*text* syncs fine, but any **note** attached to a highlight (stock or
AI-added) is currently silently dropped server-side — the Crossbill backend
dropped the per-highlight `note` column in a schema redesign
([crossbill-web#409](https://github.com/Crossbill-App/crossbill-web/pull/409))
before this plugin's own note-preservation fix landed. Tracking
[crossbill-web#592](https://github.com/Crossbill-App/crossbill-web/issues/592)
for when that's fixed upstream — its own description says the web UI won't
display the note even once the backend fix merges, so there'll likely be a
further wait after that too.

**Separately**: `crossbill.koplugin`'s menu (and thus this whole feature)
only appears in KOReader's Tools menu while a **document is open**
(`is_doc_only = true` in its `main.lua`) — if it's missing from Tools, open
a book first.

**Server enforces a minimum client version.** Found 2026-08-29: every
sync attempt on kobo-sabrina was failing with HTTP 426 on both the
metadata-fetch and create-book calls — traced (via `curl -v` against
`/api/v1/ereader/books/...` directly) to a JSON body reading
`{"code":"client_upgrade_required","min_supported_version":"0.12.0",...}`.
The installed plugin was `0.10.2` on both Kindle and Kobo (an old vendored
snapshot, predates that server-side gate). **Fixed** by updating
`shared/koreader-plugins/crossbill.koplugin/` to the latest upstream
release (`0.14.0` as of 2026-08-29,
[Crossbill-App/koreader-plugin releases](https://github.com/Crossbill-App/koreader-plugin/releases)),
which also adds a proper `upgrade_required.lua` handler for this exact
scenario going forward (a real in-KOReader message instead of a silent
log-only failure) and its own `modules/update/` self-updater. If a sync
ever silently fails like this again, check the plugin's `_meta.lua`
`version` against the server's current minimum before assuming it's a
config or network problem.

## Secrets

- **Crossbill account password** — not committed anywhere in this repo.
  Lives in `homelab-crossbill/.env` (`ADMIN_PASSWORD`) on the machine that
  deployed the container. Same account for every device connecting to this
  server.
