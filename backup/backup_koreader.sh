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
# Usage: KINDLE_HOST=root@kindle ./backup_koreader.sh [output-dir]
# Requires: an SSH host alias/IP that's actually reachable (Tailscale SSH
# on port 22, or KOReader's own dropbear on port 2222 -- see the "SSH
# access" section of kindle/README.md) and a plain `ssh <host>` that works
# with no extra flags (put port/key/IdentitiesOnly config in ~/.ssh/config
# under that alias rather than passing flags here).
set -euo pipefail

HOST="${KINDLE_HOST:-root@kindle}"
REMOTE_KOREADER="${KINDLE_KOREADER_PATH:-/mnt/base-us/koreader}"
OUT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kindle/$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$OUT/settings"

echo "Pulling plugins/ (full install -- all plugin code, plus any config/keys" \
     "a plugin keeps inside its own folder, e.g. VocabDeck's vocabdeck_apikeys.lua)..."
ssh "$HOST" "cd '$REMOTE_KOREADER' && tar cf - plugins" | tar xf - -C "$OUT"

echo "Pulling top-level settings/*.lua (global + per-feature config only)..."
ssh "$HOST" "cd '$REMOTE_KOREADER/settings' && tar cf - \$(find . -maxdepth 1 -name '*.lua')" \
  | tar xf - -C "$OUT/settings"

echo
echo "Done. Snapshot at $OUT"
echo "This lives under backup/kindle/, which is gitignored on purpose --"
echo "it contains real API keys and sync credentials in plaintext. See"
echo "backup/README.md before committing anything from it anywhere."
