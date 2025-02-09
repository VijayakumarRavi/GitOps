#!/bin/bash

# Number of backups to keep
KEEP=48

# Function to process backups on a given rclone remote
process_remote() {
  local remote=$1

  # List files on the rclone remote and sort them by date
  files=$(rclone lsf --files-only "$remote" | sort -t'-' -k3,3 -k2,2 -k1,1)

  # Convert the list of files to an array
  IFS=$'\n' read -rd '' -a files_array <<<"$files"

  # Calculate the number of files to delete
  total_files=${#files_array[@]}
  delete_count=$((total_files - KEEP))

  # Delete older files if there are more files than the number to keep
  if [ $delete_count -gt 0 ]; then
    for ((i=0; i<delete_count; i++)); do
      file="${files_array[i]}"
      echo "Deleting old backup: $file"
      rclone -v delete "$remote/$file"
    done
  fi
}

process_remote "backblaze:backuprest/vaultwarden"
process_remote "Cloudflare:vaultwarden"

# Ping healthchecks.io for monitoring
if [[ -n "$CLEANUP_HC_PING_URL" ]]; then
    curl -fsS -m 10 --retry 5 -o /dev/null "${CLEANUP_HC_PING_URL}"
fi
