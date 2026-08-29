# Kindle setup

See **[BASE_SETUP.md](BASE_SETUP.md)** for the full component list,
install order, and per-device specifics (gestures, chip bar, secrets,
boot hooks) — this is the canonical reference for what's actually
installed and configured on the physical Kindle Paperwhite 5 right now.

Kindle Paperwhite 5, jailbroken, running KOReader + Tailscale + a
self-hosted Calibre-Web NextGen library. Goal: reach the OPDS catalog and
sync progress over the tailnet from anywhere, with the Amazon framework
disabled most of the time to save power.

This folder mirrors what's actually installed and configured on that
physical device right now — every plugin listed in `BASE_SETUP.md`,
`koreader-settings/`, and `boot-hooks/` should match what's really on the
Kindle. When the device changes (a plugin added/removed, a setting
changed), this folder should be re-synced from it, not just left
describing an earlier state — see `../backup/`'s `backup_koreader.sh` for
pulling a raw snapshot to diff against.
