#!/bin/bash
# setup-mlops-envs.sh
# Complete provisioning script for the "Plan and prepare an MLOps solution" lab.
# Creates a dev workspace, a prod workspace, and a shared Azure ML registry,
# each in their own resource group with isolated data assets.

# ---------------------------------------------------------------------------
# 🌍 1. Centralized Variable Definitions (Deterministic & Safe Suffixes)
# ---------------------------------------------------------------------------
# Create a short 6-character unique identifier to bypass resource name naming collisions
guid=$(cat /proc/sys/kernel/random/uuid)
suffix=${guid//[-]/}
suffix=${suffix:0:6}

# Global Cloud Configuration
export LOCATION="eastus" # Low-cost, highly-stable region
export RESOURCE_PROVIDER="Microsoft.MachineLearningServices"

# Shared Azure ML Registry Environment
export SHARED_RESOURCE_GROUP="rg-proseware-shared-${suffix}"
export REGISTRY_NAME="regprosewareshared${suffix}"

# 🛠️ Environment 1: Development Workspace (Experimentation)
export DEV_RESOURCE_GROUP="rg-proseware-dev-${suffix}"
export DEV_WORKSPACE_NAME="mlw-proseware-dev-${suffix}"
export DEV_COMPUTE_INSTANCE="ci-dev-${suffix}"
export DEV_COMPUTE_CLUSTER="aml-cluster-dev"

# 🚀 Environment 2: Production Workspace ( retraining & Stable Serving)
export PROD_RESOURCE_GROUP="rg-proseware-prod-${suffix}"
export PROD_WORKSPACE_NAME="mlw-proseware-prod-${suffix}"
export PROD_COMPUTE_CLUSTER="aml-cluster-prod"

echo "✅ Variables configured smoothly with deployment token suffix: [ ${suffix} ]"

# ---------------------------------------------------------------------------
# 📡 2. Register Resource Providers
# ---------------------------------------------------------------------------
echo "Registering the Azure Machine Learning resource provider..."
az provider register --namespace $RESOURCE_PROVIDER

# ---------------------------------------------------------------------------
# 🛠️ 3. Development Environment Provisioning
# ---------------------------------------------------------------------------
echo "Creating DEV resource group: $DEV_RESOURCE_GROUP"
az group create --name $DEV_RESOURCE_GROUP --location $LOCATION

echo "Creating DEV workspace: $DEV_WORKSPACE_NAME"
az ml workspace create --name $DEV_WORKSPACE_NAME --resource-group $DEV_RESOURCE_GROUP --location $LOCATION

# Set CLI contexts natively
az configure --defaults group=$DEV_RESOURCE_GROUP workspace=$DEV_WORKSPACE_NAME

echo "Creating low-cost compute instance for Dev workspace..."
az ml compute create --name $DEV_COMPUTE_INSTANCE \
                     --type ComputeInstance \
                     --size Standard_DS2_v2

echo "Creating low-cost autoscaling cluster for Dev workspace (Enforcing 0 Min instances)..."
az ml compute create --name $DEV_COMPUTE_CLUSTER \
                     --type AmlCompute \
                     --size Standard_DS2_v2 \
                     --min-instances 0 \
                     --max-instances 2 \
                     --idle-time-before-scale-down 900

echo "Creating Development ML Data Assets..."
az ml data create --type mltable --name "diabetes-training" --path ./data/diabetes-data
az ml data create --type uri_file --name "diabetes-data" --path ./data/diabetes-data/diabetes.csv
az ml data create --type uri_folder --name "diabetes-dev-folder" --path ./data/diabetes-data

# ---------------------------------------------------------------------------
# 🚀 4. Production Environment Provisioning
# ---------------------------------------------------------------------------
echo "Creating PROD resource group: $PROD_RESOURCE_GROUP"
az group create --name $PROD_RESOURCE_GROUP --location $LOCATION

echo "Creating PROD workspace: $PROD_WORKSPACE_NAME"
az ml workspace create --name $PROD_WORKSPACE_NAME --resource-group $PROD_RESOURCE_GROUP --location $LOCATION

az configure --defaults group=$PROD_RESOURCE_GROUP workspace=$PROD_WORKSPACE_NAME

echo "Creating low-cost autoscaling cluster for Prod workspace..."
az ml compute create --name $PROD_COMPUTE_CLUSTER \
                     --type AmlCompute \
                     --size Standard_DS2_v2 \
                     --min-instances 0 \
                     --max-instances 2 \
                     --idle-time-before-scale-down 900

echo "Creating Production ML Data Asset..."
az ml data create \
    --type uri_folder \
    --name "diabetes-prod-folder" \
    --path ./production/data

# ---------------------------------------------------------------------------
# 🌐 5. Shared Central Registry Provisioning
# ---------------------------------------------------------------------------
echo "Creating Shared Registry Resource Group: $SHARED_RESOURCE_GROUP"
az group create --name $SHARED_RESOURCE_GROUP --location $LOCATION

echo "Rendering registry.yml dynamically with standard low-cost variables..."
cat <<EOF > infra/registry.generated.yml
\$schema: https://azuremlschemas.azureedge.net/latest/registry.schema.json
name: ${REGISTRY_NAME}
location: ${LOCATION}
description: Central shared registry for Proseware multi-disease models.
tags:
  tier: shared-assets
  billing: low-cost
EOF

echo "Creating central Azure Machine Learning registry: $REGISTRY_NAME"
az ml registry create \
    --file infra/registry.generated.yml \
    --resource-group $SHARED_RESOURCE_GROUP

# ---------------------------------------------------------------------------
# 📊 6. Output Deployment Summary
# ---------------------------------------------------------------------------
echo "====================================================================="
echo "💥 PROVISIONING INFRASTRUCTURE COMPLETE"
echo "====================================================================="
echo "  Dev Environment Workspace  : $DEV_WORKSPACE_NAME ($DEV_RESOURCE_GROUP)"
echo "  Prod Environment Workspace : $PROD_WORKSPACE_NAME ($PROD_RESOURCE_GROUP)"
echo "  Central Shared Registry    : $REGISTRY_NAME ($SHARED_RESOURCE_GROUP)"
echo "====================================================================="
echo "⚠️ ANTI-BILLING ADVICE: When finished with this session, execute:"
echo "   az group delete --name $DEV_RESOURCE_GROUP --yes --no-wait"
echo "   az group delete --name $PROD_RESOURCE_GROUP --yes --no-wait"
echo "   az group delete --name $SHARED_RESOURCE_GROUP --yes --no-wait"
echo "====================================================================="