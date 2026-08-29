#!/usr/bin/env bash
# Pulls a full "reinstall this device" snapshot off a KOReader device --
# the whole plugins/ install plus every top-level settings/*.lua config
# file (global settings.reader.lua plus the per-feature ones already
# catalogued in kindle/koreader-settings/README.md). Skips everything
# else under settings/ on purpose: reading statistics, per-book progress
# (docsettings/), caches, history, and the stock (unused) Vocabulary
# Builder db are device-specific junk, not install/config -- see that
# README for the full reasoning. Also skips book-specific data entirely
# (no epubs/books, no VocabDeck card databases) -- this is an app + addon
# backup, not a library backup.
#
# This is deliberately separate from kindle/koreader-plugins/ and
# kindle/koreader-settings/ elsewhere in this repo, which are the
# hand-curated, secret-scrubbed, documented subset meant for browsing and
# committing. This script's output is a raw personal snapshot instead --
# see backup/README.md before doing anything with it beyond restoring it
# straight back to a device.
#
# One script for both devices -- set DEVICE=kindle (default) or DEVICE=kobo,
# which picks the right default host alias and remote KOReader path. Same
# script, not a forked backup_kobo.sh, because the only real difference
# between the two is those two defaults.
#
# Usage: DEVICE=kobo ./backup_koreader.sh [output-dir]
#        KINDLE_HOST=root@kindle ./backup_koreader.sh [output-dir]
# Requires: an SSH host alias/IP that's actually reachable and a plain
# `ssh <host>` that works with no extra flags -- put port/key/
# IdentitiesOnly config in ~/.ssh/config under that alias rather than
# passing flags here. Kindle: Tailscale SSH on port 22, or KOReader's own
# dropbear on port 2222 (see kindle/README.md's "SSH access"). Kobo:
# KOReader's own dropbear on port 2222 over LAN -- Tailscale is a manual
# toggle there (battery reasons, see kobo/BASE_SETUP.md), so don't rely on
# its MagicDNS name being up; point the `kobo-sabrina` alias at the LAN IP
# directly, e.g.:
#   Host kobo-sabrina
#       HostName 192.168.5.93
#       Port 2222
#       User root
set -euo pipefail

DEVICE="${DEVICE:-kindle}"
case "$DEVICE" in
  kindle)
    HOST="${KINDLE_HOST:-root@kindle}"
    REMOTE_KOREADER="${KINDLE_KOREADER_PATH:-/mnt/base-us/koreader}"
    ;;
  kobo)
    HOST="${KOBO_HOST:-root@kobo-sabrina}"
    REMOTE_KOREADER="${KOBO_KOREADER_PATH:-/mnt/onboard/.adds/koreader}"
    ;;
  *)
    echo "Unknown DEVICE '$DEVICE' -- expected 'kindle' or 'kobo'" >&2
    exit 1
    ;;
esac
OUT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$DEVICE/$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$OUT/settings"

echo "Pulling plugins/ (full install -- all plugin code, plus any config/keys" \
     "a plugin keeps inside its own folder, e.g. VocabDeck's vocabdeck_apikeys.lua)..."
ssh "$HOST" "cd '$REMOTE_KOREADER' && tar cf - plugins" | tar xf - -C "$OUT"

echo "Pulling top-level settings/*.lua (global + per-feature config only)..."
ssh "$HOST" "cd '$REMOTE_KOREADER/settings' && tar cf - \$(find . -maxdepth 1 -name '*.lua')" \
  | tar xf - -C "$OUT/settings"

echo
echo "Done. Snapshot at $OUT"
echo "This lives under backup/$DEVICE/, which is gitignored on purpose --"
echo "it contains real API keys and sync credentials in plaintext. See"
echo "backup/README.md before committing anything from it anywhere."
