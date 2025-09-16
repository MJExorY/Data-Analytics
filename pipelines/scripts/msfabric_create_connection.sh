#!/bin/bash -e
################################################################################
# MS Fabric Connection Management Script
# 
# Purpose: Automates creation and management of connections in MS Fabric
# Status: WIP - ADF connection creation not supported by Microsoft API
# Reference: https://learn.microsoft.com/en-us/rest/api/fabric/core/connections/create-connection?tabs=HTTP
################################################################################

set -euo pipefail

# Script constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MODULE_PATH="dah_devops/pipelines/scripts/modules/msfabric.sh"
readonly CONNECTION_WAIT_TIME=15

# Load required module
if [ -f "$MODULE_PATH" ]; then
  source "$MODULE_PATH"
else
  echo "##[error]Module file $MODULE_PATH not found!"
  exit 1
fi

print_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

DESCRIPTION:
  This script automates the creation of connections in Microsoft Fabric for Dataverse.
  It supports creating, deleting, and managing role assignments for connections.

OPTIONS:
  --env <environment_name>
      Specifies the environment name (e.g., dev, prod). This is used to identify 
      the workspace and other environment-specific configurations.

  --connection-name <name>
      The name of the connection to be created. This will be displayed as the 
      'displayName' in the Microsoft Fabric API.

  --fabric-setup-admin-principal-key <key>
      The secret key for the MS Fabric Admin Principal. Required for authentication.

  --fabric-setup-admin-principal-id <id>
      The client ID of the MS Fabric Admin Principal. Required for authentication.

  --tenant-id <id>
      The tenant ID for Azure Active Directory. Required for authentication.

  --dataverse-storage-container <container_name>
      Required only for Dataverse connections. Specifies the name of the Azure 
      Data Lake Storage container used for Dataverse.

  --action <action_type>
      Specifies the action to perform. Valid options are:
        - 'create_dataverse_conn': Creates a connection for Dataverse.
        - 'create_adf_conn': Creates a connection for ADF (currently not working).

  --help
      Displays this help message.

EXAMPLES:
  # Create Dataverse connection
  $(basename "$0") --env prod --connection-name "MyConnection" \\
    --fabric-setup-admin-principal-key "****" \\
    --fabric-setup-admin-principal-id "guid" \\
    --tenant-id "guid" \\
    --dataverse-storage-container "mycontainer" \\
    --action create_dataverse_conn

EOF
}

# Parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env)
        environment="$2"
        shift 2
        ;;
      --connection-name)
        connection_name="$2"
        shift 2
        ;;
      --fabric-setup-admin-principal-key)
        fabric_setup_admin_principal_key="$2"
        shift 2
        ;;
      --fabric-setup-admin-principal-id)
        fabric_setup_admin_principal_id="$2"
        shift 2
        ;;
      --tenant-id)
        tenant_id="$2"
        shift 2
        ;;
      --dataverse-storage-container)
        dataverse_storage_container="$2"
        shift 2
        ;;
      --action)
        action="$2"
        shift 2
        ;;
      --help)
        print_help
        exit 0
        ;;
      *)
        echo "##[error]Unknown parameter: $1"
        print_help
        exit 1
        ;;
    esac
  done
}

