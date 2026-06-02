#!/bin/bash

# catch the error in case first pipe command fails (but second succeeds)
set -euo pipefail
IFS=$'\n\t'
# turn on traces, useful while debugging but commented out by default
# set -o xtrace

if [ -z "${RESTIC_HC_PING_UUID:-}" ]; then
    echo "RESTIC_HC_PING_UUID is not set"
    exit 1
fi

RID=$(uuidgen)
LOG="/var/log/restic/$(date +%Y%m%d_%H%M%S).log"

# create log dir
mkdir -p /var/log/restic/

function log() {
    "$@" 2>&1 | tee -a "$LOG"
}

function run_silently() {
    "$@" >/dev/null 2>&1
}

# ###############################################################################
# colorized echo helpers                                                        #
# taken from: https://github.com/atomantic/dotfiles/blob/master/lib_sh/echos.sh #
# ###############################################################################

ESC_SEQ="\x1b["
COL_RED=$ESC_SEQ"31;01m"
COL_BLUE=$ESC_SEQ"34;01m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_YELLOW=$ESC_SEQ"33;01m"
COL_RESET=$ESC_SEQ"39;49;00m"

function ok() {
    log echo -e "$COL_GREEN[ok]$COL_RESET ${1:-}"
}

function running() {
    log echo -en "$COL_BLUE ⇒ $COL_RESET ${1:-}..."
}

function warn() {
    log echo -e "$COL_YELLOW[warning]$COL_RESET ${1:-}"
}

function error() {
    log echo -e "$COL_RED[error]$COL_RESET ${1:-}"
    log echo -e "${2:-}"
}

function notify_and_exit_on_error() {
    local cmd="$1"
    local err_msg="$2"

    output=$(eval "$cmd" 2>&1)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        error "$err_msg" "$output"
        curl -fsS --retry 3 "https://hc-ping.com/${RESTIC_HC_PING_UUID}/fail?rid=${RID}" -d "$err_msg: $output" >/dev/null 2>&1
        exit 2
    fi
}

function finish_successfully() {
    curl -fsS --retry 3 "https://hc-ping.com/${RESTIC_HC_PING_UUID}?rid=${RID}" -d "$output" >/dev/null 2>&1
}

# ##############
# backup steps #
# ##############

curl -fsS --retry 3 "https://hc-ping.com/${RESTIC_HC_PING_UUID}/start?rid=$RID" >/dev/null 2>&1

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
    notify_and_exit_on_error "restic init" "Repo init failed"
fi

running "restic backup"
notify_and_exit_on_error "restic backup --verbose /data" "Restic backup failed"
ok

running "checking consistency of restic repository"
notify_and_exit_on_error "restic check" "Restic check failed"
ok

running "removing outdated snapshots"
notify_and_exit_on_error "restic forget --keep-hourly 24 --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --keep-yearly 3 --prune" "Restic forget failed"
ok

/usr/bin/find /var/log/restic/ -name "*.log" -type f -mmin +600 -exec rm -f {} \;

finish_successfully
