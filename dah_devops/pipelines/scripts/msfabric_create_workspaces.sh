#!/bin/bash -e

print_help() {
    echo "Usage: $0 --env <environment> --workspaces <workspace_list> --capacity-name <capacity_name>"
    echo
    echo "Arguments:"
    echo "  --env              Environment type (e.g., SIT)"
    echo "  --workspaces       Comma-separated list of workspaces (e.g., 'workspace1,workspace2')"
    echo "  --capacity-name    Capacity name to assign workspaces to"
    echo "  -h, --help         Display this help message"
    echo
    echo "Example:"
    echo "  $0 --env 'SIT' --workspaces 'workspace1,workspace2' --capacity-name 'gfcsneuwfc001'"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --env)
            environment="$2"
            shift 2
            ;;
        --workspaces)
            IFS=',' read -r -a workspaces_list <<< "$2"
            shift 2
            ;;
        --capacity-name)
            capacityName="$2"
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

if [ -z "$environment" ] || [ -z "$capacityName" ] || [ ${#workspaces_list[@]} -eq 0 ]; then
    echo "Missing required arguments!" >&2
    print_help
fi

echo "Environment name: $environment"
echo "Capacity name: $capacityName"
echo "Workspaces to process: ${workspaces_list[@]}"

if [ -f "pipelines/scripts/modules/msfabric.sh" ]; then
  source pipelines/scripts/modules/msfabric.sh
else
  echo "Module file dah_devops/pipelines/scripts/modules/msfabric.sh not found!"
  exit 1
fi

if [ -f "pipelines/scripts/modules/msfabric_security.sh" ]; then
  source pipelines/scripts/modules/msfabric_security.sh
else
  echo "Module file dah_devops/pipelines/scripts/modules/msfabric_security.sh not found!"
  exit 1
fi

# Function to get workspace ID by name
get_workspace_id_by_name() {
  local workspace_name="$1"
  local list_url="$msfabric_api_url/v1/workspaces"
  
  workspace_id=$(az rest --method get \
    --url "$list_url" \
    --headers "Authorization=Bearer $token" \
    | jq -r ".value[] | select(.displayName==\"$workspace_name\") | .id")
  
  echo "$workspace_id"
}

# Function to remove all existing role assignments for a workspace
remove_all_role_assignments() {
  local workspace_id="$1"
  local workspace_name="$2"
  
  echo "Removing all existing role assignments for workspace: $workspace_name"
  
  # Get all current role assignments
  local list_url="$msfabric_api_url/v1/workspaces/$workspace_id/roleAssignments"
  
  role_assignments=$(az rest --method get \
    --url "$list_url" \
    --headers "Authorization=Bearer $token" \
    | jq -r '.value[]? | @base64')
  
  if [ -z "$role_assignments" ]; then
    echo "No existing role assignments found for workspace: $workspace_name"
    return 0
  fi
  
  # Remove each role assignment
  for assignment in $role_assignments; do
    assignment_decoded=$(echo "$assignment" | base64 --decode)
    principal_id=$(echo "$assignment_decoded" | jq -r '.principal.id')
    principal_type=$(echo "$assignment_decoded" | jq -r '.principal.type')
    
    echo "Removing role assignment for principal: $principal_id (type: $principal_type)"
    
    delete_url="$msfabric_api_url/v1/workspaces/$workspace_id/roleAssignments/$principal_id"
    
    az rest --method delete \
      --url "$delete_url" \
      --headers "Authorization=Bearer $token"
    
    if [ $? -eq 0 ]; then
      echo "Successfully removed role assignment for principal: $principal_id"
    else
      echo "Warning: Failed to remove role assignment for principal: $principal_id"
    fi
  done
  
  echo "Completed removing all role assignments for workspace: $workspace_name"
}

# Function to reset and reassign permissions
reset_workspace_permissions() {
  local workspace_id="$1"
  local workspace_name="$2"
  local workspace_type="$3"
  
  echo "=== Resetting permissions for workspace: $workspace_name ==="
  
  # Step 1: Remove all existing role assignments
  remove_all_role_assignments "$workspace_id" "$workspace_name"
  
  # Step 2: Wait a moment to ensure removals are processed
  echo "Waiting for permission removals to process..."
  sleep 2
  
  # Step 3: Add new role assignments
  echo "Adding new role assignments for workspace: $workspace_name"
  add_role_assignment_for_new_workspace "$workspace_type" "$workspace_name" "$environment"
  
  echo "=== Permission reset completed for workspace: $workspace_name ==="
}

assign_workspace_to_capacity() {
  local workspace_id="$1"
  local capacity_id
  capacity_id=$(get_capacity_id "$capacityName")

  local assign_capacity_url="$msfabric_api_url/v1/workspaces/${workspace_id}/assignToCapacity"
  response=$(az rest --method post \
    --url "$assign_capacity_url" \
    --headers "Authorization=Bearer $token" \
    --body "{\"capacityId\": \"$capacity_id\"}")

  if [ $? -ne 0 ]; then
    echo "Failed to assign workspace $workspace_id to the capacity: $capacity_id"
    exit 1
  fi

  echo "Response: $response"
  echo "Assigned workspace $workspace_id to the capacity: $capacity_id"
}

configure_spark_for_workspace() {
  local workspace_id=$1
  local environment=$2
  local workspace_display_name=$3
  local workspace_type=$4
  local create_url="$msfabric_api_url/v1/workspaces/$workspace_id/spark/settings"

  if [[ "$environment" == DEV || "$environment" == SIT ]]; then
    session_timeout_in_minutes=20
  else
    session_timeout_in_minutes=5
  fi

  if [[ "$workspace_type" == SDL ]]; then
    notebook_interactive_run_enabled=true
    notebook_pipeline_run_enabled=true
  else 
    notebook_interactive_run_enabled=false
    notebook_pipeline_run_enabled=false
  fi

  body=$(cat <<EOF
{
  "highConcurrency": {
    "notebookInteractiveRunEnabled": $notebook_interactive_run_enabled,
    "notebookPipelineRunEnabled": $notebook_pipeline_run_enabled
  },
  "job": {
    "conservativeJobAdmissionEnabled": false,
    "sessionTimeoutInMinutes": $session_timeout_in_minutes
  }
}
EOF
)

  response=$(az rest --method patch \
    --url "$create_url" \
    --headers "Authorization=Bearer $token" \
    --body "$body")

  if [ $? -ne 0 ]; then
    echo "Failed to configure Spark for workspace: $workspace_display_name"
    exit 1
  fi

  echo "Response: $response"
  echo "Spark configuration for workspace: $workspace_display_name -- DONE."
}

check_all_existing_workspaces() {
  local workspace=$1
  local workspace_type=$2
  local list_url="$msfabric_api_url/v1/workspaces"
  
  # Check if workspace exists
  existing_workspace=$(az rest --method get --url "$list_url" --headers "Authorization=Bearer $token" | jq -r '.value[].displayName' | grep -x "$workspace" || echo "")

  if [ "$existing_workspace" == "$workspace" ]; then
    echo "Workspace already exists: $workspace"
    
    # Get workspace ID for existing workspace
    workspace_id=$(get_workspace_id_by_name "$workspace")
    
    if [ -n "$workspace_id" ]; then
      echo "Found workspace ID: $workspace_id"
      
      # Reset permissions for existing workspace
      reset_workspace_permissions "$workspace_id" "$workspace" "$workspace_type"
    else
      echo "Error: Could not find workspace ID for: $workspace"
      exit 1
    fi
  else
    echo "Creating new MS Fabric workspace: $workspace"
    create_new_workspace "$workspace" "$workspace_type"
  fi
}

create_new_workspace() {
  local workspace_display_name="$1"
  local workspace_type="$2"
  local create_url="$msfabric_api_url/v1/workspaces"

  response=$(az rest --method post \
    --url "$create_url" \
    --headers "Authorization=Bearer $token" \
    --body "{\"displayName\": \"$workspace_display_name\"}")

  if [ $? -ne 0 ]; then
    echo "Failed to create new workspace: $workspace_display_name"
    exit 1
  fi

  echo "Response: $response"
  echo "New workspace created: $workspace_display_name"

  workspace_id=$(echo "$response" | jq -r '.id')
  assign_workspace_to_capacity "$workspace_id"
  configure_spark_for_workspace "$workspace_id" "$environment" "$workspace_display_name" "$workspace_type"
  
  # For new workspaces, we don't need to remove permissions first
  echo "Adding role assignments for new workspace: $workspace_display_name"
  add_role_assignment_for_new_workspace "$workspace_type" "$workspace_display_name" "$environment"
}

# Main execution
echo "Starting MS Fabric workspace configuration..."
echo "========================================"

# Get access token
token=$(az account get-access-token --resource "$msfabric_api_url" --query accessToken --output tsv)

if [ -z "$token" ]; then
  echo "Error: Failed to get access token"
  exit 1
fi

# Process each workspace
for workspace in "${workspaces_list[@]}"; do
  echo ""
  echo "Processing workspace: $workspace"
  echo "-----------------------------------"
  
  # Determine workspace type
  if echo "$workspace" | grep -q 'CDL'; then
    workspace_type="CDL"
  elif echo "$workspace" | grep -q 'IDL'; then
    workspace_type="IDL"
  elif echo "$workspace" | grep -q 'SDL'; then
    workspace_type="SDL"
  else
    workspace_type="UNKNOWN"
    echo "Error: Unknown workspace type for: $workspace"
    exit 1
  fi
  
  echo "Detected workspace type: $workspace_type"
  
  # Process workspace (create new or update existing)
  check_all_existing_workspaces "$workspace" "$workspace_type"
  
  echo "Completed processing workspace: $workspace"
done

echo ""
echo "========================================"
echo "All workspaces processed successfully!"