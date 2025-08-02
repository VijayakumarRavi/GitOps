#!/usr/bin/env bash
set -euo pipefail


URL="https://hc-ping.com/${HC_PING_KEY}/baovault-${FLY_MACHINE_ID}?create=1"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [$FLY_MACHINE_ID] $*" >&2
}

log "Starting healthcheck script for OpenBao..."

# Initial delay to allow OpenBao to start
sleep "${HEALTHCHECK_INTERVAL:-300}"

while true; do
    STATUS_OUTPUT=$(bao status -address=http://127.0.0.1:8200 2>&1)
    STATUS_CODE=$?

    if [[ "${STATUS_CODE}" -ne 0 ]]; then
        log "Attempting to restart OpenBao..."
        if overmind restart vault -s overmind.hcvault.sock; then
            DATA=`echo -e "⚠️  OpenBao was unhealthy. Status code: ${STATUS_CODE}\n✅ Restart successful\n${STATUS_OUTPUT}"`
            curl -fsS -m 10 --retry 3 -d "${DATA}" "${URL}" -o /dev/null || log "Failed to ping Healthchecks.io"
        else
            DATA=`echo -e "❌ Restart failed \n${STATUS_OUTPUT}"`
            curl -fsS -m 10 --retry 3 -d "${DATA}" "${URL}/fail" -o /dev/null || log "Failed to ping Healthchecks.io"
        fi
    else
        DATA=`echo -e "✅ Vault is healthy \n${STATUS_OUTPUT}"`
        curl -fsS -m 10 --retry 3 -d "${DATA}" "${URL}" -o /dev/null || log "Failed to ping Healthchecks.io"
    fi
    sleep "${HEALTHCHECK_INTERVAL:-300}"
done