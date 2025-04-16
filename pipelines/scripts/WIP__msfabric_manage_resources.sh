#!/bin/bash -e

##########################
##### WORK IN PROGRESS...
##########################

if [ -f "pipelines/scripts/modules/msfabric.sh" ]; then
  source pipelines/scripts/modules/msfabric.sh
else
  echo "Module file pipelines/scripts/modules/msfabric.sh not found!"
  exit 1
fi

workspaces_list=$1
# msfabric_deployment_pipeline_source_stage_id=$2
# msfabric_deployment_pipeline_target_stage_id=$3

create_db() {
  workspace_id=$1
  database_name=$2
  api_url="$msfabric_api_url/v1/workspaces/$workspace_id/items"

  request_body=$(cat <<EOF
{
  "displayName": "$database_name",
  "type": "SQLDatabase",
  "description": "Created using Bash script"
}
EOF
  )

  response=$(curl -s -X POST "$api_url" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$request_body")

  echo $response
}

create_notebook() {
  local workspace_id=$1
  local nb_payload=$2
  local create_notebook_url="$msfabric_api_url/v1/workspaces/$workspace_id/items"

  # Request Body
  body=$(cat <<EOF
{
  "displayName": "Notebook53",
  "type": "Notebook",
  "definition": {
    "format": "ipynb",
    "parts": [
      {
        "path": "./abc/notebook-content.ipynb",
        "payload": "$nb_payload",
        "payloadType": "InlineBase64"
      }
    ]
  }
}
EOF
  )

  response=$(curl -X POST "$create_notebook_url" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$body")

  echo "Create Notebook Response: $response"
}

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

# Get Access Token
token=$(az account get-access-token --resource $msfabric_api_url --query accessToken --output tsv)
echo "Access Token: $token"

if [ -z "$token" ]; then
  echo "Failed to obtain access token. Please check your Azure credentials and permissions."
  exit 1
fi

echo "Processing workspace: $workspaces_list"
get_workspace_id=$(get_workspace_id "GFCS SIT IDL")
workspace_id=$(echo $get_workspace_id | jq -r --arg workspace_name "$workspace_name" '.value[] | select(.displayName == $workspace_name) | .id')
echo "Workspace ID: $workspace_id"

if [ -z "$workspace_id" ]; then
  echo "Workspace ID not found for $workspaces_list"
else
  echo "Creating new notebook..."
  # lakehouse_info=$(get_lakehouse_id_and_name "$workspace_id")
  # modified_payload=$(echo "$nb_payload" | jq --arg workspace_id "$workspace_id" '.metadata.dependencies.environment.workspaceId = $workspace_id' | jq '.metadata.dependencies.environment.environmentId = "abcd"' | base64)
  # create_notebook "$workspace_id" "$modified_payload"
  create_db "$workspace_id" "testDB"
fi
