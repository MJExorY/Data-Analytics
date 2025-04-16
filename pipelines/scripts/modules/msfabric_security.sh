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
          "59128c64-b7f6-45d7-a9d4-790b497d9f86:SIT:IDL:Admin:group"        # GRPAAD_CS_FW_Admin_DAH-I
          "59128c64-b7f6-45d7-a9d4-790b497d9f86:SIT:SDL:Admin:group"        # GRPAAD_CS_FW_Admin_DAH-I
          "59128c64-b7f6-45d7-a9d4-790b497d9f86:SIT:CDL:Admin:group"        # GRPAAD_CS_FW_Admin_DAH-I
          "7a1bd5e9-2263-4ebb-90c2-f8bae1ed11e0:SIT:SDL:Contributor:group"  # GRPAAD_CS_FW_Contributor_DAH-SDL_I
          "0f08afd3-dafc-4336-a28f-557b3ec1b01a:SIT:SDL:Member:group"       # GRPAAD_CS_FW_Member_DAH-SDL_I
          "6650e51c-ce91-4704-a7bb-519bcb3e7eb0:SIT:IDL:Member:group"       # GRPAAD_CS_FW_Member_DAH-IDL_I
          "cec3fd10-e113-4223-b2fb-c04656bfb34b:SIT:IDL:Contributor:group"  # GRPAAD_CS_FW_Contributor_DAH-IDL_I
          "ae035b8a-96c3-48bb-ba8b-d9edba81442b:SIT:CDL:Contributor:group"  # GRPAAD_CS_FW_Contributor_DAH-CDL_I
          "0fad7e95-8b2f-465c-8811-406748b042f1:SIT:CDL:Member:group"       # GRPAAD_CS_FW_Member_DAH-CDL_I

          # HACK: for DEV purposes ONLY!
          "e84bc843-0d8a-4b61-bf2d-71fb9566ae2b:SIT:IDL:Admin:user"         # Martin Ciganik - IDL - Admin
          "e84bc843-0d8a-4b61-bf2d-71fb9566ae2b:SIT:CDL:Admin:user"         # Martin Ciganik - CDL - Admin
          "e84bc843-0d8a-4b61-bf2d-71fb9566ae2b:SIT:SDL:Admin:user"         # Martin Ciganik - SDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:SIT:IDL:Admin:user"         # Ekici, Muhammed Kasim - IDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:SIT:CDL:Admin:user"         # Ekici, Muhammed Kasim - CDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:SIT:SDL:Admin:user"         # Ekici, Muhammed Kasim - SDL - Admin
      )
      ;;
    "UAT")
      principal_assignments=(
          "3ea9e824-c87a-40bb-a933-3be464570234:UAT:IDL:Admin:group"        # GRPAAD_CS_FW_Admin_DAH-T 
          "3ea9e824-c87a-40bb-a933-3be464570234:UAT:SDL:Admin:group"        # GRPAAD_CS_FW_Admin_DAH-T 
          "3ea9e824-c87a-40bb-a933-3be464570234:UAT:CDL:Admin:group"        # GRPAAD_CS_FW_Admin_DAH-T 
          "bf864731-265b-4a2b-a329-47098c91f0b2:UAT:SDL:Viewer:group"       # GRPAAD_CS_FW_Viewer_DAH-SDL_T 
          "45b86625-ccb9-4938-99ec-6fb09ceb2154:UAT:SDL:Contributor:group"  # GRPAAD_CS_FW_Contributor_DAH-SDL_T
          "89957437-a7ba-48c2-933e-4529a497c1fa:UAT:IDL:Viewer:group"       # GRPAAD_CS_FW_Viewer_DAH-IDL_T
          "8d6843ff-5d03-40e5-a622-577bb2d1b0c1:UAT:IDL:Contributor:group"  # GRPAAD_CS_FW_Contributor_DAH-IDL_T
          "1c35072f-8055-4e36-84d7-63e8386afe69:UAT:CDL:Viewer:group"       # GRPAAD_CS_FW_Viewer_DAH-CDL_T 
          "cc52ab3c-af74-45ae-bf2d-c3c8427c159f:UAT:CDL:Contributor:group"  # GRPAAD_CS_FW_Contributor_DAH-CDL_T

          # HACK: for DEV purposes ONLY!
          "e84bc843-0d8a-4b61-bf2d-71fb9566ae2b:UAT:IDL:Admin:user"         # Martin Ciganik - IDL - Admin
          "e84bc843-0d8a-4b61-bf2d-71fb9566ae2b:UAT:CDL:Admin:user"         # Martin Ciganik - CDL - Admin
          "e84bc843-0d8a-4b61-bf2d-71fb9566ae2b:UAT:SDL:Admin:user"         # Martin Ciganik - SDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:UAT:IDL:Admin:user"         # Ekici, Muhammed Kasim - IDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:UAT:CDL:Admin:user"         # Ekici, Muhammed Kasim - CDL - Admin
          "73544100-f313-45c4-a248-c7c55ee3ad82:UAT:SDL:Admin:user"         # Ekici, Muhammed Kasim - SDL - Admin
      )
      ;;
    "PRD")
      principal_assignments=(
          "fd8290fa-14c2-4da5-8a81-0679b799a132:PRD:IDL:Admin:group"        # GRPAAD_CS_FW_Admin_DAH-P 
          "fd8290fa-14c2-4da5-8a81-0679b799a132:PRD:SDL:Admin:group"        # GRPAAD_CS_FW_Admin_DAH-P
          "fd8290fa-14c2-4da5-8a81-0679b799a132:PRD:CDL:Admin:group"        # GRPAAD_CS_FW_Admin_DAH-P
          "55393f45-336a-4ae7-957c-1beaf87db86e:PRD:SDL:Viewer:group"       # GRPAAD_CS_FW_Viewer_DAH-SDL_P
          "42571fc2-fdfc-42f2-ab71-8ab1d0dbc090:PRD:SDL:Contributor:group"  # GRPAAD_CS_FW_Contributor_DAH-SDL_P 
          "71855b02-5c4f-498a-8855-d61425400fc3:PRD:IDL:Viewer:group"       # GRPAAD_CS_FW_Viewer_DAH-IDL_P
          "efca6848-1183-4362-af9b-758689494203:PRD:IDL:Contributor:group"  # GRPAAD_CS_FW_Contributor_DAH-IDL_P
          "1231b085-bae3-4131-a58c-21af24907040:PRD:CDL:Viewer:group"       # GRPAAD_CS_FW_Viewer_DAH-CDL_P
          "8c08472b-1d06-41d0-be16-8f0891db3501:PRD:CDL:Contributor:group"  # GRPAAD_CS_FW_Contributor_DAH-CDL_P

          # HACK: for DEV purposes ONLY!
          "e84bc843-0d8a-4b61-bf2d-71fb9566ae2b:PRD:IDL:Admin:user"         # Martin Ciganik - IDL - Admin
          "e84bc843-0d8a-4b61-bf2d-71fb9566ae2b:PRD:CDL:Admin:user"         # Martin Ciganik - CDL - Admin
          "e84bc843-0d8a-4b61-bf2d-71fb9566ae2b:PRD:SDL:Admin:user"         # Martin Ciganik - SDL - Admin
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
