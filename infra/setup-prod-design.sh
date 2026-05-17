#!/bin/bash
# setup-prod-design.sh
# Complete provisioning script for the "Plan and prepare an MLOps solution" lab.

# ---------------------------------------------------------------------------
# 1. Environment Variable Declarations
# ---------------------------------------------------------------------------
guid=$(cat /proc/sys/kernel/random/uuid)
suffix=${guid//[-]/}
suffix=${suffix:0:6} # Forces safe character limits for Azure ML Registry names

export RANDOM_REGION="eastus" # Using 'eastus' based on your successful log region

# Dev environment naming variables
export DEV_RESOURCE_GROUP="rg-mlops-dev-${suffix}"
export DEV_WORKSPACE_NAME="mlw-mlops-dev-${suffix}"

# Prod environment naming variables
export PROD_RESOURCE_GROUP="rg-mlops-prod-${suffix}"
export PROD_WORKSPACE_NAME="mlw-mlops-prod-${suffix}"

# Shared registry naming variables
export REGISTRY_RESOURCE_GROUP="rg-mlops-reg-${suffix}"
export REGISTRY_NAME="mlrmlopsshared${suffix}"

# Core cluster constants
export RESOURCE_PROVIDER="Microsoft.MachineLearningServices"

echo "====================================================================="
echo "⚙️ MLOps ARCHITECTURE SETUP RUNNING WITH SUFFIX: [ ${suffix} ]"
echo "====================================================================="

# ---------------------------------------------------------------------------
# 2. Resource Provider Registration
# ---------------------------------------------------------------------------
echo "Registering the Machine Learning resource provider..."
az provider register --namespace $RESOURCE_PROVIDER

# ---------------------------------------------------------------------------
# 🛠️ 3. Development Resource Group and Workspace Provisioning (ADDED FIX)
# ---------------------------------------------------------------------------
echo "Creating dev resource group: $DEV_RESOURCE_GROUP"
az group create --name $DEV_RESOURCE_GROUP --location $RANDOM_REGION

echo "Creating dev workspace instance: $DEV_WORKSPACE_NAME"
az ml workspace create \
    --name $DEV_WORKSPACE_NAME \
    --resource-group $DEV_RESOURCE_GROUP \
    --location $RANDOM_REGION

# ---------------------------------------------------------------------------
# 🌐 4. Shared Registry Provisioning
# ---------------------------------------------------------------------------
echo "Creating registry resource group: $REGISTRY_RESOURCE_GROUP"
az group create --name $REGISTRY_RESOURCE_GROUP --location $RANDOM_REGION

echo "Rendering registry.yml placeholders dynamically..."
sed \
    -e "s|REGISTRY_NAME_PLACEHOLDER|$REGISTRY_NAME|g" \
    -e "s|PRIMARY_REGION_PLACEHOLDER|$RANDOM_REGION|g" \
    registry.yml > registry.generated.yml

echo "Creating central shared Azure ML asset registry..."
az ml registry create \
    --file registry.generated.yml \
    --resource-group $REGISTRY_RESOURCE_GROUP

# ---------------------------------------------------------------------------
# 🚀 5. Production Resource Group and Workspace Provisioning
# ---------------------------------------------------------------------------
echo "Creating prod resource group: $PROD_RESOURCE_GROUP"
az group create --name $PROD_RESOURCE_GROUP --location $RANDOM_REGION

echo "Creating prod workspace instance: $PROD_WORKSPACE_NAME"
az ml workspace create \
    --name $PROD_WORKSPACE_NAME \
    --resource-group $PROD_RESOURCE_GROUP \
    --location $RANDOM_REGION

# ---------------------------------------------------------------------------
# 💾 6. Isolate Development and Production Data Assets
# ---------------------------------------------------------------------------
# Step 6a: Connect to the dev workspace and register the experimentation data
echo "Connecting focus context to Dev Workspace to register training assets..."
az configure --defaults group=$DEV_RESOURCE_GROUP workspace=$DEV_WORKSPACE_NAME

az ml data create \
    --type uri_folder \
    --name diabetes-dev-folder \
    --path ../data/diabetes-data

# Step 6b: Switch contexts to the prod workspace and register production data asset
echo "Switching configuration context focus to Production Workspace..."
az configure --defaults group=$PROD_RESOURCE_GROUP workspace=$PROD_WORKSPACE_NAME

az ml data create \
    --type uri_folder \
    --name diabetes-prod-folder \
    --path ../production/data

echo "====================================================================="
echo "💥 PROVISIONING WORKFLOW GENERATION COMPLETE"
echo "====================================================================="