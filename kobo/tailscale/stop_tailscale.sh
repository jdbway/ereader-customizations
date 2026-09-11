#!/bin/sh
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SELF_DIR/platform.sh"

LOG=$BIN/tailscale_stop_log.txt

echo "[$(date)] Stopping Tailscale..." > "$LOG"
eips_log "Stopping Tailscale..."

# `tailscale down` tears down the whole tailscale0 route table, including
# any accepted subnet route that would otherwise shadow the device's own
# directly-connected LAN interface route while accept-routes is on (see
# start_tailscale.sh's up.args note) - this alone is what "fixes the
# routes" on disconnect, no separate cleanup needed here.
#
# --accept-risk=lose-ssh: without it, `tailscale down` silently no-ops
# ("aborted, no changes made") whenever invoked over a session whose client
# IP is itself a tailnet address. First confirmed 2026-09-08 on the Kindle
# and gated to that platform on the assumption it was Kindle-specific; the
# very next test, on Kobo, hit the identical abort. It's a property of the
# `tailscale` CLI's own safety check, not of either device, so it's applied
# unconditionally now.
if "$TAILSCALE" $SOCK_ARG down --accept-risk=lose-ssh >> "$LOG" 2>&1; then
    eips_log "Tailscale stopped"
else
    eips_log "tailscale down failed - check log"
fi
