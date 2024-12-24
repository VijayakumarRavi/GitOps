#!/bin/bash

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Info: Starting up...${NC}"

# error: adding [-i tailscale0 -j MARK --set-mark 0x40000] in v4/filter/ts-forward: running [/sbin/iptables -t filter -A ts-forward -i tailscale0 -j MARK --set-mark 0x40000 --wait]: exit status 2: iptables v1.8.6 (legacy): unknown option "--set-mark"
modprobe xt_mark

# Ensure the directory exists and has the correct permissions
mkdir -p /root/.config/rclone  /data/tailscale
chmod 700 /root/.config/rclone

# Generate or modify rclone.conf
cat << EOF > /root/.config/rclone/rclone.conf
[Cloudflare]
type = s3
provider = Cloudflare
access_key_id = $CF_ACCESS_KEY
secret_access_key = $CF_ACCESS_KEY_SECRET
region = auto
endpoint = $CF_R2_ENDPOINT
acl = private
no_check_bucket = true

[backblaze]
type = b2
account = $B2_APPLICATION_KEY_ID
key = $B2_APPLICATION_KEY
hard_delete = true
EOF
chmod 600 /root/.config/rclone/rclone.conf

# Set sysctl parameters
sysctl -w net.core.rmem_max=8388608
sysctl -w net.core.wmem_max=8388608
sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216'
sysctl -w net.ipv4.tcp_wmem='4096 87380 16777216'
sysctl -w net.ipv4.tcp_mem='16777216 16777216 16777216'
sysctl -w net.ipv4.udp_mem='16777216 16777216 16777216'
sysctl -w net.ipv4.ping_group_range="0 1000"
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Deleting old fly node from tailnet
apikey=$(curl -s -d "client_id=${OAUTH_CLIENT_ID}" -d "client_secret=${OAUTH_CLIENT_SECRET}" "https://api.tailscale.com/api/v2/oauth/token" | jq .access_token | tr -d '"')
targetname="${FLY_APP_NAME}"
curl -s "https://api.tailscale.com/api/v2/tailnet/-/devices" -u "$apikey:" | jq -r '.devices[] |  "\(.id) \(.name)"' |
  while read id name; do
    if [[ $name = *"$targetname"* ]]
    then
      echo -e "${YELLOW}Warn: Found previous node($name) still in tailnet - getting rid of it${NC}"
      curl -s -X DELETE "https://api.tailscale.com/api/v2/device/$id" -u "$apikey:"
    fi
  done

# litestream database restore
litestream restore -if-db-not-exists -if-replica-exists -config /etc/litestream.yaml /data/db.sqlite3

# Execute the CMD
exec "$@"
