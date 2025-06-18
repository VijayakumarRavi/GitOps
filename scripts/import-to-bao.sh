#!/usr/bin/env bash

# ---- Config ----
MOUNT_PATH="luffy"                    # Change this if your KV engine is mounted elsewhere

if [[ -z "$BAO_TOKEN" ]]; then
  echo "Error: BAO_TOKEN is not set"
  exit 1
fi
if [[ -z "$BAO_ADDR" ]]; then
  echo "Error: BAO_ADDR is not set"
  exit 1
fi

add_to_vault() {
    INPUT_JSON=$(op item get $1 --format json --reveal)

    # ---- Read and Transform JSON ----
    DATA=$(echo "$INPUT_JSON" | jq 'reduce .fields[] as $item ({}; . + { ($item.label): $item.value }) | with_entries(select(.value != null))')
    if [[ -z "$DATA" ]]; then
      echo "Error: Failed to extract data from input.json"
      exit 1
    fi

    # ---- Create JSON Payload for KV v2 ----
    PAYLOAD=$(jq -n --argjson data "$DATA" '{ data: $data }')

    SECRET_PATH=$(echo $INPUT_JSON | jq -r '.title | ascii_downcase | gsub(" "; "-")')

    # ---- Push to Vault ----
    curl -sS \
      --header "X-Vault-Token: $BAO_TOKEN" \
      --request POST \
      --data "$PAYLOAD" \
      "$BAO_ADDR/v1/$MOUNT_PATH/data/$SECRET_PATH" | jq .

    echo "✅ Secret written to path: $MOUNT_PATH/data/$SECRET_PATH"
}

ITEMS=$(op item list --vault automation --format=json | jq -r '.[].id')

for item in $ITEMS; do
    add_to_vault "$item"
done
