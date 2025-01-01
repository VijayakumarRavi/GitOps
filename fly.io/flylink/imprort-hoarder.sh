
#!/bin/bash

# Configuration
API_URL="https://flylink.fly.dev/api/bookmarks/"
ACCESS_TOKEN=""
JSON_FILE=""

# Function to create or update a bookmark
create_bookmark() {
  local url="$1"
  local title="$2"

  # Prepare JSON payload
  PAYLOAD=$(cat <<EOF
{
  "url": "$url",
  "title": "$title",
  "is_archived": false,
  "unread": true,
  "shared": false
}
EOF
)

  # Make POST request
  response=$(curl -s -o /dev/stderr -w "%{http_code}" -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Token $ACCESS_TOKEN" \
    -d "$PAYLOAD")

  # Check response code
  if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
    echo "Bookmark created/updated successfully for URL: $url"
  else
    echo "Error creating/updating bookmark for URL: $url (HTTP $response)"
  fi
}

# Read URLs and details from JSON file
jq -c '.bookmarks[] | {url: .content.url, title: .title}' "$JSON_FILE" | while read -r entry; do
  url=$(echo "$entry" | jq -r '.url')
  title=$(echo "$entry" | jq -r '.title // "Untitled"')

  # Skip entries without a URL
  if [ -n "$url" ]; then
    create_bookmark "$url" "$title"
  else
    echo "Skipping entry without URL: $entry"
  fi
done
