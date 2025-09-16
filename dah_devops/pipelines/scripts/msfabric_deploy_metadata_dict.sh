#!/bin/bash -e

if [ -f "dah_devops/pipelines/scripts/modules/msfabric.sh" ]; then
  source dah_devops/pipelines/scripts/modules/msfabric.sh
elif [ -f "./pipelines/scripts/modules/msfabric.sh" ]; then
  source ./pipelines/scripts/modules/msfabric.sh
else
  echo "Module file msfabric.sh not found!"
  exit 1
fi

print_help() {
  echo "Usage:"
  echo "  $0 --workspace <workspace> --env <environment> --nb-name <notebook_name> --yaml-file <yaml_file> --action <action>"
  echo ""
  echo "Options:"
  echo "  -w, --workspace       Workspace name (e.g., GFCS SIT IDL)"
  echo "  -e, --env             Environment name (e.g., SIT)"
  echo "  -n, --nb-name         Notebook name (e.g., 007_read_configs)"
  echo "  -y, --yaml-file       Path to YAML file to deploy"
  echo "  -a, --action          Action: 'deploy'"
  echo "  -h, --help            Show this help message"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--workspace)
      workspace="$2"
      shift 2
      ;;
    -e|--env)
      environment="$2"
      shift 2
      ;;
    -n|--nb-name)
      notebook_name="$2"
      shift 2
      ;;
    -y|--yaml-file)
      yaml_file="$2"
      shift 2
      ;;
    -a|--action)
      action="$2"
      shift 2
      ;;
    -h|--help)
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

if [ -z "$workspace" ] || [ -z "$environment" ] || [ -z "$notebook_name" ] || [ -z "$yaml_file" ] || [ -z "$action" ]; then
  echo "Missing required arguments."
  exit 1
fi

echo "Workspace: $workspace"
echo "Environment: $environment"
echo "Notebook: $notebook_name"
echo "YAML File: $yaml_file"
echo "Action: $action"

update_notebook_with_yaml() {
  local workspace_id=$1
  local notebook_id=$2
  local yaml_content=$3
  
  yaml_content_escaped=$(echo "$yaml_content" | jq -Rs .)
  
  nb_payload=$(cat <<EOF
{
  "cells": [
    {
      "cell_type": "code",
      "source": [
        "# Parameters\\n",
        "yml = $yaml_content_escaped"
      ],
      "outputs": [],
      "execution_count": null,
      "metadata": {
        "microsoft": {
          "language": "python",
          "language_group": "synapse_pyspark"
        },
        "tags": ["parameters"]
      },
      "id": "param-cell-001"
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
      "language_group": "synapse_pyspark"
    },
    "nteract": {
      "version": "nteract-front-end@1.0.0"
    },
    "spark_compute": {
      "compute_id": "/trident/default"
    }
  },
  "nbformat": 4,
  "nbformat_minor": 5
}
EOF
  )
  

  base64_encoded_nb_payload=$(echo "$nb_payload" | jq -c . | base64 -w 0)
  
  update_notebook_url="$msfabric_api_url/v1/workspaces/${workspace_id}/notebooks/${notebook_id}/updateDefinition"
  
  body=$(cat <<EOF
{
  "definition": {
    "parts": [
      {
        "path": "notebook-content.py",
        "payload": "${base64_encoded_nb_payload}",
        "payloadType": "InlineBase64"
      }
    ]
  }
}
EOF
  )
  
  response=$(az rest --method post \
    --url "$update_notebook_url" \
    --headers "Authorization=Bearer $token" \
    --headers "Content-Type=application/json" \
    --resource "$msfabric_api_url" \
    --body "$body")
  
  if [ $? -ne 0 ]; then
    echo "Failed to update notebook."
    exit 1
  fi
  
  echo "Notebook updated successfully with YAML content"
}


run_notebook() {
  local workspace_id=$1
  local notebook_id=$2
  
  run_nb_url="$msfabric_api_url/v1/workspaces/$workspace_id/items/$notebook_id/jobs/instances?jobType=RunNotebook"
  
  response=$(az rest --method post \
    --url "$run_nb_url" \
    --headers "Authorization=Bearer $token" \
    --body "{}")
  
  if [ $? -ne 0 ]; then
    echo "Failed to run notebook."
    exit 1
  fi
  
  echo "Notebook execution started successfully"
}

token=$(az account get-access-token --resource "$msfabric_api_url" --query accessToken --output tsv)

if [ -z "$token" ]; then
  echo "Failed to obtain access token. Please check your Azure credentials and permissions."
  exit 1
fi


workspace_id=$(get_workspace_id | jq -r --arg workspace_name "${workspace}" '.value[] | select(.displayName == $workspace_name) | .id')

if [ -z "$workspace_id" ]; then
  echo "Workspace ID not found for workspace: $workspace"
  exit 1
fi


notebook_id=$(get_nb_id "$workspace_id" "$notebook_name")

if [ -z "$notebook_id" ]; then
  echo "Notebook '$notebook_name' not found in workspace '$workspace'"
  exit 1
fi

if [ "$action" == "deploy" ]; then
  # Read YAML content
  if [ ! -f "$yaml_file" ]; then
    echo "YAML file not found: $yaml_file"
    exit 1
  fi
  
  yaml_content=$(cat "$yaml_file")
  
  echo "Updating notebook with YAML content..."
  update_notebook_with_yaml "$workspace_id" "$notebook_id" "$yaml_content"
  
  echo "Running notebook..."
  run_notebook "$workspace_id" "$notebook_id"
  
  echo "Metadata dictionary deployment completed successfully"
else
  echo "Invalid action specified. Use 'deploy'."
  exit 1
fi