#!/bin/bash
if [ -f "dah_devops/pipelines/scripts/modules/msfabric.sh" ]; then
  source dah_devops/pipelines/scripts/modules/msfabric.sh
else
  echo "Module file dah_devops/pipelines/scripts/modules/msfabric.sh not found!"
  exit 1
fi

print_help() {
  echo "Usage:"
  echo ""
  echo "Options:"
  echo "  --workspace                  Workspace name (e.g., GFCS SIT IDL)"
  echo "  --env                        Environment name (e.g., SIT)"
  echo "  --nb-name                    Notebook name (e.g., Notebook 1)"
  echo "  --delete-nb-in-workspaces    Comma-separated list of workspaces to delete notebook from (required if action is 'delete')"
  echo "  --action                     Action: 'update' or 'run'"
  echo "  --help                       Show this help message"
}


while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      workspace="$2"
      shift 2
      ;;
    --env)
      environment="$2"
      shift 2
      ;;
    --nb-name)
      notebook_name="$2"
      shift 2
      ;;
    --delete-nb-in-workspaces)
      delete_nb_in_workspaces="$2"
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

if [ -z "$workspace" ] || [ -z "$environment" ] || [ -z "$notebook_name" ] || [ -z "$action" ]; then
  echo "Missing required arguments."
  exit 1
fi

if [ "$action" == "delete" ] && [ -z "$delete_nb_in_workspaces" ]; then
  echo "Argument --delete-nb-in-workspaces is required when action is 'delete'."
  exit 1
fi

echo "Workspace: $workspace"
echo "Environment: $environment"
echo "Notebook: $notebook_name"
echo "Delete Notebook from these workspaces: $delete_nb_in_workspaces"
echo "Action: $action"

delete_notebook() {
  local workspace_id=$1
  local notebook_id=$2

  delete_notebook_url="$msfabric_api_url/v1/workspaces/${workspace_id}/notebooks/${notebook_id}"

  az rest --method delete \
    --url "$delete_notebook_url" \
    --headers "Authorization=Bearer $token" \
    --resource "$msfabric_api_url" 
}

run_nb() {
  local workspace_id=$1
  local notebook_id=$2
  run_nb_url="$msfabric_api_url/v1/workspaces/$workspace_id/items/$notebook_id/jobs/instances?jobType=RunNotebook"

  response=$(az rest --method post \
    --url "$run_nb_url" \
    --headers "Authorization=Bearer $token" \
    --body "{}")

  if [ $? -ne 0 ]; then
    echo "Failed to run notebook. Please check the API and your token."
    exit 1
  fi

  echo "Notebook run -- success!"
}

# TODO: When update notebook definition will be fully supported by Microsoft then this function can by integrated.
# update_notebook_definition() {
#   local workspace_id=$1
#   local nb_payload_base64=$2
#   local nb_name=$3

#   notebook_id=$(get_nb_id "$workspace_id" "$nb_name")
#   update_notebook_url="$msfabric_api_url/v1/workspaces/${workspace_id}/notebooks/${notebook_id}/updateDefinition"

#   body=$(cat <<EOF
# {
#   "definition": {
#     "parts": [
#       {
#         "path": "notebook-content.py",
#         "payload": "${nb_payload_base64}",
#         "payloadType": "InlineBase64"
#       }
#     ]
#   }
# }
# EOF
#   )

#   response=$(az rest --method post \
#     --url "$update_notebook_url" \
#     --headers "Authorization=Bearer $token" \
#     --headers "Content-Type=application/json" \
#     --resource "$msfabric_api_url" \
#     --body "$body")

#   if [ $? -ne 0 ]; then
#     echo "Failed to update notebook."
#     exit 1
#   fi

#   echo "$response"
# }

