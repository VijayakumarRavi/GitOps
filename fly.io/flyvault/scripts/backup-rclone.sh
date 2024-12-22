#!/bin/bash

sqlite3 /data/db.sqlite3 '.backup /data/db.bak'
tar -czvf /backup.tar.gz /data

# Encrypt backup and Upload to Cloudflare R2
echo "$PASS" | gpg --batch --yes --passphrase-fd  0 --cipher-algo AES256 --symmetric backup.tar.gz

# Define the remote name and path in Cloudflare R2 where you want to store the backup
FILE_NAME="vault-backup-$(date +'%d_%m_%Y-%H_%M').tar.gz.gpg"
mv backup.tar.gz.gpg $FILE_NAME

RCLONE_BACKBLAZE_REMOTE="backblaze:backuprest/vaultwarden"
RCLONE_CLOUDFLARE_REMOTE="Cloudflare:vaultwarden"

# Perform the backup
rclone -v copy ./$FILE_NAME $RCLONE_CLOUDFLARE_REMOTE
rclone -v copy ./$FILE_NAME $RCLONE_BACKBLAZE_REMOTE

# Remove local files
rm *.tar.gz.gpg
rm *.tar.gz

# Ping healthchecks.io for monitoring
if [[ -n "$RCLONE_HC_PING_URL" ]]; then
    wget "${RCLONE_HC_PING_URL}" -O /dev/null
fi
