#!/bin/bash

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Info: Starting up...${NC}"

cat <<EOF > /config.hcl
ui = true
cluster_name = "bao"
api_addr = "http://[${FLY_PRIVATE_IP}]:8200"
cluster_addr = "http://[${FLY_PRIVATE_IP}]:8201"

storage "postgresql" {
  connection_url = "${BAO_POSTGRES_URL}"
  ha_enabled = "true"
}

listener "tcp" {
  tls_disable = "true"
  address     = "[::]:8200"
  cluster_address = "[::]:8201"
}

seal "static" {
  current_key_id = "unsealkey-20250711"
  current_key = "${BAO_CURRENT_UNSEAL_KEY}"
}
EOF
echo -e "${GREEN}Info: Vault configuration written to /config.hcl${NC}"

# Execute the CMD
exec "$@"
