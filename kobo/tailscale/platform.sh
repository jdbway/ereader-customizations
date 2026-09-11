#!/bin/sh
# Sourced by every script in this folder. Detects which e-reader it's
# running on (by which known bin dir exists - same technique
# shared/koreader-plugins/networkextras.koplugin/main.lua already uses) and
# sets the paths/flags that differ by device. Deployment copies every file
# in this folder flat into that same bin dir on the device, so plain
# "$(dirname "$0")/platform.sh" sourcing works with no symlink resolution
# needed on-device - the symlinks only exist in this git repo for
# visibility, not on the actual hardware.
if [ -d /mnt/us/extensions/tailscale/bin ]; then
    PLATFORM=kindle
    BIN=/mnt/us/extensions/tailscale/bin
    SOCK=""
elif [ -d /mnt/onboard/.adds/tailscale/bin ]; then
    PLATFORM=kobo
    BIN=/mnt/onboard/.adds/tailscale/bin
    SOCK=/tmp/tailscaled.sock
else
    echo "platform.sh: neither Kindle nor Kobo tailscale bin dir found" >&2
    exit 1
fi

SOCK_ARG=""
[ -n "$SOCK" ] && SOCK_ARG="--socket=$SOCK"

TAILSCALE=$BIN/tailscale
TAILSCALED=$BIN/tailscaled

# eips_log's DEFAULT behavior is "write the line to $LOG" - every script
# that calls it needs that logging on every platform, not just Kindle.
# kindle-hooks.sh (Kindle only) overrides this to ALSO show it on the
# e-ink status line; Kobo keeps the plain log-only version. Caught
# 2026-09-08: the first version of this file made eips_log a true no-op by
# default, which silently dropped every status line ("Tailscale
# connected!", the final up/down result) on Kobo - the log file just went
# blank after the raw `tailscale up` output, with no failure indication.
# kindle_extra_start (the dns_watch.sh launcher) has no non-Kindle
# equivalent, so that one genuinely is a no-op elsewhere.
eips_log() { echo "$1" >> "$LOG"; }
kindle_extra_start() { :; }
[ -f "$BIN/kindle-hooks.sh" ] && . "$BIN/kindle-hooks.sh"
