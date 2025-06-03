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

storage "raft" {
  path    = "/data/vault"
  node_id = "hcvault"
}

listener "tcp" {
  address     = "[::]:8200"
  tls_disable = "true"
}
EOF
echo -e "${GREEN}Info: Vault configuration written to /config.hcl${NC}"

restic restore --overwrite if-newer --target=/ --verbose=2 --cleanup-cache latest
if [ $? -ne 0 ]; then
  echo -e "${RED}Error: Restic restore failed. Please check your restic configuration.${NC}"
  exit 1
else
  echo -e "${GREEN}Info: Restic restore completed successfully.${NC}"
fi

# Execute the CMD
exec "$@"
