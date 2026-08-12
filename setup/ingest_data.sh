#!/usr/bin/env bash
# Copies one month of NYC Yellow Taxi trip Parquet data from Microsoft's
# public Azure Open Datasets storage account directly into the project's
# own ADLS Gen2 "raw" container, via a service-to-service azcopy transfer
# (the data never touches your local machine).
#
# Uses a short-lived SAS token generated via Azure CLI for the destination,
# rather than "azcopy login" - that command's AAD device-code flow rejects
# personal Microsoft accounts, which az login itself accepts fine.
set -euo pipefail
export MSYS_NO_PATHCONV=1

if [ ! -f .synapse_project_config ]; then
  echo "ERROR: .synapse_project_config not found. Run setup/create_resources.sh first."
  exit 1
fi
source .synapse_project_config

PUBLIC_SOURCE="https://azureopendatastorage.blob.core.windows.net/nyctlc/yellow/puYear=2022/puMonth=1/*.parquet"

echo "==> Checking azcopy is installed"
if ! command -v azcopy &> /dev/null; then
  echo "ERROR: azcopy not found. Install it: https://learn.microsoft.com/azure/storage/common/storage-use-azcopy-v10"
  exit 1
fi

echo "==> Generating a short-lived SAS token for the raw container"
ACCOUNT_KEY=$(az storage account keys list \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query '[0].value' -o tsv)

EXPIRY=$(date -u -d "+2 hours" '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -v+2H '+%Y-%m-%dT%H:%MZ')

SAS_TOKEN=$(az storage container generate-sas \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$ACCOUNT_KEY" \
  --name raw \
  --permissions acdlrw \
  --expiry "$EXPIRY" \
  -o tsv)

DEST_URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net/raw/yellow_2022_01?${SAS_TOKEN}"

echo "==> Copying January 2022 Yellow Taxi data (public source -> your raw container)"
azcopy copy "$PUBLIC_SOURCE" "$DEST_URL" --recursive

echo ""
echo "==> Done. Data copied to: https://${STORAGE_ACCOUNT}.blob.core.windows.net/raw/yellow_2022_01"
echo ""
echo "Next: open Synapse Studio, connect to the Built-in serverless SQL pool,"
echo "and run sql/01_create_external_objects.sql"
