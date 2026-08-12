#!/usr/bin/env bash
# Creates the ADLS Gen2 storage account and Synapse workspace for the
# NYC Taxi big data solution. Run one section at a time.
set -euo pipefail

# Prevent Git Bash/MSYS from mangling /subscriptions/... paths into
# Windows-style paths, which silently corrupts --scope arguments.
export MSYS_NO_PATHCONV=1

RESOURCE_GROUP="rg-synapse-nyc-taxi"
LOCATION="centralus"
SUFFIX=$(openssl rand -hex 3)
STORAGE_ACCOUNT="synapsenyctaxi${SUFFIX}"
FILESYSTEM_NAME="raw"
SYNAPSE_WORKSPACE="synapse-nyc-taxi-${SUFFIX}"
SQL_ADMIN_USER="synapseadmin"

echo "==> Creating resource group: $RESOURCE_GROUP in $LOCATION"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

echo "==> Creating ADLS Gen2 storage account: $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --hierarchical-namespace true

echo "==> Creating containers: raw, curated"
az storage container create \
  --account-name "$STORAGE_ACCOUNT" \
  --name "raw" \
  --auth-mode login

az storage container create \
  --account-name "$STORAGE_ACCOUNT" \
  --name "curated" \
  --auth-mode login

echo "==> Generating a SQL admin password"
SQL_ADMIN_PASSWORD=$(openssl rand -base64 24)
echo "$SQL_ADMIN_PASSWORD" > .synapse_sql_admin_password
echo "    Saved to .synapse_sql_admin_password (gitignored) - keep this safe"

echo "==> Creating Synapse workspace: $SYNAPSE_WORKSPACE"
az synapse workspace create \
  --name "$SYNAPSE_WORKSPACE" \
  --resource-group "$RESOURCE_GROUP" \
  --storage-account "$STORAGE_ACCOUNT" \
  --file-system "$FILESYSTEM_NAME" \
  --sql-admin-login-user "$SQL_ADMIN_USER" \
  --sql-admin-login-password "$SQL_ADMIN_PASSWORD" \
  --location "$LOCATION"

echo "==> Allowing your current IP through the workspace firewall"
MY_IP=$(curl -s https://api.ipify.org)
az synapse workspace firewall-rule create \
  --name "AllowMyIP" \
  --workspace-name "$SYNAPSE_WORKSPACE" \
  --resource-group "$RESOURCE_GROUP" \
  --start-ip-address "$MY_IP" \
  --end-ip-address "$MY_IP"

echo "==> Granting your account Storage Blob Data Contributor on the storage account"
MY_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
STORAGE_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
az role assignment create \
  --assignee "$MY_OBJECT_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID"

# Save config for the other scripts to reuse without re-typing generated names.
cat > .synapse_project_config << EOF
RESOURCE_GROUP=$RESOURCE_GROUP
STORAGE_ACCOUNT=$STORAGE_ACCOUNT
SYNAPSE_WORKSPACE=$SYNAPSE_WORKSPACE
LOCATION=$LOCATION
EOF

echo ""
echo "==> Done. Resources created:"
echo "    Resource group    : $RESOURCE_GROUP"
echo "    Storage account   : $STORAGE_ACCOUNT (containers: raw, curated)"
echo "    Synapse workspace : $SYNAPSE_WORKSPACE"
echo ""
echo "Studio URL: https://web.azuresynapse.net/?workspace=%2Fsubscriptions%2F.../resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Synapse/workspaces/$SYNAPSE_WORKSPACE"
echo "(or just go to https://web.azuresynapse.net and select the workspace from the list)"
echo ""
echo "Next: bash setup/ingest_data.sh"
