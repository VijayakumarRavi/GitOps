#!/bin/bash

# Default values
VAULT_NAME="Private"
ITEM_NAME="MyEnvironmentSecrets"
ENV_FILE=".env"
TEMPLATE_FILE=$(op item template get "Login")



# Usage function
usage() {
  echo "Usage: $0 [-v VAULT_NAME] [-i ITEM_NAME] [-f ENV_FILE]"
  echo "  -v    Name of the 1Password vault (default: Private)"
  echo "  -i    Name of the 1Password item (default: MyEnvironmentSecrets)"
  echo "  -f    Path to the .env file (default: .env)"
  exit 1
}

# Parse command-line options
while getopts "v:i:f:h" opt; do
  case $opt in
    v) VAULT_NAME="$OPTARG" ;;
    i) ITEM_NAME="$OPTARG" ;;
    f) ENV_FILE="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

# Check if the .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: Environment file '$ENV_FILE' not found!"
  exit 1
fi

# Read and modify the JSON template
FIELDS_JSON="[]"
while IFS='=' read -r key value; do
  if [[ -n "$key" && ! "$key" =~ ^# ]]; then
    FIELDS_JSON=$(jq --arg key "$key" --arg value "$value" '. + [{ "id": $key, "label": $key, "value": $value, "type": "STRING" }]' <<< "$FIELDS_JSON")
  fi
done < "$ENV_FILE"

# Inject fields into the JSON template
echo "$TEMPLATE_FILE" | jq --arg title "$ITEM_NAME" --argjson fields "$FIELDS_JSON" '.title=$title | .fields=$fields'  > modified_login.json

# Create the item in 1Password
op item create --vault "$VAULT_NAME" --template=modified_login.json

# Clean up the temporary file
# rm -f modified_login.json

echo "Secrets from '$ENV_FILE' imported into 1Password vault '$VAULT_NAME' under item '$ITEM_NAME'."

