#!/bin/bash

sqlite3 /data/db.sqlite3 '.backup /data/db.bak'
tar -cvzf /backup.tar.gz /data

#Encrypt File and Upload to GitHub
echo "$PASS" | gpg --batch --yes --passphrase-fd 0 --cipher-algo AES256 --symmetric backup.tar.gz
GITHUB_USER="VijayakumarRavi"
REPO_NAME="IaC"
TAG="FLY-DATA"

# Check if release already exists
if curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/releases/tags/$TAG" | grep -q "tag_name"; then

    # Get the existing release ID if it already exists
    EXISTING_RELEASE_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/releases/tags/$TAG" | jq -r '.id')

    curl -s -X DELETE -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/octet-stream" \
        "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/releases/$EXISTING_RELEASE_ID" | jq
fi

# Create a new release if it doesn't exist
RELEASE_ID=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
    -d "{\"tag_name\": \"$TAG\",\"name\":\"Fly Data Backup\",\"body\":\"Encrypted backup of fly vault data backup\"}" \
    "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/releases" | jq -r '.id')


# Upload the backup.tar.gz file to the release
curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@/backup.tar.gz.gpg" \
    "https://uploads.github.com/repos/$GITHUB_USER/$REPO_NAME/releases/$RELEASE_ID/assets?name=backup-$(date +'%d_%m_%Y-%H_%M').tar.gz.gpg" \
    | jq -r '"Created backup at \"\(.created_at)\":  \"\(.name)\""'

rm *.tar.gz.gpg
rm *.tar.gz

# Ping healthchecks.io for monitoring
if [[ -n "$GITHUB_HC_PING_URL" ]]; then
    wget "${GITHUB_HC_PING_URL}" -O /dev/null
fi
