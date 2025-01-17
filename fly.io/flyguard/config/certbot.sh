#!/usr/bin/env bash

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color


# Function to print the online status of the specified Tailscale node
get_status() {
    # Node name to check
    TARGET_NODE=${PING_HOST}
    # Get the status of all Tailscale nodes in JSON format
    tailscale_status=$(/usr/local/bin/tailscale status --json)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error: Failed to get Tailscale status${NC}"
        exit 1
    fi
    # Use jq to parse and print the online status of the specified node
    node_status=$(echo "$tailscale_status" | jq -r --arg TARGET_NODE "$TARGET_NODE" '.Peer[] | select(.HostName == $TARGET_NODE) | .Online')

    if [[ -z "$node_status" ]]; then
        echo -e "${RED}Error: Node '$TARGET_NODE' not found${NC}"
    elif [[ "$node_status" == "true" ]]; then
        echo -e "${GREEN}Info: $TARGET_NODE online status: $node_status${NC}"
        wget ${PING_HC_URL} -O /dev/null
    else
        echo -e "${YELLOW}Warn: $TARGET_NODE online status: $node_status${NC}"
    fi
}

/usr/local/bin/tailscale up \
  --accept-routes \
  --accept-dns=false \
  --advertise-exit-node \
  --hostname=${FLY_APP_NAME} \
  --advertise-tags=tag:fly-exit \
  --authkey=${TS_OAUTH_CLIENT_SECRET}?preauthorized=true

hostname=$(/usr/local/bin/tailscale whois --json $(/usr/local/bin/tailscale ip | grep 100) | jq -r '.Node.Name | rtrimstr(".")')
apikey=$(curl -s -d "client_id=${TS_OAUTH_CLIENT_ID}" -d "client_secret=${TS_OAUTH_CLIENT_SECRET}" "https://api.tailscale.com/api/v2/oauth/token" | jq .access_token | tr -d '"')
targetid="$(curl -s "https://api.tailscale.com/api/v2/tailnet/-/devices" -u "$apikey:" | jq -r --arg name "$hostname" '.devices[] | select(.name == $name) | .id')"

IP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --request POST \
  --url "https://api.tailscale.com/api/v2/device/$targetid/ip" \
  --header "Authorization: Bearer ${apikey}" \
  --header "Content-Type: application/json" \
  --data "{
    \"ipv4\": \"$TS_NODE_IP\"
  }")

# Check if the HTTP status code is not 200
if [ "$IP_STATUS" -ne 200 ]; then
  echo "${RED}Error: Unable to set tailscale ipv4 to $TS_NODE_IP Request failed with status code $IP_STATUS"
  sleep 10
  exit 1
else
  echo -e "${GREEN}Info: Node ip is set to $TS_NODE_IP ${NC}"
fi

cat << "EOF"
 ____________________
< Certbot, activate! >
 --------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
EOF

echo "🚀 Let's Get Encrypted! 🚀"
echo "🌐 Domain: $CERTBOT_DOMAIN"
echo "📧 Email: $CERTBOT_EMAIL"
echo "🔑 Key Type: $CERTBOT_KEY_TYPE"
echo "⏰ Renewal Interval: $RENEWAL_INTERVAL seconds"
echo "Let's Encrypt, shall we?"
echo "-----------------------------------------------------------"

# Validate required environment variables
for var in CLOUDFLARE_API_TOKEN CERTBOT_DOMAIN CERTBOT_EMAIL CERTBOT_KEY_TYPE; do
    if [ -z "$(eval echo \$$var)" ]; then
        echo "Error: $var environment variable is not set"
        exit 1
    fi
done

# Create Cloudflare configuration file
echo "dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN" > /cloudflare.ini

# Function to run certbot with provided arguments
run_certbot() {
    certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials /cloudflare.ini \
        -d "$CERTBOT_DOMAIN" \
        --key-type "$CERTBOT_KEY_TYPE" \
        --email "$CERTBOT_EMAIL" \
        --agree-tos \
        --non-interactive
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Error: certbot command failed with exit code $exit_code"
        exit 1
    fi
}

# Run certbot initially
if [[ ! -d /data/letsencrypt/live ]]; then
  run_certbot
  mv -v /etc/letsencrypt /data
  ln -svf /data/letsencrypt/* /etc/letsencrypt
fi

# Infinite loop to keep the container running and periodically check for renewals
while true; do
    next_run=$(date -d "@$(($(date +%s) + RENEWAL_INTERVAL))" '+%Y-%m-%d %H:%M:%S')
    echo "Next certificate renewal check will be at ${next_run}"
    sleep "$RENEWAL_INTERVAL"
    if ! run_certbot; then
        echo "Error: Certificate renewal failed. Exiting."
        exit 1
    fi
done
