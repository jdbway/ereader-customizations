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

## Secrets

- **Crossbill account password** — not committed anywhere in this repo.
  Lives in `homelab-crossbill/.env` (`ADMIN_PASSWORD`) on the machine that
  deployed the container. Same account for every device connecting to this
  server.
