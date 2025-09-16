#!/bin/bash -e

# Check if the msfabric module exists
if [ -f "pipelines/scripts/modules/msfabric.sh" ]; then
  source pipelines/scripts/modules/msfabric.sh
else
  echo "Module file pipelines/scripts/modules/msfabric.sh not found!"
  exit 1
fi

print_help() {
    echo "Usage: $0 --dacpac-file-path <dacpac_file_path> --workspace <workspace> --dbac-action <create|publish>"
    echo
    echo "Arguments:"
    echo "  --dacpac-file-path  Path to the DACPAC file"
    echo "  --workspace         Workspace type: GFCS SIT IDL"
    echo "  --dbac-action       Action: 'create' or 'publish'"
    echo "  -h, --help          Display this help message"
    echo
    echo "Example:"
    echo "  $0 --dacpac-file-path 'file.dacpac' --workspace 'GFCS SIT IDL' --dbac-action 'create'"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dacpac-file-path)
            dacpac_file_path="$2"
            shift 2
            ;;
        --workspace)
            workspace="$2"
            shift 2
            ;;
        --dbac-action)
            dbac_action="$2"
            shift 2
            ;;
        -h|--help)
            print_help
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_help
            ;;
    esac
done

if [ -z "$dacpac_file_path" ] || [ -z "$workspace" ] || [ -z "$dbac_action" ]; then
    echo "Missing required arguments!" >&2
    print_help
fi

echo "DACPAC file path: $dacpac_file_path"
echo "Workspace name: $workspace"
echo "DACPAC action: $dbac_action"

create_dacpac() {
    local database_name=$1
    local dacpac_file_path=$2
    local server_name=$3

    if [ -z "$token" ]; then
        echo "Failed to obtain access token. Please check your Azure credentials and permissions."
        exit 1
    fi

    sqlpackage_path="sqlpackage"

    echo "Creating DACPAC from database: $database_name"
    "$sqlpackage_path" /at:$token /Action:Extract /TargetFile:"$dacpac_file_path" \
        /SourceConnectionString:"Server=tcp:$server_name,1433;Initial Catalog=$database_name;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

    if [ $? -ne 0 ]; then
        echo "Failed to create DACPAC. Please check the details and try again."
        exit 1
    fi

    echo "DACPAC created successfully at $dacpac_file_path."
}

publish_dacpac() {
    local database_name=$1
    local dacpac_file_path=$2
    local server_name=$3

    if [ -z "$token" ]; then
      echo "Failed to obtain access token. Please check your Azure credentials and permissions."
      exit 1
    fi

    sqlpackage_path="sqlpackage"

    echo "Publishing DACPAC to database: $database_name"
    "$sqlpackage_path" /Action:Publish /SourceFile:"$dacpac_file_path" \
        /TargetServerName:"$server_name" \
        /TargetDatabaseName:"$database_name" \
        /AccessToken:"$token"

    if [ $? -ne 0 ]; then
        echo "Failed to deploy DACPAC. Please check the details and try again."
        exit 1
    fi

    echo "DACPAC deployed successfully."
}

token=$(az account get-access-token --resource $msfabric_api_url --query accessToken --output tsv)

if [ -z "$token" ]; then
    echo "Failed to acquire Azure access token. Ensure you are logged in to Azure."
    exit 1
fi

workspace_id=$(get_workspace_id | jq -r --arg workspace_name "${workspace}" '.value[] | select(.displayName == $workspace_name) | .id')

if [ -z "$workspace_id" ]; then
    echo "No workspace found: ($workspace)."
    exit 1
fi

dbInfo_response=$(get_database_parameters "$workspace_id")

serverFqdn=$(echo "$dbInfo_response" | jq -r '.serverFqdn')
databaseName=$(echo "$dbInfo_response" | jq -r '.databaseName')

if [ -z "$serverFqdn" ] || [ -z "$databaseName" ]; then
    echo "Error: Unable to retrieve valid database parameters (server FQDN or database name)."
    exit 1
fi

if [ "$dbac_action" == "create" ]; then
    echo "Creating DACPAC..."
    create_dacpac "$databaseName" "$dacpac_file_path" "$serverFqdn"
elif [ "$dbac_action" == "publish" ]; then
    echo "Publishing DACPAC..."
    publish_dacpac "$databaseName" "$dacpac_file_path" "$serverFqdn"
else
    echo "Invalid action specified. Please use 'create' or 'publish'."
    exit 1
fi
