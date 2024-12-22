#!/bin/bash

# Ensure the directory exists and has the correct permissions
mkdir -p /root/.config/rclone
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

# Execute the CMD
exec "$@"
