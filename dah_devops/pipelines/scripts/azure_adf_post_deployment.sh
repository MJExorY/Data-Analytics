#!/bin/bash -e

if [ -f "dah_devops/pipelines/scripts/modules/msfabric.sh" ]; then
  source dah_devops/pipelines/scripts/modules/msfabric.sh
else
  echo "Module file dah_devops/pipelines/scripts/modules/msfabric.sh not found!"
  exit 1
fi

if [ -f "dah_devops/pipelines/scripts/modules/azure.sh" ]; then
  source dah_devops/pipelines/scripts/modules/azure.sh
else
  echo "Module file dah_devops/pipelines/scripts/modules/azure.sh not found!"
  exit 1
fi

print_help() {
  echo "Usage:"
  echo ""
  echo "Options:"
  echo "  --workspace              Workspace name (e.g., GFCS SIT IDL)"
  echo "  --env                    Environment name (e.g., SIT)"
  echo "  --adf-params-template    ADF parameters template file"
  echo "  --adf-template-file      ADF template file"
  echo "  --adf-name               ADF name"
  echo "  --keyvault-name          KeyVault name"
  echo "  --resource-group         Resource group name"
  echo "  --service-principle-id   Service Principal ID"
  echo "  --storage-account-name   Storage Account name"
  echo "  --help                   Show this help message"
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
    --adf-params-template)
      adf_params_template="$2"
      shift 2
      ;;
    --adf-template-file)
      adf_template_file="$2"
      shift 2
      ;;
    --adf-name)
      adf_name="$2"
      shift 2
      ;;
    --keyvault-name)
      keyvault_name="$2"
      shift 2
      ;;
    --resource-group)
      resource_group="$2"
      shift 2
      ;;
    --service-principal-id)
      service_principal_id="$2"
      shift 2
      ;;
    --adf-shir-resource-group)
      adf_shir_resource_group="$2"
      shift 2
      ;;
    --adf-shir-adf-name)
      adf_shir_adf_name="$2"
      shift 2
      ;;
    --subscription-id)
      subscription_id="$2"
      shift 2
      ;;
    --storage-account-name)
      if [ -z "$2" ] || [[ "$2" == -* ]]; then
        storage_account_name=""
        shift 1
      else
        storage_account_name="$2"
        shift 2
      fi
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

if [ -z "$workspace" ] || [ -z "$environment" ] || [ -z "$adf_template_file" ] || [ -z "$adf_name" ] || [ -z "$resource_group" ] || [ -z "$service_principal_id" ] || [ -z "$adf_params_template" ] || [ -z "$keyvault_name" ] || [ -z "$adf_shir_adf_name" ] || [ -z "$adf_shir_resource_group" ] || [ -z "$subscription_id" ]; then
  echo "Missing required arguments."
  exit 1
fi

echo "Workspace: $workspace"
echo "Environment: $environment"
echo "ADF ARM Template File: $adf_template_file"
echo "ADF ARM Template Parameter file: $adf_params_template"
echo "Azure Keyvault name: $keyvault_name"
echo "Azure ADF Name: $adf_name"
echo "Azure Resource Group name: $resource_group"
echo "Azure Service Principal ID: $service_principal_id"
echo "Azure Storage Account Name: $storage_account_name"
echo "Subsription ID: $subscription_id"
echo "ADF SHIR Resource Group: $adf_shir_resource_group"
echo "ADF SHIR Azure Data Factory: $adf_shir_adf_name"


