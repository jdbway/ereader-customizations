#!/usr/bin/env bash
# Pushes a backup_koreader.sh snapshot (plugins/ + settings/*.lua) onto a
# target device at the matching paths under KOReader's install root.
# Meant for a fresh or replacement Kindle that already has KOReader
# installed -- this overwrites plugins/ and the top-level settings/*.lua
# files in place, it does not merge or back up what's already there first.
#
# Does NOT touch boot hooks (kor.conf / tailscale.conf) -- those live on
# the read-only root filesystem and need the manual mntroot rw dance in
# kindle/boot-hooks/README.md. Restart KOReader (or reboot) afterward to
# pick up the restored plugins/settings.
#
# Usage: ./restore_koreader.sh <snapshot-dir> [user@host]
#   snapshot-dir defaults to nothing -- always pass one explicitly, so you
#   restore the snapshot you mean to, not whatever's newest.
#   host defaults to $KINDLE_HOST, then root@kindle.
set -euo pipefail

SNAPSHOT="${1:?Usage: restore_koreader.sh <snapshot-dir> [user@host]}"
HOST="${2:-${KINDLE_HOST:-root@kindle}}"
REMOTE_KOREADER="${KINDLE_KOREADER_PATH:-/mnt/base-us/koreader}"

[ -d "$SNAPSHOT/plugins" ] || {
  echo "No plugins/ directory in '$SNAPSHOT' -- wrong snapshot dir?" >&2
  exit 1
}

echo "Pushing plugins/ to $HOST:$REMOTE_KOREADER/plugins ..."
tar cf - -C "$SNAPSHOT" plugins | ssh "$HOST" "cd '$REMOTE_KOREADER' && tar xf -"

if [ -d "$SNAPSHOT/settings" ]; then
  echo "Pushing settings/*.lua to $HOST:$REMOTE_KOREADER/settings ..."
  tar cf - -C "$SNAPSHOT/settings" . | ssh "$HOST" "cd '$REMOTE_KOREADER/settings' && tar xf -"
fi

echo
echo "Done. Restart KOReader on the device (or reboot) to pick up the"
echo "restored plugins/settings. Boot hooks are NOT handled by this"
echo "script -- see kindle/boot-hooks/README.md for those."
