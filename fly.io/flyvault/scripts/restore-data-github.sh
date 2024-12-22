#!/usr/bin/env bash

# Authorize to GitHub to get the latest release tar.gz
# Requires: oauth token, https://help.github.com/articles/creating-an-access-token-for-command-line-use/
# Requires: jq package to parse json

# GitHub repository information
OWNER="VijayakumarRavi"
REPO="IaC"

# Concatenate the values together for a
API_URL="https://$GITHUB_TOKEN:@api.github.com/repos/$OWNER/$REPO"

# Get the latest backup file details
ASSET=$(curl -s "$API_URL/releases/latest" | jq -r '.assets[] | select(.name | test("backup-.*\\.tar\\.gz\\.gpg")) | {name: .name, id: .id}')

# Extract the name and download URL of the latest backup file
FILE_NAME=$(echo "$ASSET" | jq -r '.name')
ASSET_ID=$(echo "$ASSET" | jq -r '.id')

# Check if the asset URL was found
if [[ -z "$ASSET_ID" || "$ASSET_ID" == "null" ]]; then
    echo "Error: Could not find any backup file in the latest release. Asset ID: $ASSET_ID"
    exit 1
fi

# curl does not allow overwriting file from -O, nuke
rm *.tar.gz.gpg
rm *.tar.gz
rm -rf /data

# curl: Download the asset
# -O: Use name provided from endpoint
# -J: "Content Disposition" header, in this case "attachment"
# -L: Follow links, we actually get forwarded in this request
# -H "Accept: application/octet-stream": Tells api we want to dl the full binary
curl -O -J -L -H "Accept: application/octet-stream" "$API_URL/releases/assets/$ASSET_ID"

echo "Downloaded $FILE_NAME successfully."

# Decrypt the backup file
echo "$PASS" | gpg --batch --yes --passphrase-fd 0 -o backup.tar.gz -d *.tar.gz.gpg

# Extract the tar file
tar -xzvf backup.tar.gz -C /

# Restart all the processes to apply the restoration
overmind interrupt
overmind restart

rm *.tar.gz.gpg
rm *.tar.gz
