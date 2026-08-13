# cwasync (NextGen Progress Sync) config — not backed up as a file

Unlike the other plugins here, `cwasync.koplugin` doesn't use its own
settings file — it stores `server`/`username`/`password` inside KOReader's
global `settings.reader.lua`, which also holds a large amount of unrelated,
device-specific state (window position, recently-opened files, etc.). That
file isn't a clean "config to copy to a new device" the way `wallabag.lua`
or `opds.lua` are, so it's not vendored here, and its password wasn't
extracted into this repo at all (not even blanked out — never pulled off
the device in the first place).

To reproduce this plugin's config on a new device, in KOReader's main menu
under **NextGen Progress Sync**:

1. **Set NextGen Server** → `https://calibre.truepob.com` (no path suffix —
   the plugin appends `/kosync` itself internally).
2. Log in with your Calibre-Web NextGen username/password.
3. Optionally enable **Sync KOReader highlights** (off by default — see
   `../README.md` for why it's opt-in and still a manual "Sync highlights
   now" action, not automatic).
