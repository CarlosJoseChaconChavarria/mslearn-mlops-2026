#!/bin/bash
# setup-prod-design.sh
# Evolved provisioning tool to support isolated Dev, Prod, and Shared architectures.

# ---------------------------------------------------------------------------
# 🌎 1. Parse Input Parameters (NEW ENVIRONMENT FLAG)
# ---------------------------------------------------------------------------
# Accept environment argument (dev or prod). Defaults to dev if empty.
ENVIRONMENT=${1:-dev}

# Seed unique random values to prevent naming collisions in Azure's global namespace
guid=$(cat /proc/sys/kernel/random/uuid)
suffix=${guid//[-]/}
suffix=${suffix:0:6} # Safe character limits for Azure ML Registry names

export RANDOM_REGION="eastus" # Unified active region
export RESOURCE_PROVIDER="Microsoft.MachineLearningServices"

# Shared base naming templates (built using the custom prefix string)
export REGISTRY_RESOURCE_GROUP="rg-ai300-reg-${suffix}"
export REGISTRY_NAME="mlrai300shared${suffix}"

export DEV_RESOURCE_GROUP="rg-ai300-dev-${suffix}"
export DEV_WORKSPACE_NAME="mlw-ai300-dev-${suffix}"

export PROD_RESOURCE_GROUP="rg-ai300-prod-${suffix}"
export PROD_WORKSPACE_NAME="mlw-ai300-prod-${suffix}"

# ---------------------------------------------------------------------------
# 📊 2. Evolved Environment Routing Conditionals (The Lab Logic)
# ---------------------------------------------------------------------------
if [ "$ENVIRONMENT" = "prod" ]; then
    TARGET_RESOURCE_GROUP=$PROD_RESOURCE_GROUP
    TARGET_WORKSPACE_NAME=$PROD_WORKSPACE_NAME
    DATA_ASSET_NAME="diabetes-prod-folder"
    DATA_SOURCE_PATH="../production/data"
else
    TARGET_RESOURCE_GROUP=$DEV_RESOURCE_GROUP
    TARGET_WORKSPACE_NAME=$DEV_WORKSPACE_NAME
    DATA_ASSET_NAME="diabetes-dev-folder"
    DATA_SOURCE_PATH="../data/diabetes-data"
fi

echo "====================================================================="
echo "⚙️  MLOps CONDITIONAL PROVISIONING TRIGGERED"
echo "====================================================================="
echo "  Target Environment  : $ENVIRONMENT"
echo "  Target Resource Group: $TARGET_RESOURCE_GROUP"
echo "  Target Workspace Name: $TARGET_WORKSPACE_NAME"
echo "  Target Data Mapping : $DATA_ASSET_NAME ($DATA_SOURCE_PATH)"
echo "====================================================================="

# ---------------------------------------------------------------------------
# 📡 3. Register Core Azure Provider
# ---------------------------------------------------------------------------
echo "Registering the Machine Learning resource provider..."
az provider register --namespace $RESOURCE_PROVIDER

# ---------------------------------------------------------------------------
# 🌐 4. Provision the Central Shared Registry (Shared Layer)
# ---------------------------------------------------------------------------
# The registry is shared, so the script ensures it exists regardless of dev or prod flags
if ! az ml registry show --name "$REGISTRY_NAME" --resource-group "$REGISTRY_RESOURCE_GROUP" &>/dev/null; then
    echo "Creating shared registry resource group: $REGISTRY_RESOURCE_GROUP"
    az group create --name $REGISTRY_RESOURCE_GROUP --location $RANDOM_REGION

    echo "Rendering registry.yml placeholders dynamically..."
    sed \
        -e "s|REGISTRY_NAME_PLACEHOLDER|$REGISTRY_NAME|g" \
        -e "s|PRIMARY_REGION_PLACEHOLDER|$RANDOM_REGION|g" \
        registry.yml > registry.generated.yml

    echo "Deploying the shared central Azure ML registry..."
    az ml registry create \
        --file registry.generated.yml \
        --resource-group $REGISTRY_RESOURCE_GROUP
else
    echo "🔄 Shared central registry already exists. Skipping registry build..."
fi

# ---------------------------------------------------------------------------
# 🏗️ 5. Provision Environment-Specific Resource Group and Workspace
# ---------------------------------------------------------------------------
echo "Creating targeted environment resource group: $TARGET_RESOURCE_GROUP"
az group create --name $TARGET_RESOURCE_GROUP --location $RANDOM_REGION

echo "Creating targeted workspace instance: $TARGET_WORKSPACE_NAME"
az ml workspace create \
    --name $TARGET_WORKSPACE_NAME \
    --resource-group $TARGET_RESOURCE_GROUP \
    --location $RANDOM_REGION

# ---------------------------------------------------------------------------
# 💾 6. Isolate Isolated Environment Data Assets
# ---------------------------------------------------------------------------
echo "Configuring defaults context to: $TARGET_WORKSPACE_NAME"
az configure --defaults group=$TARGET_RESOURCE_GROUP workspace=$TARGET_WORKSPACE_NAME

echo "Registering target asset container [ $DATA_ASSET_NAME ] inside workspace..."
az ml data create \
    --type uri_folder \
    --name "$DATA_ASSET_NAME" \
    --path "$DATA_SOURCE_PATH"

echo "====================================================================="
echo "✅ SUCCESS: Conditional provisioning complete for [ $ENVIRONMENT ]."
echo "====================================================================="