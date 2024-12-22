#!/usr/bin/env bash

sleep 10

tailscale up \
  --accept-routes \
  --advertise-exit-node \
  --hostname=${FLY_APP_NAME} \
  --advertise-tags=tag:fly-exit \
  --authkey=${OAUTH_CLIENT_SECRET}?preauthorized=true

while true; do
   sleep 60
done
