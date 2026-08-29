#!/usr/bin/env bash
# Pushes a backup_koreader.sh snapshot (plugins/ + settings/*.lua) onto a
# target device (set DEVICE=kindle or DEVICE=kobo, see backup_koreader.sh)
# at the matching paths under KOReader's install root, which must already
# have KOReader installed -- this overwrites plugins/ and the top-level
# settings/*.lua files in place, it does not merge or back up what's
# already there first.
#
# Does NOT touch boot hooks. On Kindle that's kor.conf/tailscale.conf on
# the read-only root filesystem, needing the manual mntroot rw dance in
# kindle/boot-hooks/README.md. On Kobo there ARE no repo-managed boot
# hooks by design -- see kobo/BASE_SETUP.md's "do not repeat the
# auto-start incident" for why (a boot-time KOReader auto-launch attempt
# factory-reset the device). Restart KOReader (or reboot) afterward to
# pick up the restored plugins/settings -- on Kobo that means closing and
# reopening it via NickelMenu, not a boot-file change.
#
# Usage: ./restore_koreader.sh <snapshot-dir> [user@host]
#   snapshot-dir defaults to nothing -- always pass one explicitly, so you
#   restore the snapshot you mean to, not whatever's newest.
#   host defaults by DEVICE (kindle/kobo, see backup_koreader.sh) to
#   $KINDLE_HOST/root@kindle or $KOBO_HOST/root@kobo-sabrina.
set -euo pipefail

SNAPSHOT="${1:?Usage: restore_koreader.sh <snapshot-dir> [user@host]}"
DEVICE="${DEVICE:-kindle}"
case "$DEVICE" in
  kindle)
    HOST="${2:-${KINDLE_HOST:-root@kindle}}"
    REMOTE_KOREADER="${KINDLE_KOREADER_PATH:-/mnt/base-us/koreader}"
    ;;
  kobo)
    HOST="${2:-${KOBO_HOST:-root@kobo-sabrina}}"
    REMOTE_KOREADER="${KOBO_KOREADER_PATH:-/mnt/onboard/.adds/koreader}"
    ;;
  *)
    echo "Unknown DEVICE '$DEVICE' -- expected 'kindle' or 'kobo'" >&2
    exit 1
    ;;
esac

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
echo "script -- see kindle/boot-hooks/README.md (Kindle) or"
echo "kobo/BASE_SETUP.md (Kobo, deliberately has none) for those."
