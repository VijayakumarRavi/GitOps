#!/bin/sh

# Ensure we are in the /app folder
cd /app

PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Check if the group with PGID exists; if not, create it
if ! getent group pocket-id-group > /dev/null 2>&1; then
    echo "Creating group $PGID..."
    addgroup -g "$PGID" pocket-id-group
fi

# Check if a user with PUID exists; if not, create it
if ! id -u pocket-id > /dev/null 2>&1; then
    if ! getent passwd "$PUID" > /dev/null 2>&1; then
        echo "Creating user $PUID..."
        adduser -u "$PUID" -G pocket-id-group pocket-id > /dev/null 2>&1
    else
        # If a user with the PUID already exists, use that user
        existing_user=$(getent passwd "$PUID" | cut -d: -f1)
        echo "Using existing user: $existing_user"
    fi
fi

# Change ownership of the /app/data directory
mkdir -p /app/data
find /app/data \( ! -group "${PGID}" -o ! -user "${PUID}" \) -exec chown "${PUID}:${PGID}" {} +
find /app/lldap \( ! -group "${PGID}" -o ! -user "${PUID}" \) -exec chown "${PUID}:${PGID}" {} +

# create restic log dir and give ownership
mkdir -p /var/log/restic/ && chown ${PUID}:${PGID} /var/log/restic/

LLDAP_CONFIG_FILE=/app/data/lldap_config.toml

if [[ ! -f "$LLDAP_CONFIG_FILE" ]]; then
  echo "[entrypoint] Copying the default config to $LLDAP_CONFIG_FILE"
  echo "[entrypoint] Edit this file to configure LLDAP."
  cp /app/lldap/lldap_config.docker_template.toml $LLDAP_CONFIG_FILE
fi

if [[ ! -r "$LLDAP_CONFIG_FILE" ]]; then
  echo "[entrypoint] Config file is not readable. Check the permissions"
  exit 1;
fi

# Start background processes
echo "Starting pocket-id..."
(cd /app && sleep 5 && su-exec "$PUID:$PGID" /app/pocket-id) &
p1=$!

echo "Starting lldap..."
(cd /app/lldap && su-exec "$PUID:$PGID" /app/lldap/lldap run --config-file /app/data/lldap_config.toml) &
p2=$!

sleep 10
echo "Starting cloudflared tunnel..."
su-exec "$PUID:$PGID" cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN" &
p3=$!

# Monitor processes
wait -n $p1 $p2 $p3
exit $?