create_notebook_definition() {
  local workspace_id=$1
  nb_payload_base64=$2
  create_notebook_url="$msfabric_api_url/v1/workspaces/${workspace_id}/items"

  body=$(cat <<EOF
{
    "displayName":"$notebook_name",
    "type":"Notebook",
    "definition" : {
        "format": "ipynb",
        "parts": [
            {
                "path": "notebook-content.ipynb",
                "payload": "${nb_payload_base64}",
                "payloadType": "InlineBase64"
            }
        ]
    }
}
EOF
  )

  response=$(az rest --method post \
    --url "$create_notebook_url" \
    --headers "Authorization=Bearer $token" \
    --headers "Content-Type=application/json" \
    --resource "$msfabric_api_url" \
    --body "$body")

  if [ $? -eq 0 ]; then
    echo -e "Notebook '${notebook_name}' created for workspace '${workspace}!'"
    echo -e "********************************************************************\n"
  fi

  echo "$response"
}

manage_parameters_in_notebook() {
  idl_workspace_id=$(get_workspace_id | jq -r --arg workspace_name "GFCS $environment IDL" '.value[] | select(.displayName == $workspace_name) | .id')
  idl_lakehouse_id=$(get_lakehouse_id_and_name "$idl_workspace_id" | jq -r '.value[] | select(.displayName == "system_lh") | .id')
  idl_gold_lh_id=$(get_lakehouse_id_and_name "$idl_workspace_id" | jq -r '.value[] | select(.displayName == "gold_lh") | .id')

  sdl_workspace_id=$(get_workspace_id | jq -r --arg workspace_name "GFCS $environment SDL SAP-S4" '.value[] | select(.displayName == $workspace_name) | .id')
  sdl_silver_lakehouse_id=$(get_lakehouse_id_and_name "$sdl_workspace_id" | jq -r '.value[] | select(.displayName == "silver_lh") | .id')
  sdl_bronze_lakehouse_id=$(get_lakehouse_id_and_name "$sdl_workspace_id" | jq -r '.value[] | select(.displayName == "bronze_lh") | .id')

  cdl_workspace_id=$(get_workspace_id | jq -r --arg workspace_name "GFCS $environment CDL OtC" '.value[] | select(.displayName == $workspace_name) | .id')
  cdl_sales_pricing_dm_lh=$(get_lakehouse_id_and_name "$cdl_workspace_id" | jq -r '.value[] | select(.displayName == "pl_sales_pricing_dm_lh") | .id')

  sdl_crm_workspace_id=$(get_workspace_id | jq -r --arg workspace_name "GFCS $environment SDL CRM" '.value[] | select(.displayName == $workspace_name) | .id')
  sdl_crm_silver_lakehouse_id=$(get_lakehouse_id_and_name "$sdl_crm_workspace_id" | jq -r '.value[] | select(.displayName == "silver_lh") | .id')
  sdl_crm_bronze_lakehouse_id=$(get_lakehouse_id_and_name "$sdl_crm_workspace_id" | jq -r '.value[] | select(.displayName == "bronze_lh") | .id')

  nb_payload=$(cat <<EOF
{
  "cells": [
    {
      "cell_type": "code",
      "source": [
        "IDL               = \"$idl_workspace_id\"\n",
        "SDL_S4_Sales      = \"$sdl_workspace_id\"\n",
        "SDL_CRM           = \"$sdl_crm_workspace_id\"\n",
        "CDL_sales_pricing = \"$cdl_workspace_id\"\n",
        " \n",
        "IDL_system_lh           = \"$idl_lakehouse_id\"\n",
        "IDL_gold_lh             = \"$idl_gold_lh_id\"\n",
        "SDL_S4_Sales_bronze_lh  = \"$sdl_bronze_lakehouse_id\"\n",
        "SDL_S4_Sales_silver_lh  = \"$sdl_silver_lakehouse_id\"\n",
        "SDL_CRM_bronze_lh       = \"$sdl_crm_bronze_lakehouse_id\"\n",
        "SDL_CRM_silver_lh       = \"$sdl_crm_silver_lakehouse_id\"\n",
        "CDL_sales_pricing_pl_lh = \"$cdl_sales_pricing_dm_lh\"\n",
        "\n",
        "ENVIRONMENT = \"$environment\""
      ],
      "outputs": [],
      "execution_count": null,
      "metadata": {
        "microsoft": {
          "language": "python",
          "language_group": "synapse_pyspark"
        }
      },
      "id": "45373f72-d322-45be-b67c-c68fe1c2900c"
    }
  ],
  "metadata": {
    "kernel_info": {
      "name": "synapse_pyspark"
    },
    "kernelspec": {
      "name": "synapse_pyspark",
      "display_name": "synapse_pyspark"
    },
    "language_info": {
      "name": "python"
    },
    "microsoft": {
      "language": "python",
      "language_group": "synapse_pyspark",
      "ms_spell_check": {
        "ms_spell_check_language": "en"
      }
    },
    "nteract": {
      "version": "nteract-front-end@1.0.0"
    },
    "spark_compute": {
      "compute_id": "/trident/default",
      "session_options": {
        "conf": {
          "spark.synapse.nbs.session.timeout": "1200000"
        }
      }
    },
    "dependencies": {}
  },
  "nbformat": 4,
  "nbformat_minor": 5
}
EOF
  )

  base64_encoded_nb_payload=$(echo "$nb_payload" | jq -c . | base64 -w 0)

  echo "$base64_encoded_nb_payload"
}

