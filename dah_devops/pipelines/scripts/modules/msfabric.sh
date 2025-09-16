#!/bin/bash -e

# The module file msfabric.sh is likely a shell script that contains various utility functions and configurations specific to managing or interacting with Microsoft Fabric services. 

msfabric_api_url="https://api.fabric.microsoft.com"

# Retrieves the capacity ID based on the capacity display name
get_capacity_id() {
  local capacity_display_name=$1
  local get_capacity_id_url="$msfabric_api_url/v1/capacities"
  response=$(az rest --method get \
    --url "$get_capacity_id_url" \
    --headers "Authorization=Bearer $token")

  if [ $? -ne 0 ]; then
    echo "Failed to get capacity ID of this capacity: $capacity_display_name"
    exit 1
  fi

  capacity_id=$(echo "$response" | jq -r --arg capacity_display_name "$capacity_display_name" '.value[] | select(.displayName == $capacity_display_name) | .id')
  echo "$capacity_id"
}

# Retrieves the list of workspaces based on workspace type and environment
get_workspace_id() {

  response=$(az rest --method get \
    --url "$msfabric_api_url/v1/workspaces" \
    --headers "Authorization=Bearer $token")

  if [ -z "$response" ]; then
    echo "Failed to retrieve workspaces. Please check the API and your token."
    exit 1
  fi

  echo $response
}

# retriev database parameters
get_database_parameters() {
    workspace_id=$1
    create_db_url="$msfabric_api_url/v1/workspaces/${workspace_id}/SqlDatabases"
    response=$(az rest --method get \
        --url "$create_db_url" \
        --headers "Authorization=Bearer $token" 
    )

    # Extract server FQDN and database name
    serverFqdn=$(echo "$response" | jq -r '.value[0].properties.serverFqdn' | cut -d "," -f1)
    databaseName=$(echo "$response" | jq -r '.value[0].properties.databaseName')

    # Return the values as a JSON object
    echo "{\"serverFqdn\":\"$serverFqdn\", \"databaseName\":\"$databaseName\"}"
}

# Retrieves the notebook ID based on the notebook name and workspace ID
get_nb_id() {
  local workspace_id=$1
  local notebook_name=$2

  get_nb_id_url="$msfabric_api_url/v1/workspaces/$workspace_id/notebooks"
  response=$(az rest --method get \
    --url "$get_nb_id_url" \
    --headers "Authorization=Bearer $token")

  if [ -z "$response" ]; then
    echo "Failed to retrieve notebooks. Please check the API and your token."
    exit 1
  fi

  nb_id=$(echo "$response" | jq -r --arg notebook_name "$notebook_name" '.value[] | select(.displayName == $notebook_name) | .id')

  echo "$nb_id"
}

# Retrieves the deployment pipeline ID for the given workspace type
get_deployment_pipeline_id() {
  local workspace_type=$1
  get_deployment_pipeline_id_url="$msfabric_api_url/v1/deploymentPipelines"
  response=$(az rest --method get \
    --url "$get_deployment_pipeline_id_url" \
    --headers "Authorization=Bearer $token")
  
  id=$(echo "$response" | jq -r --arg workspace_type "$workspace_type" '.value[] | select(.displayName | test($workspace_type; "i")) | .id')
  
  if [ -z "$id" ]; then
    echo "No ID found for workspace type containing '$workspace_type'"
  else
    echo "$id"
  fi
}

# Retrieves deployment pipeline stage IDs based on source and target environments
list_deployment_pipeline_stages() {
  env_source_stage=$1
  env_target_stage=$2
  deployment_pipeline_id=$3
  list_deployment_pipeline_stages_url="$msfabric_api_url/v1/deploymentPipelines/$deployment_pipeline_id/stages"

  response=$(az rest --method get \
    --url "$list_deployment_pipeline_stages_url" \
    --headers "Authorization=Bearer $token")

  case "$env_source_stage" in
    "DEV"|"SIT"|"UAT"|"PRD")
      source_deployment_stage=$(echo "$response" | jq -r --arg env "$env_source_stage" '.value[] | select(.displayName == $env) | .id')
      ;;
    *)
      echo "Invalid source environment. Please specify DEV, SIT, UAT, or PRD."
      exit 1
      ;;
  esac

  case "$env_target_stage" in
    "DEV"|"SIT"|"UAT"|"PRD")
      target_deployment_stage=$(echo "$response" | jq -r --arg env "$env_target_stage" '.value[] | select(.displayName == $env) | .id')
      ;;
    *)
      echo "Invalid target environment. Please specify DEV, SIT, UAT, or PRD."
      exit 1
      ;;
  esac

  result=$(jq -n --arg source_id "$source_deployment_stage" --arg target_id "$target_deployment_stage" '{sourceStageId: $source_id, targetStageId: $target_id}')
  echo "$result"
}

# Retrieves lakehouse ID and name for the given workspace
get_lakehouse_id_and_name() {
  local workspace_id=$1
  api_version="2021-06-01"
  get_lakehouse_id_url="$msfabric_api_url/v1/workspaces/$workspace_id/lakehouses?api-version=$api_version"

  response=$(az rest --method get \
    --url "$get_lakehouse_id_url" \
    --headers "Authorization=Bearer $token")

  echo "$response"
}

get_connection_id() {
    local environment=$1
    local type=$2
    response=$(az rest --method get \
                --url "$msfabric_api_url/v1/connections" \
                --headers "Authorization=Bearer $token")
    echo "$response" | jq -r --arg environment "$environment" --arg type "$type" '.value[] | select(.displayName == ("GFCS_DAH_" + $environment + "_" + $type)) | .id'
}

get_data_pipeline_id() {
    local sdl_workspace_id=$1
    response=$(az rest --method get \
                --url "$msfabric_api_url/v1/workspaces/${sdl_workspace_id}/items" \
                --headers "Authorization=Bearer $token")
    echo "$response" | jq -r '.value[] | select(.displayName == "99_S4_Sales_br_cpl") | .id'
}

get_sql_database_id() {
    local workspace_id=$1

    response=$(az rest --method get \
                --url "$msfabric_api_url/v1/workspaces/${workspace_id}/items" \
                --headers "Authorization=Bearer $token")
    echo "$response" | jq -r '.value[] | select(.displayName == "system_db" and .type == "SQLDatabase") | .id'
}

