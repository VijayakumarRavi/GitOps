#!/usr/bin/env bash

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color


echo -e "${GREEN}Info: Starting up...${NC}"

mkdir -p /data/AdGuardHome

restic restore latest --target=/ --verbose=2 --cleanup-cache --overwrite if-newer
if [ $? -ne 0 ]; then
  echo -e "${RED}Error: Restic restore failed. Please check your restic configuration.${NC}"
  exit 1
else
  echo -e "${GREEN}Info: Restic restore completed successfully.${NC}"
fi

# Execute the CMD
exec "$@"
