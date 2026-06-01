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
echo "nameserver 127.0.0.1" > /etc/resolv.conf
dnsproxy -u https://dns.vjlab.xyz/dns-query/gatus -b 1.1.1.1 -f 1.1.1.1 --cache &
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

# Start tailscale daemon and wait briefly for socket
echo -e "${GREEN}Info: Starting tailscale daemon...${NC}"
tailscaled --port 41641 --state=mem: --statedir=/data/tailscale --socket=/var/run/tailscale/tailscaled.sock >> /dev/null 2>&1 &
p1=$!
sleep 3

# Run tailscale up
echo -e "${GREEN}Info: Running tailscale up...${NC}"
tailscale up --accept-dns=false --accept-routes --advertise-exit-node --hostname=${FLY_APP_NAME} --advertise-tags=tag:fly-exit --authkey=${TS_OAUTH_CLIENT_SECRET}?preauthorized=true

# Start gatus
echo -e "${GREEN}Info: Starting gatus...${NC}"
gatus &
p2=$!

sleep 10
# Start cloudflared tunnel
echo -e "${GREEN}Info: Starting cloudflared tunnel...${NC}"
cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN" &
p3=$!

# Monitor processes
wait -n $p1 $p2 $p3
exit $?