update_adf_parameters() {

  local keyvault_name_as_substitution="https://$2.vault.azure.net/"
  local storage_account_key=$3

  cat "$adf_params_template" > ARMTemplateParametersForFactory.json
  cat "$adf_template_file" > ARMTemplateForFactory.json

  ### $adf_template_params arm parameters template modification 
  jq --arg adf_name "$adf_name" '.parameters.factoryName.value |= $adf_name' ARMTemplateParametersForFactory.json > temp.json && mv temp.json updated_ARMTemplateParametersForFactory.json
  jq --arg keyvault_name_as_substitution "$keyvault_name_as_substitution" '.parameters.KeyVault_DAH_LS_properties_typeProperties_baseUrl.value |= $keyvault_name_as_substitution' updated_ARMTemplateParametersForFactory.json > temp.json && mv temp.json updated_ARMTemplateParametersForFactory.json
  jq --arg storage_account_key "$storage_account_key" '.parameters.StorageAccount_Staging_LS_accountKey.value |= $storage_account_key' updated_ARMTemplateParametersForFactory.json > temp.json && mv temp.json updated_ARMTemplateParametersForFactory.json
  jq --arg adf_shir_resource_group "$adf_shir_resource_group" --arg adf_shir_adf_name "$adf_shir_adf_name"  --arg subscription_id "$subscription_id" '.parameters.lshir001_properties_typeProperties_linkedInfo_resourceId.value |= "/subscriptions/" + $subscription_id + "/resourceGroups/" + $adf_shir_resource_group + "/providers/Microsoft.DataFactory/factories/" + $adf_shir_adf_name + "/integrationruntimes/shir001"' updated_ARMTemplateParametersForFactory.json > temp.json && mv temp.json updated_ARMTemplateParametersForFactory.json
  jq --arg service_principal_id "$service_principal_id" '
    .parameters.Fabric_SAPSales_SDL_Bronze_LS_properties_typeProperties_servicePrincipalId.value |= $service_principal_id
    ' updated_ARMTemplateParametersForFactory.json > temp.json && mv temp.json updated_ARMTemplateParametersForFactory.json
  
  if [ -n "$storage_account_key" ]; then
    jq --arg storage_account_name "$storage_account_name" '.parameters.StorageAccount_Staging_LS_properties_typeProperties_url.value |= "https://" + $storage_account_name  + ".dfs.core.windows.net/"' updated_ARMTemplateParametersForFactory.json > temp.json && mv temp.json updated_ARMTemplateParametersForFactory.json
  fi

  ### $adf_arm_template modification
  jq --arg sdl_workspace_id "$sdl_workspace_id" \
   --arg sdl_bronze_lakehouse_id "$sdl_bronze_lakehouse_id" \
   --arg service_principal_id "$service_principal_id" '
  .resources |= map(
    if .name == "[concat(parameters('\''factoryName'\''), '\''/Fabric_SAPSales_SDL_Bronze_LS'\'')]" or
       .name == "[concat(parameters('\''factoryName'\''), '\''/Fabric_SAPSales_SDL_SRC_LS'\'')]" then
      .properties.typeProperties |= (
        .workspaceId = $sdl_workspace_id
        | .artifactId = $sdl_bronze_lakehouse_id
      )
    elif .name =="[concat(parameters('\''factoryName'\''), '\''/ADF_DAH_CR'\'')]" then
      .properties.typeProperties.servicePrincipalId = $service_principal_id
    else
      .
    end
  )' ARMTemplateForFactory.json > temp2.json && mv temp2.json updated_ARMTemplateForFactory.json
}

token=$(az account get-access-token --resource $msfabric_api_url --query accessToken --output tsv)

workspace_id=$(get_workspace_id | jq -r --arg workspace_name "${workspace}" '.value[] | select(.displayName == $workspace_name) | .id')
sql_database_id=$(get_sql_database_id "$workspace_id")

if [ -n "$storage_account_name" ]; then
  storage_account_key_string=$(get_storage_account_access_key "$resource_group" "$storage_account_name")
else
  storage_account_key_string=""
fi

sdl_workspace_id=$(get_workspace_id | jq -r --arg workspace_name "GFCS $environment SDL SAP-S4" '.value[] | select(.displayName == $workspace_name) | .id')
sdl_bronze_lakehouse_id=$(get_lakehouse_id_and_name "$sdl_workspace_id" | jq -r '.value[] | select(.displayName == "bronze_lh") | .id')

update_adf_parameters "$sql_database_id" "$keyvault_name" "${storage_account_key_string}"
echo "Running Azure ADF ARM Template deployment - dry run..."
azure_arm_template_deployment "${environment}_ADF_cicd_deployment" "$resource_group" "updated_ARMTemplateForFactory.json" "updated_ARMTemplateParametersForFactory.json" "what-if"
echo "Running Azure ADF ARM Template deployment..."
azure_arm_template_deployment "${environment}_ADF_cicd_deployment" "$resource_group" "updated_ARMTemplateForFactory.json" "updated_ARMTemplateParametersForFactory.json" "create" 