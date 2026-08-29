#!/bin/sh
# Uploads new KOReader screenshots to Immich as they appear. Works
# unmodified on both Kindle and Kobo -- auto-detects install layout by
# mount point rather than needing a per-device copy, and derives a unique
# device id from the tailnet hostname already set in up.args (rather than
# a separate hardcoded DEVICE_ID per device).
SERVER=https://immich.truepob.com

if [ -d /mnt/us ]; then
    BASE=/mnt/us/extensions/tailscale/bin
    DIR=/mnt/us/koreader/screenshots
elif [ -d /mnt/onboard ]; then
    BASE=/mnt/onboard/.adds/tailscale/bin
    DIR=/mnt/onboard/.adds/koreader/screenshots
else
    echo "immich_upload_watch.sh: unrecognized device layout (neither /mnt/us nor /mnt/onboard found)" >&2
    exit 1
fi

API_KEY_FILE=$BASE/immich_api.key
STATE=$BASE/.immich_uploaded
LOG=$BASE/immich_upload_log.txt
UP_ARGS_FILE=$BASE/up.args

# Reuse the tailnet hostname already configured for `tailscale up` so this
# script doesn't need its own separate per-device identifier.
DEVICE_ID="unknown-device"
if [ -f "$UP_ARGS_FILE" ]; then
    parsed=$(sed -n 's/.*--hostname=\([^ ]*\).*/\1/p' "$UP_ARGS_FILE")
    [ -n "$parsed" ] && DEVICE_ID="$parsed"
fi

API_KEY=$(cat "$API_KEY_FILE" 2>/dev/null)

while true; do
    for f in "$DIR"/*.png; do
        [ -f "$f" ] || continue
        name=$(basename "$f")
        if ! grep -qxF "$name" "$STATE" 2>/dev/null; then
            ts=$(date -u -r "$f" +%Y-%m-%dT%H:%M:%S.000Z)
            code=$(curl -s -o /tmp/immich_resp.json -w '%{http_code}' \
                -X POST "$SERVER/api/assets" \
                -H "x-api-key: $API_KEY" \
                -F "deviceAssetId=${name}" \
                -F "deviceId=${DEVICE_ID}" \
                -F "fileCreatedAt=${ts}" \
                -F "fileModifiedAt=${ts}" \
                -F "assetData=@${f}")
            if [ "$code" = "200" ] || [ "$code" = "201" ]; then
                echo "$name" >> "$STATE"
                echo "[$(date)] uploaded $name ($code)" >> "$LOG"
            else
                echo "[$(date)] FAILED $name ($code): $(cat /tmp/immich_resp.json 2>/dev/null)" >> "$LOG"
            fi
        fi
    done
    sleep 30
done
