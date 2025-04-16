#!/bin/bash -e

# Example usage: ./pipelines/scripts/msfabric_trigger_deployment_pipeline 'DEV' 'SIT' 'IDL'

###############################################
###### WORK IN PROGRESS...
###############################################

if [ -f "pipelines/scripts/modules/msfabric.sh" ]; then
  source pipelines/scripts/modules/msfabric.sh
else
  echo "Module file pipelines/scripts/modules/msfabric.sh not found!"
  exit 1
fi

# Parameters
env_source_stage=$1  # DEV or SIT or UAT or PRD
env_target_stage=$2  # DEV or SIT or UAT or PRD
# TODO: workspace_type is obsolete. The entire code logic must be refactored!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
workspace_type=$3  # IDL or SDL or CDL  

# Function to deploy all resources from the source stage to the target stage
deploy_all_resources_from_target_stage_to_source_stage() {
  local msfabric_deployment_pipeline_id=$1
  local msfabric_deployment_pipeline_source_stage_id=$2
  local msfabric_deployment_pipeline_target_stage_id=$3
  
  deployment_pipeline_id=$msfabric_deployment_pipeline_id
  deployment_url="$msfabric_api_url/v1/deploymentPipelines/$deployment_pipeline_id/deploy"

  body=$(cat <<EOF
{
  "sourceStageId": $msfabric_deployment_pipeline_source_stage_id,
  "targetStageId": $msfabric_deployment_pipeline_target_stage_id,
  "items": [
    {
      "sourceItemId": "9b72fee7-2053-4375-bd94-3a7e850b5030",
      "itemType": "Notebook"
    }
  ],
  "note": "Deploying resources."
}
EOF
  )

  response=$(az rest --method post \
    --url "$deployment_url" \
    --headers "Authorization=Bearer $token" \
    --body "$body")

  echo "$response"
}

# Acquire the access token
token=$(az account get-access-token --resource $msfabric_api_url --query accessToken --output tsv)
echo "Access Token: $token"

if [ -z "$token" ]; then
  echo "Failed to obtain access token. Please check your Azure credentials and permissions."
  exit 1
fi

# Retrieve the deployment pipeline ID based on workspace type
msfabric_deployment_pipeline_id=$(get_deployment_pipeline_id "$workspace_type")

# List the stages of the deployment pipeline
deployment_stages=$(list_deployment_pipeline_stages "$env_source_stage" "$env_target_stage" "$msfabric_deployment_pipeline_id")

# Extract the source and target stage IDs
source_stage=$(echo $deployment_stages | jq .sourceStageId)
target_stage=$(echo $deployment_stages | jq .targetStageId)

# Deploy all resources from the source stage to the target stage
deploy_all_resources_from_target_stage_to_source_stage "$msfabric_deployment_pipeline_id" "$source_stage" "$target_stage"
