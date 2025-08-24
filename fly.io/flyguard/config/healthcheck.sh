
# Check if the Cloudflare tunnel is healthy

status=$(curl -s https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$CLOUDFLARE_TUNNEL_ID \
  -H "X-Auth-Email: $EMAIL" \
  -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
  | jq -r ".result.status")

if [[ $status == "healthy" ]]; then
  echo "✅ Tunnel is healthy!"
else
  echo "❌ Tunnel is not healthy. Restarting..."
  overmind restart cf_tunnel -s /overmind.AGH.sock
fi

# Check if AdGuard Home DoH is resolving domains
if curl -fsS -m 10 --retry 5 -o /dev/null --doh-url https://${DOMAIN_NAME}/dns-query/localhost https://hc-ping.com/76e166fa-d7a5-4277-9677-5886b6eebd4b; then
  echo "✅ AdGuard Home is healthy!"
else
  echo "❌ AdGuard Home is not healthy. Restarting..."
  overmind restart adguard -s /overmind.AGH.sock
fi

