#!/bin/bash -e
################################
############ WIP
##### TODO: solve the issue to create connection for ADF which looks to be not supported by Microsoft: https://learn.microsoft.com/en-us/rest/api/fabric/core/connections/create-connection?tabs=HTTP
################################

if [ -f "dah_devops/pipelines/scripts/modules/msfabric.sh" ]; then
  source dah_devops/pipelines/scripts/modules/msfabric.sh
else
  echo "Module file dah_devops/pipelines/scripts/modules/msfabric.sh not found!"
  exit 1
fi

print_help() {
  echo "Usage:"
  echo "  ./script.sh [options]"
  echo ""
  echo "Description:"
  echo "  This script automates the creation of connections in Microsoft Fabric for Dataverse."
  echo "  It supports creating, deleting, and managing role assignments for connections."
  echo ""
  echo "Options:"
  echo "  --env <environment_name>"
  echo "      Specifies the environment name (e.g., dev, prod). This is used to identify the workspace and other environment-specific configurations."
  echo ""
  echo "  --connection-name <name>"
  echo "      The name of the connection to be created. This will be displayed as the 'displayName' in the Microsoft Fabric API."
  echo ""
  echo "  --fabric-setup-admin-principal-key <key>"
  echo "      The secret key for the MS Fabric Admin Principal. Required for authentication."
  echo ""
  echo "  --fabric-setup-admin-principal-id <id>"
  echo "      The client ID of the MS Fabric Admin Principal. Required for authentication."
  echo ""
  echo "  --tenant-id <id>"
  echo "      The tenant ID for Azure Active Directory. Required for authentication."
  echo ""
  echo "  --dataverse-storage-container <container_name>"
  echo "      Required only for Dataverse connections. Specifies the name of the Azure Data Lake Storage container used for Dataverse."
  echo ""
  echo "  --action <action_type>"
  echo "      Specifies the action to perform. Valid options are:"
  echo "        - 'create_dataverse_conn': Creates a connection for Dataverse."
  echo ""
  echo "  --help"
  echo "      Displays this help message."
  echo ""
}

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
      echo "Unknown parameter: $1"
      print_help
      exit 1
      ;;
  esac
done

if [ -z "$connection_name" ] || [ -z "$fabric_setup_admin_principal_key" ] || [ -z "$fabric_setup_admin_principal_id" ] || [ -z "$tenant_id" ] || [ -z "$environment" ] || [ -z "$action" ]; then
  echo "Missing required arguments."
  exit 1
fi

echo "Connection Name: $connection_name"
echo "MS Fabric Setup Admin Principal ID: $fabric_setup_admin_principal_id"
echo "MS Fabric Setup Admin Principal KEY: $fabric_setup_admin_principal_key"
echo "Tenant ID: $tenant_id"
echo "Dateverse Storage account container name: $dataverse_storage_container"
echo "Action: $action"

token=$(az account get-access-token --resource "$msfabric_api_url" --query accessToken --output tsv)

list_existing_connections() {
  response=$(az rest --method get \
  --url "$msfabric_api_url/v1/connections" \
  --headers "Authorization=Bearer $token")

  echo "$response"
}

delete_connection() {
  local connection_id=$1
  az rest --method delete \
  --url "$msfabric_api_url/v1/connections/${connection_id}" \
  --headers "Authorization=Bearer $token" 
}

# TODO: Must be fixed, not working!
create_adf_connection() {
  local fabric_setup_admin_principal_key=$1
  local fabric_setup_admin_principal_id=$2
  local tenant_id=$3
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

  connection_id=$(echo "$response" | grep -oP '"id":\s*"\K[^"]+')
  echo "$connection_id"
}

create_dataverse_connection() {
  local fabric_setup_admin_principal_key=$1
  local fabric_setup_admin_principal_id=$2
  local tenant_id=$3
  local dataverse_container_name=$4
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

  connection_id=$(echo "$response" | grep -oP '"id":\s*"\K[^"]+')
  echo "$connection_id"
}

create_connection_role_assignment() {
    local connection_id=$1

    principal_assignments=(
      "d9cdc1c5-97e9-4f41-b854-bcf5d1d77332:group:User"  # GRPAAD_CS_DAH_DataEngineers
      "eb7aa397-616f-48c2-8187-65614b13a534:group:Owner" # GRPAAD_CS_DAH_InfrastructureEngineers
      "a7c91457-a48e-48fa-ba3a-9bf151203ce6:group:Owner" # GRPAAD_CS_DAH_Admins
      
      # HACK: for DEV purposes ONLY!
      "73544100-f313-45c4-a248-c7c55ee3ad82:user:Owner"  # Ekici, Muhammed Kasim - Owner
    )

    for assignment in "${principal_assignments[@]}"; do
       IFS=':' read -r principal_id principal_type role_name <<< "$assignment"
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
      echo "New role $role_name assigning to $principal_id $principal_type for new $connection_name connection." 
      az rest --method post \
              --url "$msfabric_api_url/v1/connections/${connection_id}/roleAssignments" \
              --headers "Authorization=Bearer $token" \
              --headers "Content-Type=application/json" \
              --body "$request_body" \
              --resource "$msfabric_api_url"
      echo "Connection role assignment - Done!" 
    done

}

connection_id=$(list_existing_connections | jq -r --arg name "$connection_name" '.value[] | select(.displayName == $name) | .id')

if [ -n "$connection_id" ]; then
  # delete obsolete connecion
  echo "Deleting $connection_name connection..."
  delete_connection "$connection_id"
  echo -e "Connection $connection_name deleted.\n"
  sleep 15
else
  echo "No connection found with name $connection_name."
fi

if [ "$action" == "create_dataverse_conn" ]; then
  if [ -z "$dataverse_storage_container" ]; then
    echo "Missing required arguments."
    exit 1
  fi

  # create datavarse connection
  echo "Creating new $connection_name connection..."
  dataverse_existing_container_name=$(az storage container list --account-name "$dataverse_storage_container" --prefix dataverse --auth-mode login --query "[].name" --output tsv)
  new_connection_id=$(create_dataverse_connection "$fabric_setup_admin_principal_key" "$fabric_setup_admin_principal_id" "$tenant_id" "$dataverse_existing_container_name")
  create_connection_role_assignment "$new_connection_id"
  echo -e "Connection $connection_name created.\n"
elif [ "$action" == "create_adf_conn" ]; then
  echo "Creating new $connection_name connection..."
  new_connection_id=$(create_adf_connection "$fabric_setup_admin_principal_key" "$fabric_setup_admin_principal_id" "$tenant_id")
  create_connection_role_assignment "$new_connection_id"
  echo -e "Connection $connection_name created.\n"
else
  echo -e "Incorrect value provided for the 'action' argument."
  exit 1
fi
