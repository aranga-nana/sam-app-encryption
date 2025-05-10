#!/bin/bash

# Check if CONFIG_ENV and PASSWORD are provided
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <CONFIG_ENV> <PASSWORD>"
  exit 1
fi

CONFIG_ENV="$1"
ENV_CONFIG_FILE="env-config.json"

# Check if the JSON file exists
if [ ! -f "$ENV_CONFIG_FILE" ]; then
  echo "Error: Environment config file '$ENV_CONFIG_FILE' not found."
  exit 1
fi

# Extract all key-value pairs for the specified environment
PARAMETER_OVERRIDES=$(jq -r --arg env "$CONFIG_ENV" '.[$env] | to_entries | map("\(.key)=\(.value)") | join(" ")' "$ENV_CONFIG_FILE")

if [ -z "$PARAMETER_OVERRIDES" ]; then
  echo "Error: No parameters found for environment '$CONFIG_ENV' in '$ENV_CONFIG_FILE'."
  exit 1
fi

# Update the parameter_overrides in samconfig.toml
sed -i -e "s|parameter_overrides = .*|parameter_overrides = \"$PARAMETER_OVERRIDES\"|g" samconfig.toml

echo "Updated parameter_overrides for environment '$CONFIG_ENV': $PARAMETER_OVERRIDES"

# Variables
CONFIG_ENV="$1"
PASSWORD="$2"
ROLE_ARN="arn:aws:iam::363762816039:role/cf-deploy"
SESSION_NAME="cf-deploy-session"
KMS_KEY_ID="alias/test" # Replace with your KMS key alias or ID

# Step 1: Encrypt the password using AWS KMS
echo "Encrypting the password using AWS KMS..."
ENCRYPTED_PASSWORD=$(aws kms encrypt --key-id "$KMS_KEY_ID" --plaintext "$PASSWORD" --query CiphertextBlob --output text --profile aranga)  

if [ $? -ne 0 ]; then
  echo "Error: Failed to encrypt the password."
  exit 1
fi

echo "Encrypted password: $ENCRYPTED_PASSWORD"

# Replace the placeholder in the environment variable file or configuration
sed -i -e "s|inject-her-a|$ENCRYPTED_PASSWORD|g" template.yaml


# Step 2: Assume the role
echo "Assuming role: $ROLE_ARN"
ASSUME_ROLE_OUTPUT=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name "$SESSION_NAME")

if [ $? -ne 0 ]; then
  echo "Error: Failed to assume role."
  exit 1
fi

# Extract temporary credentials
AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')

# Step 3: Export credentials
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

echo "Temporary credentials set."

# Step 4: Deploy the stack
echo "Deploying the stack with SAM CLI using config environment: $CONFIG_ENV"
npm run build
sam deploy --config-env "$CONFIG_ENV"

# Step 5: Cleanup environment variables
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

sed -i -e "s|$ENCRYPTED_PASSWORD|inject-her-a|g" template.yaml
echo "Deployment complete. Temporary credentials cleared."
rm -f rm -rf template-*.yaml
rm -f samconfig-*.toml 
 