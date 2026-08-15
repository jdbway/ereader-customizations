#!/bin/sh
# Uploads new KOReader screenshots to Immich as they appear.
SERVER=https://immich.truepob.com
API_KEY_FILE=/mnt/us/extensions/tailscale/bin/immich_api.key
DIR=/mnt/us/koreader/screenshots
STATE=/mnt/us/extensions/tailscale/bin/.immich_uploaded
LOG=/mnt/us/extensions/tailscale/bin/immich_upload_log.txt
DEVICE_ID=kindle-malbec

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
