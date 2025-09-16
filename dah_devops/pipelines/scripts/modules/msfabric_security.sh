#!/bin/bash -e

# This module is designed to manage role assignments for new workspaces in Microsoft Fabric. 

if [ -f "pipelines/scripts/modules/msfabric.sh" ]; then
  source pipelines/scripts/modules/msfabric.sh
else
  echo "Module file pipelines/scripts/modules/msfabric.sh not found!"
  exit 1
fi

# Function to add role assignments for a new workspace
add_role_assignment_for_new_workspace() {
  local workspace_types=$1
  local workspace_display_name=$2
  local environment=$3

  # Define role assignments based on the environment
  case "$environment" in
    "SIT")
      principal_assignments=(
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:SIT:IDL:Owner:group"        # GRPAAD_CS_DAH_Admins_IDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:SIT:SDL:Owner:group"        # GRPAAD_CS_DAH_Admins_SDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:SIT:CDL:Owner:group"        # GRPAAD_CS_DAH_Admins_CDL
          "eb7aa397-616f-48c2-8187-65614b13a534:SIT:IDL:Owner:group"        # GRPAAD_CS_DAH_InfrastructureEngineers_IDL
          "eb7aa397-616f-48c2-8187-65614b13a534:SIT:SDL:Owner:group"        # GRPAAD_CS_DAH_InfrastructureEngineers_SDL
          "eb7aa397-616f-48c2-8187-65614b13a534:SIT:CDL:Owner:group"        # GRPAAD_CS_DAH_InfrastructureEngineers_CDL
          "d9cdc1c5-97e9-4f41-b854-bcf5d1d77332:SIT:IDL:User:group"        # GRPAAD_CS_DAH_DataEngineers_IDL
          "d9cdc1c5-97e9-4f41-b854-bcf5d1d77332:SIT:SDL:User:group"        # GRPAAD_CS_DAH_DataEngineers_SDL
          "d9cdc1c5-97e9-4f41-b854-bcf5d1d77332:SIT:CDL:User:group"        # GRPAAD_CS_DAH_DataEngineers_CDL

          # HACK: for DEV purposes ONLY!
          "73544100-f313-45c4-a248-c7c55ee3ad82:SIT:IDL:Admin:user"         # Ekici, Muhammed Kasim - IDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:SIT:CDL:Admin:user"         # Ekici, Muhammed Kasim - CDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:SIT:SDL:Admin:user"         # Ekici, Muhammed Kasim - SDL - Admin
      )
      ;;
    "UAT")
      principal_assignments=(
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:UAT:IDL:Owner:group"        # GRPAAD_CS_DAH_Admins_IDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:UAT:SDL:Owner:group"        # GRPAAD_CS_DAH_Admins_SDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:UAT:CDL:Owner:group"        # GRPAAD_CS_DAH_Admins_CDL
          "1fbccfb1-ac08-46a1-835b-347c06cacebb:UAT:IDL:User:group"        # GRPAAD_CS_DAH_ReleaseEngineers_IDL
          "1fbccfb1-ac08-46a1-835b-347c06cacebb:UAT:SDL:User:group"        # GRPAAD_CS_DAH_ReleaseEngineers_SDL
          "1fbccfb1-ac08-46a1-835b-347c06cacebb:UAT:CDL:User:group"        # GRPAAD_CS_DAH_ReleaseEngineers_CDL
          
          # HACK: for DEV purposes ONLY!
          "73544100-f313-45c4-a248-c7c55ee3ad82:UAT:IDL:Admin:user"         # Ekici, Muhammed Kasim - IDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:UAT:CDL:Admin:user"         # Ekici, Muhammed Kasim - CDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:UAT:SDL:Admin:user"         # Ekici, Muhammed Kasim - SDL - Admin
      )
      ;;
    "PRD")
      principal_assignments=(
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:PRD:IDL:Owner:group"       # GRPAAD_CS_DAH_Admins_IDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:PRD:SDL:Owner:group"       # GRPAAD_CS_DAH_Admins_SDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:PRD:CDL:Owner:group"       # GRPAAD_CS_DAH_Admins_CDL
  
            # HACK: for DEV purposes ONLY!
          "73544100-f313-45c4-a248-c7c55ee3ad82:PRD:IDL:Admin:user"         # Ekici, Muhammed Kasim - IDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:PRD:CDL:Admin:user"         # Ekici, Muhammed Kasim - CDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:PRD:SDL:Admin:user"         # Ekici, Muhammed Kasim - SDL - Admin
      )
      ;;
    *)
      echo "Invalid environment. Please specify SIT, UAT, or PRD."
      exit 1
      ;;
  esac


  for assignment in "${principal_assignments[@]}"; do
    IFS=':' read -r principal_id env_type workspace_type role_name principal_type <<< "$assignment"
    if [ "$env_type" == "$environment" ] && [ "$workspace_type" == "$workspace_types" ]; then
      workspace_id=$(get_workspace_id | jq -r --arg workspace_name "${workspace_display_name}" '.value[] | select(.displayName == $workspace_name) | .id')
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

      response=$(az rest --method POST \
        --url "$msfabric_api_url/v1/workspaces/$workspace_id/roleAssignments" \
        --headers "Authorization=Bearer $token" \
        --body "$request_body")

      if echo "$response" | grep -q '"id"'; then
        echo "Role assigned to principal ID $principal_id in workspace ID $workspace_id successfully."
      else
        echo "Failed to assign role to principal ID $principal_id in workspace ID $workspace_id."
        echo "Response: $response"
      fi
    fi
  done
}
