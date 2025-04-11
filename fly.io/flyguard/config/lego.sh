#!/bin/bash
set -euo pipefail

WORKING_DIR="/data/lego"
LEGO_BIN="/usr/local/bin/lego"

mkdir -pv "$WORKING_DIR"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# delay for tailscale to be up
sleep 10

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
< Lego, activate! >
 --------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
EOF

echo "🚀 Let's Get Encrypted! 🚀"
echo "🌐 Domain: ${DOMAIN_NAME:-}"
echo "📧 Email: ${LEGO_EMAIL:-}"
echo "📁 Working Directory: $WORKING_DIR"
echo "-----------------------------------------------------------"

error_exit() {
    echo "❌ $1" >&2
    exit 1
}

check_env() {
    : "${DOMAIN_NAME:?DOMAIN_NAME must be set}"
    : "${LEGO_EMAIL:?LEGO_EMAIL must be set}"
    : "${CLOUDFLARE_DNS_API_TOKEN:?CLOUDFLARE_DNS_API_TOKEN must be set}"
    : "${HC_PING_UUID:?HC_PING_UUID must be set}"
}

run_lego() {
    check_env

    local cmd="run"
    if [ -f "${WORKING_DIR}/certificates/${DOMAIN_NAME}.crt" ]; then
        echo "🔁 Certificate exists. Renewing..."
        cmd="renew"
    else
        echo "🆕 Requesting certificate for ${DOMAIN_NAME}"
    fi

    if ! "$LEGO_BIN" \
        --accept-tos \
        --email "$LEGO_EMAIL" \
        --dns cloudflare \
        --domains "${DOMAIN_NAME}" \
        --domains "*.${DOMAIN_NAME}" \
        --path "$WORKING_DIR" \
        --cert.timeout 600 \
        $cmd \
        --preferred-chain="ISRG Root X1"; then

        echo "❌ lego failed for command: $cmd"
        curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/${HC_PING_UUID}/fail || true
        exit 1
    fi

    echo "✅ Certificate ready: ${DOMAIN_NAME}.crt and .key"

    echo "🔄 Restarting AdGuard Home with new certificate..."
    overmind restart adguard -s /data/overmind.AGH.sock

    curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/${HC_PING_UUID} || true
}

run_lego

# Loop to check renewal every 23–24 hours
while true; do
    RENEWAL_INTERVAL=$(( (23 * 3600) + RANDOM % 3600 ))
    next_run=$(date -d "@$(($(date +%s) + RENEWAL_INTERVAL))" '+%Y-%m-%d %H:%M:%S')
    echo "🕒 Next renewal at $next_run"

    sleep "$RENEWAL_INTERVAL"
    run_lego
done
