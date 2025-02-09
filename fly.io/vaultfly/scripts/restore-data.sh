#!/usr/bin/env bash

# Check for filename argument
FILE_NAME=$1
if [[ -z "$FILE_NAME" ]]; then
    echo "No argument passed, so finding the latest backup using rclone"
    FILE_NAME=$(rclone lsl Cloudflare:vaultwarden/ | awk '{print $NF}' | tail -n 1)
    echo "Found backup $FILE_NAME in Cloudflare"
fi

# remove old data if present
rm -rf /data

# Download from rclone
echo "Downloading $FILE_NAME"
rclone copy -v Cloudflare:vaultwarden/"$FILE_NAME" .
#rclone copy backblaze:backuprest/vaultwarden/$FILE_NAME .

# Decrypt the backup file
echo "$PASS" | gpg --batch --yes --passphrase-fd 0 -o backup.tar.gz -d $FILE_NAME

# Extract the tar file
tar -xzvf backup.tar.gz -C /

# Restart all the processes to apply the restoration
overmind interrupt
overmind restart

rm *.tar.gz
rm $FILE_NAME
