# Bookshelf home screen — device-agnostic setup

This covers the parts of configuring `bookshelf.koplugin`'s home screen that
are pure plugin behavior, identical on every device it's installed on
(confirmed on both Kindle and Kobo). Device-specific specifics — which
gesture corner, exact chip contents, download folder paths — live in each
device's own `BASE_SETUP.md`, which links back here for the mechanism
instead of repeating it.

## Gesture to open the start menu

Settings → Taps and Gestures → Gesture Manager → Tap Corner → pick a
corner → set to General → **Bookshelf: open start menu**. Check whether
that corner already has a default action assigned (e.g. frontlight
toggle) — assigning the new action doesn't automatically clear an
existing one, so uncheck it explicitly if present.

## Start menu contents

Whichever items appear in the start menu opened via that gesture are
configured per-device (`start_menu_items` in `settings/bookshelf.lua`) —
no single "right" answer, see each device's `BASE_SETUP.md` for its
current set.

## Chip bar (Home / Recent / Calibre, etc.)

Long-press an unwanted chip → trash icon → confirm. Tap **+** → Chip
source → **OPDS catalog...** → pick the configured server from the list
(populated from whatever OPDS catalogs are configured in KOReader's OPDS
settings). Takes under a minute by hand on a new device.

It can also be done as a pure file edit: merge a `tabs` key directly into
the device's `settings/bookshelf.lua` (that file also holds unrelated
keys like `start_menu_items` — don't overwrite the whole file). The one
non-obvious part is `source.id` for an OPDS chip: it's not the catalog
URL itself but a `djb2`-style hash of it (`lib/bookshelf_opds_source.lua`,
`OpdsSource.serverKey()`) — `filter = {}` and `sort_priority = {}` for
OPDS chips (they don't get a client-side sort; feed order is
authoritative, per `SOURCE_SORT_DEFAULTS.opds` in
`lib/bookshelf_chip_editor.lua`). To compute the key for a catalog URL,
run this on-device (needs KOReader's bundled `luajit`, matches the real
algorithm exactly rather than reimplementing it — a from-scratch
reimplementation attempt during the Kobo setup produced two different
wrong answers before this approach was used instead):
```sh
./luajit -e '
local url = "PUT_THE_OPDS_URL_HERE"
local h = 5381
for i = 1, #url do h = (h * 33 + url:byte(i)) % 4294967296 end
print(string.format("%08x", h))'
```
(run from KOReader's install directory, so `./luajit` resolves — see each
device's `BASE_SETUP.md` for that path). Back up the device's current
`settings/bookshelf.lua` before overwriting it, and restart KOReader
afterward so it picks up the change from disk rather than overwriting it
back with whatever's still cached in memory from the running session.

## Per-chip download folder

OPDS downloads made through an OPDS-source chip default to KOReader's own
global "last used" download folder if the chip doesn't specify one —
which is whatever folder something else downloaded to most recently
(Wallabag's folder, if that ran first), not necessarily the library root.
**Set `download_dir` explicitly on every OPDS chip** to avoid this — don't
rely on the global fallback landing in the right place by luck.

**In the UI**: long-press the chip → **Edit** (not the trash icon) →
there's a download-folder option once the chip's source is OPDS (not
shown for the built-in Home/Recent/etc. sources) → pick the folder →
Save.

**As a file edit**: add `["download_dir"] = "<path>"` directly to the
chip's table in the `tabs` key.

**Known trap, confirmed on the 2026-08-29 Kobo rebuild**: creating a chip
via long-press → **+** → OPDS catalog does **not** ask for a download
folder — only the separate **Edit** step does. It's easy to create a chip,
have it look and work fine, and never notice `download_dir` was never
set until downloads start landing in the wrong folder. If OPDS downloads
land somewhere unexpected, check whether `download_dir` is actually set
on the chip before assuming something else broke.

## Micromodules (home-screen tile grid)

Reached via the grid button on Bookshelf's bottom bar.
(`bookshelf.koplugin/micromodules/*.lua` — this is where new module types
get added if one's ever written).

- Long-press an existing module → **remove/trash** it, or **+** on an
  empty slot / next to an existing module to add one.
- Long-press any module → its own settings dialog (if it has one) for
  module-specific options.
- **Reading streak** module: its **Tap action** setting offers "Reading
  insight" (opens `readinginsights.koplugin`'s popup —
  **`readinginsights.koplugin` must be installed** or the tap silently
  does nothing despite the setting showing as selected correctly, since
  it calls `Dispatcher:execute({ reading_insights_popup = true })` and
  that Dispatcher action simply doesn't exist without the plugin) or
  "Reading calendar" (KOReader's own built-in stats calendar view, no
  extra plugin needed).
