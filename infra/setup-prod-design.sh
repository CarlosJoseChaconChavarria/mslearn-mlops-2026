#!/bin/bash
# setup-prod-design.sh
# Complete provisioning script for the "Plan and prepare an MLOps solution" lab.

# ---------------------------------------------------------------------------
# 1. Environment Variable Declarations (Added at the top of the file)
# ---------------------------------------------------------------------------
# Existing random suffix generation
guid=$(cat /proc/sys/kernel/random/uuid)
suffix=${guid//[-]/}
suffix=${suffix:0:6}

# Dev environment naming variables
DEV_RESOURCE_GROUP="rg-ai300-dev-${suffix}"
DEV_WORKSPACE_NAME="mlw-ai300-dev-${suffix}"

# Prod environment naming variables
PROD_RESOURCE_GROUP="rg-ai300-prod-${suffix}"
PROD_WORKSPACE_NAME="mlw-ai300-prod-${suffix}"

# Shared registry naming variables (one per subscription/region)
REGISTRY_RESOURCE_GROUP="rg-ai300-reg-${suffix}"
REGISTRY_NAME="mlr-ai300-shared-${suffix}"

# Core cluster constants inherited from original setup.sh properties
COMPUTE_INSTANCE="ci${suffix}"
COMPUTE_CLUSTER="aml-cluster"
RESOURCE_PROVIDER="Microsoft.MachineLearningServices"
REGIONS=("eastus" "westus")
RANDOM_REGION=${REGIONS[$RANDOM % ${#REGIONS[@]}]}

# ---------------------------------------------------------------------------
# 2. Resource Provider Registration
# ---------------------------------------------------------------------------
echo "Registering the Machine Learning resource provider..."
az provider register --namespace $RESOURCE_PROVIDER

# ---------------------------------------------------------------------------
# 3. Plan: Shared Registry Provisioning (Step 4 Block)
# ---------------------------------------------------------------------------
echo "Creating registry resource group: $REGISTRY_RESOURCE_GROUP"
az group create --name $REGISTRY_RESOURCE_GROUP --location $RANDOM_REGION

echo "Rendering registry.yml placeholders dynamically with standard local values..."
sed \
    -e "s|REGISTRY_NAME_PLACEHOLDER|$REGISTRY_NAME|g" \
    -e "s|PRIMARY_REGION_PLACEHOLDER|$RANDOM_REGION|g" \
    registry.yml > registry.generated.yml

echo "Creating central shared Azure ML asset registry..."
az ml registry create \
    --file registry.generated.yml \
    --resource-group $REGISTRY_RESOURCE_GROUP

# ---------------------------------------------------------------------------
# 4. Plan: Production Resource Group and Workspace Provisioning
# ---------------------------------------------------------------------------
echo "Creating prod resource group: $PROD_RESOURCE_GROUP"
az group create --name $PROD_RESOURCE_GROUP --location $RANDOM_REGION

echo "Creating prod workspace instance: $PROD_WORKSPACE_NAME"
az ml workspace create \
    --name $PROD_WORKSPACE_NAME \
    --resource-group $PROD_RESOURCE_GROUP \
    --location $RANDOM_REGION

# ---------------------------------------------------------------------------
# 5. Plan: Isolate Development and Production Data Assets
# ---------------------------------------------------------------------------
# Step 5a: In the dev workspace, register the experimentation data asset
echo "Connecting focus context to Dev Workspace to register training metrics..."
az configure --defaults group=$DEV_RESOURCE_GROUP workspace=$DEV_WORKSPACE_NAME

az ml data create \
    --type uri_folder \
    --name diabetes-dev-folder \
    --path ../data/diabetes-data

# Step 5b: Switch contexts to the prod workspace and register production data asset
echo "Switching configuration context focus to Production Workspace..."
az configure --defaults group=$PROD_RESOURCE_GROUP workspace=$PROD_WORKSPACE_NAME

az ml data create \
    --type uri_folder \
    --name diabetes-prod-folder \
    --path ../production/data

echo "====================================================================="
echo "💥 PROVISIONING WORKFLOW GENERATION COMPLETE"
echo "====================================================================="