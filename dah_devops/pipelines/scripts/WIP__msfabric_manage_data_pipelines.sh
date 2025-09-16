#!/bin/bash -e

#################################################
########## WIP
# TODO: lack of Microsof support for this REST API at the moment: https://gfps-portal.atlassian.net/browse/AGTRAN-16490
#################################################

if [ -f "dah_devops/pipelines/scripts/modules/msfabric.sh" ]; then
  source dah_devops/pipelines/scripts/modules/msfabric.sh
else
  echo "Module file dah_devops/pipelines/scripts/modules/msfabric.sh not found!"
  exit 1
fi

print_help() {
  echo "Usage:"
  echo "  $0 --workspace <workspace> --env <environment> --data-payload <data-payload>"
  echo ""
  echo "Options:"
  echo "  -w, --workspace       Workspace name (e.g., GFCS SIT IDL)"
  echo "  -e, --env             Environment name (e.g., SIT)"
  echo "  -d, --data-payload    Payload for 'update'" 
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
    -d|--data-payload)
      data_payload_file="$2"
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

if [ -z "$workspace" ] || [ -z "$environment" ] ||  [ -z "$data_payload_file" ]; then
  echo "Missing required arguments."
  exit 1
fi

echo "Workspace: $workspace"
echo "Environment: $environment"
echo "Notebook Payload: $(<"$data_payload_file")"

update_data_pipeline_definition() {
  local sdl_workspace_id=$1
  local pipeline_id=$2
  local msfabric_adf_connection_id=$3
  local msfabric_db_connection_id=$4
  local sql_database_id_with_prefix="system_db-$5"
  local updated_pipeline_definition_json=$6

  echo "$updated_pipeline_definition_json" > updated_pipeline_definition.json
  jq --arg msfabric_adf_connection_id "$msfabric_adf_connection_id" \
     '(.properties.activities[] | select(.name == "fe_config_entry") | .typeProperties.activities[].typeProperties.cases[] | select(.value == "113_sap_table_full_br_epl") | .activities[].externalReferences.connection) |= $msfabric_adf_connection_id' \
     updated_pipeline_definition.json > temp.json && mv temp.json updated_pipeline-content.json

  jq --arg msfabric_adf_connection_id "$msfabric_adf_connection_id" \
     '(.properties.activities[] | select(.name == "fe_config_entry") | .typeProperties.activities[].typeProperties.cases[] | select(.value == "111_sap_abap_cds_full_br_epl") | .activities[].externalReferences.connection) |= $msfabric_adf_connection_id' \
     updated_pipeline-content.json > temp.json && mv temp.json updated_pipeline-content.json

  jq --arg msfabric_db_connection_id "$msfabric_db_connection_id" \
     '(.properties.activities[] 
        | select(.name != "fe_config_entry") 
        | .. | objects 
        | select(has("externalReferences")) 
        | .externalReferences.connection) |= $msfabric_db_connection_id' \
     updated_pipeline-content.json > temp.json && mv temp.json updated_pipeline-content.json
   
   jq --arg sql_database_id_with_prefix "$sql_database_id_with_prefix" '.properties.activities[].typeProperties.datasetSettings.typeProperties.database = $sql_database_id_with_prefix | .properties.activities[].typeProperties.database = $sql_database_id_with_prefix' updated_pipeline-content.json > temp.json && mv temp.json updated_pipeline-content.json

   payload=$(base64 -w 0 updated_pipeline-content.json)

   body=$(cat <<EOF
{ 
  "definition": { 
    "parts": [ 
      { 
        "path": "pipeline-content.json", 
        "payload": "$payload", 
        "payloadType": "InlineBase64" 
      } 
    ] 
  } 
}
EOF
  )

   az rest --method post \
    --url "$msfabric_api_url/v1/workspaces/${sdl_workspace_id}/items/${pipeline_id}/updateDefinition" \
    --headers "Authorization=Bearer $token" \
    --headers "Content-Type=application/json" \
    --resourcei $msfabric_api_url \
    --body "$body" 
}

token=$(az account get-access-token --resource $msfabric_api_url --query accessToken --output tsv)

workspace_id=$(get_workspace_id | jq -r --arg workspace_name "${workspace}" '.value[] | select(.displayName == $workspace_name) | .id')
sdl_workspace_id=$(get_workspace_id | jq -r --arg workspace_name "GFCS $environment SDL SAP-S4" '.value[] | select(.displayName == $workspace_name) | .id')
data_pipeline_id=$(get_data_pipeline_id "$sdl_workspace_id")
db_connection_id=$(get_connection_id "$environment" "system_db")
adf_connection_id=$(get_connection_id "$environment" "adf001")
sql_database_id=$(get_sql_database_id "$workspace_id")
update_data_pipeline_definition "$sdl_workspace_id" "$data_pipeline_id" "$adf_connection_id" "$db_connection_id" "$sql_database_id" "$(cat "$data_payload_file")"
