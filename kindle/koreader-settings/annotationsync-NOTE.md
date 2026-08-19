# AnnotationSync config — split across two files, one blanked, one not backed up at all

`AnnotationSync.koplugin` needs config in **two places**, because it binds
to a Cloud storage+ account rather than holding its own connection details:

1. **`cloudstorage.lua`** (backed up in this directory, password blanked) —
   the actual WebDAV account: address `https://webdav.truepob.com`, username
   `jon`, start folder `/koreader`. This is a self-hosted `rclone serve
   webdav` container (see the `homelab-rclone` repo, not this one) reverse-
   proxied at that domain — **shared infrastructure**, not per-device. Every
   e-reader (this Kindle, the future Kobos) should point at this same
   server, not stand up its own.
2. **`settings.reader.lua`'s `annotation_sync_plugin` block** — not backed
   up here, same reasoning as `cwasync-NOTE.md`: it's embedded in the same
   giant device-specific settings file, not a clean standalone config. Its
   `sync_server` sub-table duplicates the `cloudstorage.lua` entry above
   (address/username/password/url) plus adds `device_name` and sync
   preferences (`progress_sync`, `network_auto_sync`, etc., all off by
   default on this device).

To reproduce on a new device, in KOReader's main menu:

1. **Tools → Cloud storage+ → Add new cloud storage → WebDAV** — Server
   address `https://webdav.truepob.com`, username `jon`, password (see
   Secrets below), start folder `/koreader`.
2. **Tools → Annotation Sync → Settings → Cloud settings** → select that
   WebDAV account. This is the step that actually populates
   `annotation_sync_plugin.sync_server` — just adding the Cloud storage+
   account in step 1 isn't enough on its own.
3. Optionally set a **Device name** in the same Settings menu (defaults to
   the hardware model name if left blank — worth setting explicitly once
   there's more than one device sharing this server, e.g. the Kobos).

**Gotcha hit setting this up**: if you're pre-seeding these files directly
instead of tapping through the menu (faster than typing a long password on
an e-ink keyboard), only edit them while KOReader is **not running** on the
device — it holds its own in-memory copy and will flush that back over your
on-disk edit on exit/autosave, silently reverting it. Confirmed this happen
once; fixed by sending the live `reader.lua` process a clean `SIGTERM` over
SSH before re-editing.

**Also gotcha**: the WebDAV start folder (`/koreader` here) has to actually
exist on the server *before* the Cloud storage+ account will load without
erroring — and if you're running the same self-hosted rclone backend, its
local-filesystem directory listing can go stale if the folder gets created
*after* the container starts (a container restart clears it).

## Secrets

- **WebDAV password** — not committed anywhere in this repo. Lives in
  `homelab-rclone/.env` (`WEBDAV_PASS`) on the machine that deployed the
  rclone container. Same password for every device connecting to this
  server, since it's one shared WebDAV account, not per-device.
