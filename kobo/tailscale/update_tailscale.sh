#!/bin/sh
# Adapted 2026-09-08 from the Kobo version (the only one that existed in
# this repo) by parametrizing the install path through platform.sh. Proven
# on Kobo; NOT yet run on a Kindle - the fetch/extract/swap logic is
# generic POSIX (wget, tar, find), so it should work, but this hasn't been
# verified live there.
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SELF_DIR/platform.sh"

INSTALL_DIR=$BIN
TMP_DIR=$BIN/tmp_update
LOG=$INSTALL_DIR/update_log.txt
DONE_MARKER=$INSTALL_DIR/update_tailscale.done
RESULT_FILE=$INSTALL_DIR/update_result.txt
ARCH=arm
VERSIONS_TO_TRY=3

log() {
    echo "$1" >> "$LOG"
}

# Whatever exit path this script takes (success, "already up to date", or any
# of the error cases below), the caller (networkextras.koplugin) needs a
# reliable way to know it's done and what happened - it polls for
# DONE_MARKER and then reads RESULT_FILE, since the old approach (backgrounding
# this script and discarding its output entirely) left the UI showing a fixed
# "Checking for updates..." toast forever, regardless of outcome.
rm -f "$DONE_MARKER" "$RESULT_FILE"
trap 'tail -1 "$LOG" > "$RESULT_FILE"; touch "$DONE_MARKER"' EXIT

echo "[$(date)] Starting install/update..." > "$LOG"
eips_log "Checking for Tailscale updates..."

# Determine whether this is a fresh install or an upgrade
if [ -f "$INSTALL_DIR/tailscale" ]; then
    CURRENT=$("$INSTALL_DIR/tailscale" version 2>/dev/null | head -1)
else
    CURRENT="none"
fi
echo "Installed version : $CURRENT" >> "$LOG"

# Resolve the latest release tag from the GitHub API. Uses wget, not curl --
# BusyBox wget on these devices handles TLS fine and curl isn't guaranteed
# to be installed.
log "Checking latest Tailscale version..."
LATEST_VERSIONS=$(wget -q -O- -U "tailscale-koreader-updater/1.0" \
    "https://api.github.com/repos/tailscale/tailscale/releases?per_page=${VERSIONS_TO_TRY}" 2>>"$LOG" \
    | sed -e 's/[{}]/''/g' | awk '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')

if [ -z "$LATEST_VERSIONS" ]; then
    log "ERROR: Could not determine latest versions. Check Wi-Fi connectivity."
    eips_log "Update check failed - no Wi-Fi?"
    exit 1
fi

echo -e "Latest $VERSIONS_TO_TRY versions:\n$LATEST_VERSIONS" >> "$LOG"

# Iterate through release tags from the GitHub API until one with a 200 is found
for version in $LATEST_VERSIONS; do
    LATEST=$version
    echo "Checking $LATEST" >> "$LOG"
    URL="https://pkgs.tailscale.com/stable/tailscale_${LATEST}_${ARCH}.tgz"
    if wget --spider -q "$URL" 2>>"$LOG"; then
        echo "Using $LATEST" >> "$LOG"
        break
    else
        echo "Version $LATEST does not appear to have been built for ARM. Trying next version" >> "$LOG"
        continue
    fi
done

echo "Latest version    : $LATEST" >> "$LOG"

if [ "$CURRENT" = "$LATEST" ]; then
    log "Already up to date (v$LATEST). Nothing to do."
    eips_log "Tailscale already up to date (v$LATEST)"
    exit 0
fi

if [ "$CURRENT" = "none" ]; then
    log "No binaries found. Installing v$LATEST..."
else
    log "Updating $CURRENT -> $LATEST..."
fi

mkdir -p "$TMP_DIR"
URL="https://pkgs.tailscale.com/stable/tailscale_${LATEST}_${ARCH}.tgz"
echo "Downloading $URL..." >> "$LOG"
log "Downloading tailscale v$LATEST (~31 MB). Please wait..."
eips_log "Downloading Tailscale v$LATEST (~31MB)..."
wget -q -O "$TMP_DIR/ts.tgz" -U "tailscale-koreader-updater/1.0" "$URL" 2>>"$LOG"

if [ $? -ne 0 ] || [ ! -s "$TMP_DIR/ts.tgz" ]; then
    log "ERROR: Download failed. Check Wi-Fi connectivity and try again."
    eips_log "Download failed - check Wi-Fi"
    rm -rf "$TMP_DIR"
    exit 1
fi

eips_log "Installing v$LATEST..."
tar -xzf "$TMP_DIR/ts.tgz" -C "$TMP_DIR" 2>>"$LOG"

TS_BIN=$(find "$TMP_DIR" -type f -name "tailscale"  | head -1)
TSD_BIN=$(find "$TMP_DIR" -type f -name "tailscaled" | head -1)

if [ -z "$TS_BIN" ] || [ -z "$TSD_BIN" ]; then
    log "ERROR: Could not find binaries in tarball."
    echo "tailscale  : ${TS_BIN:-not found}" >> "$LOG"
    echo "tailscaled : ${TSD_BIN:-not found}" >> "$LOG"
    eips_log "Update failed - bad archive, check log"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Back up existing binaries before replacing (only when upgrading)
if [ "$CURRENT" != "none" ]; then
    [ -f "$INSTALL_DIR/tailscale" ]  && cp "$INSTALL_DIR/tailscale"  "$INSTALL_DIR/tailscale.bak"
    [ -f "$INSTALL_DIR/tailscaled" ] && cp "$INSTALL_DIR/tailscaled" "$INSTALL_DIR/tailscaled.bak"
    echo "Backed up existing binaries as *.bak" >> "$LOG"
fi

cp "$TS_BIN"  "$INSTALL_DIR/tailscale"  && chmod +x "$INSTALL_DIR/tailscale"  || { log "ERROR: Failed to install tailscale.";  eips_log "Update failed - couldn't install tailscale binary"; rm -rf "$TMP_DIR"; exit 1; }
cp "$TSD_BIN" "$INSTALL_DIR/tailscaled" && chmod +x "$INSTALL_DIR/tailscaled" || { log "ERROR: Failed to install tailscaled."; eips_log "Update failed - couldn't install tailscaled binary"; rm -rf "$TMP_DIR"; exit 1; }

rm -rf "$TMP_DIR"

if [ "$CURRENT" = "none" ]; then
    log "Install complete: v$LATEST."
    eips_log "Tailscale v$LATEST installed - Start Tailscale to use it"
else
    log "Update complete: v$LATEST successfully installed."
    eips_log "Tailscale updated to v$LATEST - Stop then Start to apply"
fi