token=$(az account get-access-token --resource "$msfabric_api_url" --query accessToken --output tsv)

if [ -z "$token" ]; then
  echo "Failed to obtain access token. Please check your Azure credentials and permissions."
  exit 1
fi

workspace_id=$(get_workspace_id | jq -r --arg workspace_name "${workspace}" '.value[] | select(.displayName == $workspace_name) | .id')

if [ -z "$workspace_id" ]; then
  echo "Workspace ID not found for the specified type and environment."
  exit 1
fi

if [ "$action" == "create" ]; then
  notebook_id=$(get_nb_id "$workspace_id" "$notebook_name")

  max_retries=12
  initial_delay=10
  max_delay=40
  retry_count=0

  while [[ -z "$notebook_id" && $retry_count -lt $max_retries ]]; do
    if [[ -z "$notebook_id" ]]; then
      modified_notebook_content=$(manage_parameters_in_notebook)
      ((retry_count++))
      if [[ "$retry_count" -gt 1 ]]; then
        echo -e "The obsolete notebook '${notebook_name}' has been deleted in workspace '${workspace}' and is awaiting the reflection of this change within MS Fabric, which may take up to 5-10 minutes max. Only after this process is completed will a new notebook be created. Please refrain from interrupting the process, as it will automatically terminate upon the creation of the new notebook or after the explicitly defined timeout period has elapsed.\n"
        echo -e "Waiting for notebook creation... ($((max_retries - retry_count)) attempts remaining) \n"
      fi
      
      retry_interval=$((initial_delay * (2 ** retry_count)))
      if [ "$retry_interval" -gt "$max_delay" ]; then
        retry_interval=$max_delay
      fi
      
      sleep $retry_interval
      echo -e "Creating notebook '${notebook_name}' in workspace: '${workspace}...'"
      create_notebook_definition "$workspace_id" "$modified_notebook_content"; sleep 1
      notebook_id=$(get_nb_id "$workspace_id" "$notebook_name")
    else
      break
    fi
  done

elif [ "$action" == "run" ]; then
  notebook_id=$(get_nb_id "$workspace_id" "$notebook_name")
  if [ -z "$notebook_id" ]; then
    echo "Notebook ID not found for the specified name."
    exit 1
  fi
  echo -e "Running notebook '${notebook_name}' in workspace: '${workspace}...'"
  run_nb "$workspace_id" "$notebook_id"
elif [ "$action" == "delete" ]; then
  IFS=',' read -r -a workspace_array <<< "$delete_nb_in_workspaces"

  for workspace in "${workspace_array[@]}"; do
    workspace_id=$(get_workspace_id | jq -r --arg workspace "$workspace" '.value[] | select(.displayName == $workspace) | .id')
    notebook_id=$(get_nb_id "$workspace_id" "$notebook_name")
    
    if [ -n "$notebook_id" ]; then
      echo "Deleting notebook '$notebook_name' in workspace '$workspace'..."
      delete_notebook "$workspace_id" "$notebook_id"
    else
      echo "Notebook '$notebook_name' not found in workspace '$workspace'."
    fi
  done
else
  echo "Invalid action specified. Use 'create' or 'run'."
  exit 1
fi
