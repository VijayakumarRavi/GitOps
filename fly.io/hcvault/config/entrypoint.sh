#!/bin/bash

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Info: Starting up...${NC}"

cat <<EOF > /config.hcl
ui = true
disable_mlock = "true"
cluster_name = "hcvault"
api_addr = "${VAULT_ADDR}"
cluster_addr = "${VAULT_ADDR}:8201"

storage "s3" {
  endpoint   = "${AWS_ENDPOINT}"
  access_key = "${AWS_ACCESS_KEY_ID}"
  secret_key = "${AWS_SECRET_ACCESS_KEY}"
  bucket     = "fly"
  path       = "hcvault/storage"
  s3_force_path_style = "true"
}

listener "tcp" {
  address     = "[::]:8200"
  tls_disable = "true"
}

seal "azurekeyvault" {
  client_id      = "${AZURE_CLIENT_ID}"
  client_secret  = "${AZURE_CLIENT_SECRET}"
  tenant_id      = "${AZURE_TENANT_ID}"
  vault_name     = "hcvault-e5cb030c"
  key_name       = "hcvault"
}
EOF
echo -e "${GREEN}Info: Vault configuration written to /config.hcl${NC}"

# Execute the CMD
exec "$@"
