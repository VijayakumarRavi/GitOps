#!/bin/bash
set -euo pipefail

WORKING_DIR="/data/lego"
LEGO_BIN="/usr/local/bin/lego"
CLOUDFLARE_DNS_API_TOKEN="${CLOUDFLARE_API_KEY}"

mkdir -pv "${WORKING_DIR}"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

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
echo "📁 Working Directory: ${WORKING_DIR}"
echo "-----------------------------------------------------------"


# Check if required environment variables are set
: "${DOMAIN_NAME:?DOMAIN_NAME must be set}"
: "${LEGO_EMAIL:?LEGO_EMAIL must be set}"
: "${CLOUDFLARE_DNS_API_TOKEN:?CLOUDFLARE_DNS_API_TOKEN must be set}"
: "${LEGO_HC_PING_UUID:?LEGO_HC_PING_UUID must be set}"

cmd="run"
before_mtime=""
after_mtime=""
cert_path="${WORKING_DIR}/certificates/${DOMAIN_NAME}.crt"

if [ -f "$cert_path" ]; then
    echo "🔁 Certificate exists. Renewing..."
    cmd="renew"
    before_mtime=$(stat -c %Y "$cert_path")
else
    echo "🆕 Requesting certificate for ${DOMAIN_NAME}"
fi

output=$(eval '"$LEGO_BIN" \
    --accept-tos \
    --email "$LEGO_EMAIL" \
    --dns cloudflare \
    --domains "${DOMAIN_NAME}" \
    --domains "*.${DOMAIN_NAME}" \
    --path "${WORKING_DIR}" \
    --cert.timeout 600 \
    $cmd \
--preferred-chain="ISRG Root X1"'  2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "❌ lego failed for command: $cmd"
    curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/${LEGO_HC_PING_UUID}/fail -d "$output"
    exit 1
fi

after_mtime=$(stat -c %Y "$cert_path")

if [ "$before_mtime" != "$after_mtime" ]; then
    echo "✅ Certificate was updated!"
    echo "🔄 Restarting AdGuard Home with new certificate..."
    overmind restart adguard -s /overmind.AGH.sock
fi

days_remaining=$(echo "$output" | awk '/expires in/ { for(i=1;i<=NF;i++) if($i=="in") print $(i+1) }')
echo "📅 Certificate is still valid for ${days_remaining:-unknown} more days."

curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/${LEGO_HC_PING_UUID} -d "$output"
