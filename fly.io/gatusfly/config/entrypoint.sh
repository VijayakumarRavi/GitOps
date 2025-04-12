#!/usr/bin/env bash

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Info: Starting up...${NC}"

# creating tailscale data folder
mkdir -pv /data/tailscale

#Set dnsproxy as dns server and starting it
echo "nameserver 127.0.0.1" > /etc/resolv.conf && \
  overmind start -l dnsproxy -f /Procfile -s /overmind.dns.sock &
echo -e "${GREEN}Info: Changed dns to dnsproxy(127.0.0.1)"

# error: adding [-i tailscale0 -j MARK --set-mark 0x40000] in v4/filter/ts-forward: running [/sbin/iptables -t filter -A ts-forward -i tailscale0 -j MARK --set-mark 0x40000 --wait]: exit status 2: iptables v1.8.6 (legacy): unknown option "--set-mark"
modprobe xt_mark

echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Deleting old fly node from tailnet
apikey=$(curl -s -d "client_id=${TS_OAUTH_CLIENT_ID}" -d "client_secret=${TS_OAUTH_CLIENT_SECRET}" "https://api.tailscale.com/api/v2/oauth/token" | jq .access_token | tr -d '"')
targetname="${FLY_APP_NAME}"
curl -s "https://api.tailscale.com/api/v2/tailnet/-/devices" -u "$apikey:" | jq -r '.devices[] |  "\(.id) \(.name)"' |
  while read id name; do
    if [[ $name = *"$targetname"* ]]
    then
      echo -e "${YELLOW}Warn: Found previous node($name) still in tailnet - getting rid of it${NC}"
      curl -s -X DELETE "https://api.tailscale.com/api/v2/device/$id" -u "$apikey:"
    fi
  done

# Execute the CMD
exec "$@"