# Validate required arguments
validate_arguments() {
  local missing_args=()
  
  [[ -z "${connection_name:-}" ]] && missing_args+=("--connection-name")
  [[ -z "${fabric_setup_admin_principal_key:-}" ]] && missing_args+=("--fabric-setup-admin-principal-key")
  [[ -z "${fabric_setup_admin_principal_id:-}" ]] && missing_args+=("--fabric-setup-admin-principal-id")
  [[ -z "${tenant_id:-}" ]] && missing_args+=("--tenant-id")
  [[ -z "${environment:-}" ]] && missing_args+=("--env")
  [[ -z "${action:-}" ]] && missing_args+=("--action")
  
  if [[ ${#missing_args[@]} -gt 0 ]]; then
    echo "##[error]Missing required arguments: ${missing_args[*]}"
    print_help
    exit 1
  fi
  
  # Validate action
  if [[ "$action" != "create_dataverse_conn" && "$action" != "create_adf_conn" ]]; then
    echo "##[error]Invalid action: $action"
    echo "Valid actions are: create_dataverse_conn, create_adf_conn"
    exit 1
  fi
  
  # Additional validation for dataverse action
  if [[ "$action" == "create_dataverse_conn" && -z "${dataverse_storage_container:-}" ]]; then
    echo "##[error]Missing required argument for Dataverse connection: --dataverse-storage-container"
    exit 1
  fi
}

# Display configuration
display_configuration() {
  echo "##[section]Connection Configuration"
  echo "Environment: $environment"
  echo "Connection Name: $connection_name"
  echo "MS Fabric Setup Admin Principal ID: $fabric_setup_admin_principal_id"
  echo "MS Fabric Setup Admin Principal KEY: [HIDDEN]"
  echo "Tenant ID: $tenant_id"
  [[ -n "${dataverse_storage_container:-}" ]] && echo "Dataverse Storage Container: $dataverse_storage_container"
  echo "Action: $action"
  echo ""
}

# Get access token
get_access_token() {
  echo "##[command]Getting access token..."
  token=$(az account get-access-token --resource "$msfabric_api_url" --query accessToken --output tsv)
  
  if [[ -z "$token" ]]; then
    echo "##[error]Failed to get access token"
    exit 1
  fi
  
  echo "##[section]Access token obtained successfully"
}

list_existing_connections() {
  echo "##[command]Listing existing connections..."
  
  response=$(az rest --method get \
    --url "$msfabric_api_url/v1/connections" \
    --headers "Authorization=Bearer $token")
  
  if [[ $? -ne 0 ]]; then
    echo "##[error]Failed to list connections"
    exit 1
  fi
  
  echo "$response"
}

delete_connection() {
  local connection_id=$1
  
  echo "##[command]Deleting connection with ID: $connection_id"
  
  az rest --method delete \
    --url "$msfabric_api_url/v1/connections/${connection_id}" \
    --headers "Authorization=Bearer $token"
  
  if [[ $? -eq 0 ]]; then
    echo "##[section]Connection deleted successfully"
  else
    echo "##[warning]Failed to delete connection"
  fi
}

# TODO: Fix this function - currently not working due to MS API limitations
create_adf_connection() {
  local fabric_setup_admin_principal_key=$1
  local fabric_setup_admin_principal_id=$2
  local tenant_id=$3
  
  echo "##[warning]ADF connection creation is currently not supported by Microsoft API"
  
  local json_body
  json_body=$(cat <<EOF
{
  "connectivityType": "ShareableCloud",
  "displayName": "$connection_name",
  "connectionDetails": {
    "type": "AzureDataFactory",
    "creationMethod": "AzureDataFactory.Actions",
    "parameters": [
      {
        "dataType": "Text",
        "name": "subscriptionId",
        "value": "cf329f3a-318f-45e5-9130-7a2a40d8cb6f"
      },
      {
        "dataType": "Text",
        "name": "resourceGroup",
        "value": "GFCS-P-EUW-RG-10093553-DAH-I"
      },
      {
        "dataType": "Text",
        "name": "dataFactoryName",
        "value": "gfcsneuwadf001i"
      }
    ]
  },
  "privacyLevel": "Organizational",
  "credentialDetails": {
    "singleSignOnType": "None",
    "connectionEncryption": "NotEncrypted",
    "skipTestConnection": false,
    "credentials": {
      "credentialType": "ServicePrincipal",
      "servicePrincipalClientId": "${fabric_setup_admin_principal_id}",
      "servicePrincipalSecret": "${fabric_setup_admin_principal_key}",
      "tenantId": "${tenant_id}"
    }
  }
}
EOF
)

  response=$(az rest --method post \
    --url "$msfabric_api_url/v1/connections" \
    --headers "Authorization=Bearer $token" \
    --headers "Content-Type=application/json" \
    --body "$json_body" \
    --resource "$msfabric_api_url")
  
  local connection_id
  connection_id=$(echo "$response" | jq -r '.id // empty')
  
  if [[ -z "$connection_id" ]]; then
    echo "##[error]Failed to create ADF connection"
    echo "Response: $response"
    exit 1
  fi
  
  echo "$connection_id"
}

create_dataverse_connection() {
  local fabric_setup_admin_principal_key=$1
  local fabric_setup_admin_principal_id=$2
  local tenant_id=$3
  local dataverse_container_name=$4
  
  echo "##[command]Creating Dataverse connection..."
  
  local json_body
  json_body=$(cat <<EOF
{
  "connectivityType": "ShareableCloud",
  "displayName": "$connection_name",
  "connectionDetails": {
    "type": "AzureDataLakeStorage",
    "creationMethod": "AzureDataLakeStorage",
    "parameters": [
      {
        "dataType": "Text",
        "name": "server",
        "value": "https://${dataverse_storage_container}.dfs.core.windows.net"
      },
      {
        "dataType": "Text",
        "name": "path",
        "value": "$dataverse_container_name"
      }
    ]
  },
  "privacyLevel": "Organizational",
  "credentialDetails": {
    "singleSignOnType": "None",
    "connectionEncryption": "NotEncrypted",
    "skipTestConnection": false,
    "credentials": {
      "credentialType": "ServicePrincipal",
      "servicePrincipalClientId": "$fabric_setup_admin_principal_id",
      "servicePrincipalSecret": "$fabric_setup_admin_principal_key",
      "tenantId": "$tenant_id"
    }
  }
}
EOF
)

  response=$(az rest --method post \
    --url "$msfabric_api_url/v1/connections" \
    --headers "Authorization=Bearer $token" \
    --headers "Content-Type=application/json" \
    --body "$json_body" \
    --resource "$msfabric_api_url")
  
  local connection_id
  connection_id=$(echo "$response" | jq -r '.id // empty')
  
  if [[ -z "$connection_id" ]]; then
    echo "##[error]Failed to create Dataverse connection"
    echo "Response: $response"
    exit 1
  fi
  
  echo "##[section]Connection created with ID: $connection_id"
  echo "$connection_id"
}

create_connection_role_assignment() {
  local connection_id=$1
  
  echo "##[section]Creating role assignments for connection"
  
  # Define role assignments
  local -a principal_assignments=(
    "d9cdc1c5-97e9-4f41-b854-bcf5d1d77332:group:User"  # GRPAAD_CS_DAH_DataEngineers
    "eb7aa397-616f-48c2-8187-65614b13a534:group:Owner" # GRPAAD_CS_DAH_InfrastructureEngineers
    "a7c91457-a48e-48fa-ba3a-9bf151203ce6:group:Owner" # GRPAAD_CS_DAH_Admins
    # HACK: for DEV purposes ONLY!
    "73544100-f313-45c4-a248-c7c55ee3ad82:user:Owner"  # Ekici, Muhammed Kasim - Owner
  )
  
  local success_count=0
  local failed_count=0
  
  for assignment in "${principal_assignments[@]}"; do
    IFS=':' read -r principal_id principal_type role_name <<< "$assignment"
    
    local request_body
    request_body=$(cat <<EOF
{
  "principal": {
    "id": "$principal_id",
    "type": "$principal_type"
  },
  "role": "$role_name"
}
EOF
)
    
    echo "##[command]Assigning role '$role_name' to $principal_type: $principal_id"
    
    if az rest --method post \
            --url "$msfabric_api_url/v1/connections/${connection_id}/roleAssignments" \
            --headers "Authorization=Bearer $token" \
            --headers "Content-Type=application/json" \
            --body "$request_body" \
            --resource "$msfabric_api_url" >/dev/null 2>&1; then
      echo "✓ Role assignment successful"
      ((success_count++))
    else
      echo "✗ Role assignment failed"
      ((failed_count++))
    fi
  done
  
  echo ""
  echo "##[section]Role assignment summary: $success_count successful, $failed_count failed"
}

# Main execution
main() {
  echo "##[section]MS Fabric Connection Management Script"
  echo "============================================"
  echo ""
  
  # Parse and validate arguments
  parse_arguments "$@"
  validate_arguments
  display_configuration
  
  # Get access token
  get_access_token
  
  # Check for existing connection
  echo "##[section]Checking for existing connection"
  connection_id=$(list_existing_connections | jq -r --arg name "$connection_name" '.value[] | select(.displayName == $name) | .id // empty')
  
  if [[ -n "$connection_id" ]]; then
    echo "##[warning]Found existing connection with ID: $connection_id"
    delete_connection "$connection_id"
    echo "##[command]Waiting $CONNECTION_WAIT_TIME seconds for deletion to complete..."
    sleep $CONNECTION_WAIT_TIME
  else
    echo "##[section]No existing connection found with name: $connection_name"
  fi
  
  # Create new connection based on action
  echo ""
  echo "##[section]Creating new connection"
  
  local new_connection_id
  
  if [[ "$action" == "create_dataverse_conn" ]]; then
    # Get dataverse container name
    echo "##[command]Getting Dataverse container name..."
    dataverse_existing_container_name=$(az storage container list \
      --account-name "$dataverse_storage_container" \
      --prefix dataverse \
      --auth-mode login \
      --query "[].name" \
      --output tsv)
    
    if [[ -z "$dataverse_existing_container_name" ]]; then
      echo "##[error]No Dataverse container found in storage account: $dataverse_storage_container"
      exit 1
    fi
    
    echo "##[section]Found Dataverse container: $dataverse_existing_container_name"
    
    # Create Dataverse connection
    new_connection_id=$(create_dataverse_connection \
      "$fabric_setup_admin_principal_key" \
      "$fabric_setup_admin_principal_id" \
      "$tenant_id" \
      "$dataverse_existing_container_name")
      
  elif [[ "$action" == "create_adf_conn" ]]; then
    # Create ADF connection
    new_connection_id=$(create_adf_connection \
      "$fabric_setup_admin_principal_key" \
      "$fabric_setup_admin_principal_id" \
      "$tenant_id")
  fi
  
  # Create role assignments
  create_connection_role_assignment "$new_connection_id"
  
  echo ""
  echo "##[section]Connection '$connection_name' created successfully!"
  echo "Connection ID: $new_connection_id"
}

# Execute main function
main "$@"