#!/usr/bin/env bash
set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

while true; do
    if ! bao status &>/dev/null; then
        log "⚠️ Vault unhealthy. Restarting..."
        if overmind restart vault -s overmind.hcvault.sock; then
            log "✅ Restart successful"
            curl -fsS -m 10 --retry 3 "$HC_PING_URL/fail" \
                -d "Vault unhealthy but restart successful" || true
        else
            log "❌ Restart failed"
            curl -fsS -m 10 --retry 3 "$HC_PING_URL/fail" \
                -d "Vault unhealthy and restart failed" || true
        fi
    else
        curl -fsS -m 10 --retry 3 "$HC_PING_URL" > /dev/null || true
    fi

    sleep ${HEALTHCHECK_INTERVAL:-300}
done
