#!/usr/bin/env bash
# Tears down all resources created by create_resources.sh.
set -euo pipefail
export MSYS_NO_PATHCONV=1

if [ ! -f .synapse_project_config ]; then
  echo "ERROR: .synapse_project_config not found. Nothing to clean up, or you're in the wrong directory."
  exit 1
fi
source .synapse_project_config

echo "==> This will delete the entire resource group: $RESOURCE_GROUP"
echo "    (storage account, Synapse workspace, all data — everything)"
read -p "Type the resource group name to confirm deletion: " CONFIRM

if [ "$CONFIRM" != "$RESOURCE_GROUP" ]; then
  echo "Confirmation did not match. Aborting — nothing was deleted."
  exit 1
fi

echo "==> Deleting resource group: $RESOURCE_GROUP"
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo "==> Deletion initiated (running in background)."
echo "    Check status with: az group show --name $RESOURCE_GROUP"

rm -f .synapse_project_config .synapse_sql_admin_password
