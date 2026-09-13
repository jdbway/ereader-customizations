#!/bin/sh
# Enable SSH while the device is in Nickel (stock Kobo firmware), so a
# wedged/unresponsive Nickel can be inspected without KOReader running.
#
# Why this is needed: KOReader's SSH.koplugin bundles its own dropbear on
# port 2222, but that server is a child of KOReader and dies when KOReader
# exits -- so in Nickel there is no SSH at all by default. Kobo's stock
# firmware *does* ship OpenSSH (/usr/sbin/sshd) with host keys and an
# /etc/init.d/ssh boot hook, but it is gated behind a file and its default
# config forces a password-setup prompt on every root login, which breaks
# non-interactive/automation use. This script un-gates it, makes it
# key-only, and starts it.
#
# Idempotent: safe to re-run. Run as root on the device.
#
# Conventions on this device:
#   - / is ext4 and writable (so /etc/ssh/sshd_config edits persist, but a
#     firmware update may overwrite them -- re-run this script after one).
#   - root's home is /, so AuthorizedKeysFile .ssh/authorized_keys means
#     /.ssh/authorized_keys.
#   - The agent + all human keys already live in KOReader's
#     settings/SSH/authorized_keys; we reuse that file so key management
#     stays in one place.

set -e

SSHD_CONFIG=/etc/ssh/sshd_config
AUTHORIZED_KEYS=/.ssh/authorized_keys
KO_KEYS=/mnt/onboard/.adds/koreader/settings/SSH/authorized_keys

# 1. Authorized keys (reuse KOReader's, which already holds the fleet keys).
mkdir -p /.ssh
chmod 700 /.ssh
if [ -f "$KO_KEYS" ]; then
    cp -f "$KO_KEYS" "$AUTHORIZED_KEYS"
else
    echo "WARNING: $KO_KEYS not found; populate $AUTHORIZED_KEYS by hand" >&2
fi
chmod 600 "$AUTHORIZED_KEYS"

# 2. Patch sshd_config, key-only, no forced password-setup command.
#    First match wins for most keywords in OpenSSH, so PermitEmptyPasswords
#    must be rewritten in place (appending a later 'no' would be ignored).
if ! grep -q 'Nickel SSH' "$SSHD_CONFIG"; then
    sed -e 's|^[[:space:]]*ForceCommand /etc/ssh/initial_ssh_setup.sh|# ForceCommand (disabled for Nickel SSH: key-only, non-interactive)|' \
        -e 's|^PermitEmptyPasswords yes|PermitEmptyPasswords no|' \
        "$SSHD_CONFIG" > "$SSHD_CONFIG.new"
    grep -q '^PasswordAuthentication no' "$SSHD_CONFIG.new" || \
        printf '\nPasswordAuthentication no\n' >> "$SSHD_CONFIG.new"
    mv "$SSHD_CONFIG.new" "$SSHD_CONFIG"
fi

# 3. Runtime dirs sshd expects (same as /etc/init.d/ssh).
[ -d /var/empty ] || { mkdir -p /var/empty; chmod 755 /var/empty; }
[ -d /dev/pts ] || { mkdir -p /dev/pts; mount -t devpts none /dev/pts -o mode=0622; }

# 4. Start now, and un-gate the boot hook so it starts on every boot.
pgrep -f '/usr/sbin/sshd' >/dev/null 2>&1 || /usr/sbin/sshd
[ -e /mnt/onboard/.kobo/ssh-disabled ] && \
    mv /mnt/onboard/.kobo/ssh-disabled /mnt/onboard/.kobo/ssh-enabled

echo "Nickel SSH enabled on port 22 (key-only). Test: ssh -l root <ip>"
