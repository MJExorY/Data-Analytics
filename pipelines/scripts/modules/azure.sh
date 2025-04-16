#!/bin/bash -e

get_storage_account_access_key() {
  local resource_group_name=$1
  local storage_acn_name=$2
  response=$(az storage account keys list \
    --resource-group "${resource_group_name}" \
    --account-name "${storage_acn_name}" \
    --query "[0].value" \
    --output tsv)

  if [ $? -eq 0 ]; then
    echo "$response"
  else
    echo "Error: Failed to retrieve storage account access key." >&2
    exit 1
  fi
}

azure_arm_template_deployment() {
  local deployment_name=$1
  local resource_group_name=$2
  local arm_template_json=$3
  local arm_template_parameters_json=$4
  local action=$5  # what-if || create || delete

  if [[ "$action" == "delete" ]]; then
    az deployment group delete \
      --name "$deployment_name" \
      --resource-group "$resource_group_name"
  else
    az deployment group "$action" \
      --name "$deployment_name" \
      --resource-group "$resource_group_name" \
      --template-file "$arm_template_json" \
      --parameters "$arm_template_parameters_json"
  fi
}
