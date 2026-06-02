#!/bin/bash

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Info: Starting up...${NC}"

restic self-update || true
if restic snapshots > /dev/null 2>&1; then
    restic restore --overwrite if-newer --target=/ --verbose=2 --cleanup-cache latest
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Restic restore failed. Please check your restic configuration.${NC}"
        exit 1
    else
        echo -e "${GREEN}Info: Restic restore completed successfully.${NC}"
    fi
else
    echo -e "${YELLOW}Warn: No restic snapshots found, skipping restore.${NC}"
fi

PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Create user/group if they don't exist
if ! getent group vault-group > /dev/null 2>&1; then
    echo "Creating group $PGID..."
    groupadd -g "$PGID" vault-group
fi
if ! id -u vaultuser > /dev/null 2>&1; then
    echo "Creating user $PUID..."
    useradd -u "$PUID" -g "$PGID" -M -d /home/vaultuser -s /bin/false vaultuser
fi

# Ensure restic runtime dirs are writable by the backup user
mkdir -p /var/log/restic/ /home/vaultuser
chown -R "$PUID:$PGID" /var/log/restic/ /home/vaultuser /data /restic.sh

# Start background processes
echo -e "${GREEN}Info: Starting vaultwarden...${NC}"
gosu "$PUID:$PGID" /start.sh &
p1=$!

echo -e "${GREEN}Info: Starting backup cron...${NC}"
echo "1 * * * * /restic.sh" > /crontab
chown "$PUID:$PGID" /crontab
gosu "$PUID:$PGID" supercronic /crontab &
p2=$!

sleep 10
echo -e "${GREEN}Info: Starting cloudflared tunnel...${NC}"
gosu "$PUID:$PGID" cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN" &
p3=$!

# Monitor processes
wait -n $p1 $p2 $p3
exit $?
