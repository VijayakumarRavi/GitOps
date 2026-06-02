#!/bin/bash

# Catch errors, strict mode
set -euo pipefail
IFS=$'\n\t'

if [ -z "${RESTIC_HC_PING_UUID:-}" ]; then
    echo "RESTIC_HC_PING_UUID is not set"
    exit 1
fi

RID=$(uuidgen)
LOG="/var/log/restic/$(date +%Y%m%d_%H%M%S).log"

# Create log dir
mkdir -p /var/log/restic/
touch "$LOG"

HC_PING_STATUS=""

function send_ping() {
    local status="${1:-}" # e.g., 'start', 'fail', or empty for success
    local url="https://hc-ping.com/${RESTIC_HC_PING_UUID}"

    # Append status suffix if provided
    [ -n "$status" ] && url="${url}/${status}"
    url="${url}?rid=${RID}"

    if [ -n "${RESTIC_HC_PING_UUID:-}" ] && [ "$HC_PING_STATUS" != "sent" ]; then
        # Tail the last 100,000 bytes directly to HC
        tail -c 100000 "$LOG" | curl -fsS --retry 3 --data-binary @- "$url" >/dev/null 2>&1 || true

        # Lock out further pings unless this was just the 'start' ping
        if [ "$status" != "start" ]; then
            HC_PING_STATUS="sent"
        fi
    fi
}

function on_exit() {
    local exit_code="${1:-$?}"
    if [ "$exit_code" -ne 0 ]; then
        echo -e "\n[ERROR] Script failed prematurely with exit code ${exit_code}" >> "$LOG"
        send_ping fail
    fi
}

trap 'on_exit $?' EXIT

# ###############################################################################
# Console & Log helpers                                                         #
# ###############################################################################

ESC_SEQ="\x1b["
COL_RED=$ESC_SEQ"31;01m"
COL_BLUE=$ESC_SEQ"34;01m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_YELLOW=$ESC_SEQ"33;01m"
COL_RESET=$ESC_SEQ"39;49;00m"

function ok() {
    # Print color to terminal
    echo -e "${COL_GREEN}[ok]${COL_RESET} ${1:-}"
}

function running() {
    # Print color to terminal on one line
    echo -en "${COL_BLUE} ⇒ ${COL_RESET} ${1:-}..."
    # Print formatted, spaced header to log file
    echo -e "\n=== ${1:-} ===" >> "$LOG"
}

function warn() {
    echo -e "${COL_YELLOW}[warning]${COL_RESET} ${1:-}"
    echo "[warning] ${1:-}" >> "$LOG"
}

function error() {
    echo -e "${COL_RED}[error]${COL_RESET} ${1:-}"
    echo "[error] ${1:-}" >> "$LOG"
}

function run_and_log() {
    local cmd="$1"
    local err_msg="$2"

    if ! eval "$cmd" >> "$LOG" 2>&1; then
        error "$err_msg"
        exit 2
    fi
}

function run_silently() {
    "$@" >> "$LOG" 2>&1
}

# ##############
# Backup steps #
# ##############

send_ping start

running "checking restic config"
if run_silently restic cat config; then
    ok
    running "unlocking restic repository"
    if run_silently restic unlock; then
        ok
    else
        warn "restic unlock failed, continuing anyway"
    fi
else
    warn "restic repo either not initialized or erroring out"
    running "trying to initialize it"
    run_and_log "restic init" "Repo init failed"
    ok
fi

running "restic backup"
run_and_log "restic backup --verbose /data" "Restic backup failed"
ok

running "checking consistency of restic repository"
run_and_log "restic check" "Restic check failed"
ok

running "removing outdated snapshots"
run_and_log "restic forget --keep-hourly 24 --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --keep-yearly 3 --prune" "Restic forget failed"
ok

# Cleanup local logs older than 10 hours
/usr/bin/find /var/log/restic/ -name "*.log" -type f -mmin +600 -exec rm -f {} \;

# Success ping (sends the whole log!)
send_ping ""
ok "Backup finished and reported to Healthchecks."
