#!/usr/bin/env bash
# Copies one month of NYC Yellow Taxi trip Parquet data from Microsoft's
# public Azure Open Datasets storage account directly into the project's
# own ADLS Gen2 "raw" container, via a service-to-service azcopy transfer
# (the data never touches your local machine).
set -euo pipefail
export MSYS_NO_PATHCONV=1

if [ ! -f .synapse_project_config ]; then
  echo "ERROR: .synapse_project_config not found. Run setup/create_resources.sh first."
  exit 1
fi
source .synapse_project_config

PUBLIC_SOURCE="https://azureopendatastorage.blob.core.windows.net/nyctlc/yellow/puYear=2022/puMonth=1/*.parquet"
DEST_URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net/raw/yellow_2022_01"

echo "==> Checking azcopy is installed"
if ! command -v azcopy &> /dev/null; then
  echo "ERROR: azcopy not found. Install it: https://learn.microsoft.com/azure/storage/common/storage-use-azcopy-v10"
  exit 1
fi

echo "==> Logging azcopy in with your Azure CLI session"
azcopy login --identity 2>/dev/null || azcopy login

echo "==> Copying January 2022 Yellow Taxi data (public source -> your raw container)"
azcopy copy "$PUBLIC_SOURCE" "$DEST_URL" --recursive

echo ""
echo "==> Done. Data copied to: $DEST_URL"
echo ""
echo "Next: open Synapse Studio, connect to the Built-in serverless SQL pool,"
echo "and run sql/01_create_external_objects.sql"
