#!/bin/bash

echo "Starting gotify..."
cd /data/gotify
/app/gotify/gotify-app &
p1=$!

echo "Starting igotify..."
cd /data/igotify
dotnet "/app/igotify/iGotify Notification Assist.dll" &
p2=$!

sleep 10
echo "Starting cloudflared tunnel..."
/usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN" &
p3=$!

wait -n $p1 $p2 $p3
exit $?
