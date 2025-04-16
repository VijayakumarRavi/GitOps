
# Check if the Cloudflare tunnel is healthy

status=$(curl -s https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$CLOUDFLARE_TUNNEL_ID \
  -H "X-Auth-Email: $LEGO_EMAIL" \
  -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
  | jq -r ".result.status")

if [[ $status == "healthy" ]]; then
  echo "✅ Tunnel is healthy!"
else
  echo "❌ Tunnel is not healthy. Restarting..."
  overmind restart cf_tunnel -s /overmind.AGH.sock
fi

# Check if AdGuard Home DoH is resolving domains
if curl -fsS -m 10 --retry 5 -o /dev/null --doh-url https://dns.vijayakumar.xyz/dns-query/localhost https://hc-ping.com/ff58e8f1-7e32-4b1e-8673-10c411ddb787; then
  echo "✅ AdGuard Home is healthy!"
else
  echo "❌ AdGuard Home is not healthy. Restarting..."
  overmind restart adguard -s /overmind.AGH.sock
fi

# Check if Tailscale is connected
if tailscale status > /dev/null 2>&1; then
  echo "✅ Tailscale is healthy!"
else
  echo "❌ Tailscale is not healthy. Restarting..."
  tailscale up --accept-dns=false --accept-routes --advertise-exit-node --hostname=${FLY_APP_NAME} --advertise-tags=tag:fly-exit --authkey=${TS_OAUTH_CLIENT_SECRET}?preauthorized=true
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
fi
