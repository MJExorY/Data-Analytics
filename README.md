# Azure DevOps Pipeline for Infrastructure as Code (IaC) Deployment

This repository [**dah_devops**](https://dev.azure.com/gfcs/DAH/_git/dah_devops?path=%2F&version=GBmain&_a=contents) contains Azure DevOps pipeline configurations and Bicep templates for deploying infrastructure as code (IaC) to Azure. Also, It contains Bash and Python scripts and yaml files to manage MS Fabric Workspcaces and other components.

## Table of Contents
1. [Overview](#overview)
2. [IaC deployment](#iac-deployment) 
3. [MS Fabric Manage Workspaces](#ms-fabric-manage-workspaces)
4. [Managing Microsoft Fabric Capacity](#managing-microsoft-fabric-capacity)
5. [Managing Microsoft Fabric Deployment Pipelines](#managing-microsoft-fabric-deployment-pipelines)
6. [DACPAC Management](#dacpac-management)
7. [Ms Fabric Post Deployment](#ms-fabric-post-deployment)
8. [Azure ADF Post Deployment](#azure-adf-post-deployment)
9. [Power BI import new resources to Fabric pipeline](#power-bi-import-new-resources-to-fabric-pipeline)
10. [Additional Information](#additional-information)
11. [Used Links](#used-links)

## Overview
This project uses Azure DevOps pipelines to automate the deployment of infrastructure using Bicep templates. The deployment is conditional, ensuring certain resources are only deployed in specific environments.
[DevOps Pipeline Architecture](https://dev.azure.com/gfcs/DAH/_git/dah_documentation?path=/02%20Systems%20Architecture/025%20DevOps/devops-pipeline-architecture.drawio)

## IaC deployment

### IaC Pipeline Configuration
The main pipeline configurations are defined in the pipelines directory, with separate folders for different environments.

#### IaC Environment-Specific Pipelines
* pipelines/SIT/SIT_env_deploy_IaC.yaml
* pipelines/UAT/UAT_env_deploy_IaC.yaml
* pipelines/PRD/PRD_env_deploy_IaC.yaml

#### IaC Triggering pipelines
* Most pipelines in the **DEV environments** should be **automatically triggered** when code from “feature/*” branch is merged into the “main” branch.
* As for **PROD environments**, all pipelines will be **triggered manually** only from the **“release” branch**. These pipelines, before being executed, will need to go through an **approval process** configured in Azure DevOps. For example, a designated individual will need to approve the pipeline in Azure DevOps before it runs.

#### List of existing IaC pipelines in Azure Devops(dah_devops)
* [SIT/IaC/GFCS_DAH_create_IaC_SIT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=1)
* [UAT/IaC/GFCS_DAH_create_IaC_UAT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=2)
* [PRD/IaC/GFCS_DAH_create_IaC_PRD_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=3)

#### Variable groups
A variable group in Azure DevOps is a collection of variables that can be shared and reused across multiple pipelines, stages, and jobs. It allows you to centralize the management of variables, making it easier to maintain and update them. Variables can include any kind of information, such as configuration settings, secrets, keys, or environment-specific values.

#### Used Variable groups
By linking a variable group to **Azure Key Vault**, we ensure that sensitive data is managed securely within our CI/CD pipeline. This approach provides an additional layer of security and simplifies the management of secrets across different environments.

* [GFCS_DAH_SIT_variable_group](https://dev.azure.com/gfcs/DAH/_library?itemType=VariableGroups&view=VariableGroupView&variableGroupId=1&path=GFCS_DAH_SIT_variable_group)
* [GFCS_DAH_UAT_variable_group](https://dev.azure.com/gfcs/DAH/_library?itemType=VariableGroups&view=VariableGroupView&variableGroupId=2&path=GFCS_DAH_UAT_variable_group)
* [GFCS_DAH_PRD_variable_group](https://dev.azure.com/gfcs/DAH/_library?itemType=VariableGroups&view=VariableGroupView&variableGroupId=3&path=GFCS_DAH_PRD_variable_group)

### Bicep Parameter Files
Parameter files are used to pass environment-specific values to the Bicep templates. Example files are provided for SIT, UAT, and PRD environments.

* parameters/SIT_parameters.bicepparam
* parameters/UAT_parameters.bicepparam
* parameters/PRD_parameters.bicepparam

#### How to Deploy
```bash
az deployment group create \
            --resource-group $(resourceGroupName) \
            --template-file $(bicepTemplateFile) \
            --parameters $(bicepParamFile) \
            --name DeployPipelineTemplate_$(environment)
```

##### Conditions for Deployment
The deployment of certain resources is **conditional based on the environment**.
```bicep
module msFabric 'modules/msfabric.bicep' = if (contains(envToDeploy, environment)) {
  name: 'deployMsFabric'
  params: {
    location: location
    administrationMembers: administrationMembers 
    capacitiesName: capacitiesName
    msFabricSkuName: msFabricSkuName
  }
}
```

## MS Fabric Manage Workspaces
This repository contains a Bash script to check for the existence of MS Fabric workspaces and create new ones if they do not exist. The script takes a list of workspace names as input and uses the Azure CLI to interact with the MS Fabric API.

### Requirements
* Azure CLI 
* jq (JSON processor) 
* Bash shell

### List of existing Manage workspaces pipelines in Azure Devops(dah_devops)
* [SIT/MANAGE_MSFABRIC_WORKSPACES/GFCS_DAH_msfabric_manage_workspaces_SIT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=20)
* [UAT/MANAGE_MSFABRIC_WORKSPACES/GFCS_DAH_msfabric_manage_workspaces_UAT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=21)
* [PRD/MANAGE_MSFABRIC_WORKSPACES/GFCS_DAH_msfabric_manage_workspaces_PRD_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=22)

### Running the Script 
The script expects a **--env \<environment name\>**, **--workspaces \<workspace name\>**, **--capacity-name \<capacityName\>** and **--help** as arguments. 
```bash 
./dah_devops/pipelines/scripts/msfabric_create_workspaces.sh  --env 'SIT' --workspaces 'workspace1,workspace2,workspace3' --capacity-name 'gfcsneuwfc001'
```
#### Note
Currently, the script assigns the role to the group OR user for each newly created workspace based on environment and workspace type.
```bash
    * SIT
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:SIT:IDL:Owner:group"        # GRPAAD_CS_DAH_Admins_IDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:SIT:SDL:Owner:group"        # GRPAAD_CS_DAH_Admins_SDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:SIT:CDL:Owner:group"        # GRPAAD_CS_DAH_Admins_CDL
          "eb7aa397-616f-48c2-8187-65614b13a534:SIT:IDL:Owner:group"        # GRPAAD_CS_DAH_InfrastructureEngineers_IDL
          "eb7aa397-616f-48c2-8187-65614b13a534:SIT:SDL:Owner:group"        # GRPAAD_CS_DAH_InfrastructureEngineers_SDL
          "eb7aa397-616f-48c2-8187-65614b13a534:SIT:CDL:Owner:group"        # GRPAAD_CS_DAH_InfrastructureEngineers_CDL
          "d9cdc1c5-97e9-4f41-b854-bcf5d1d77332:SIT:IDL:User:group"        # GRPAAD_CS_DAH_DataEngineers_IDL
          "d9cdc1c5-97e9-4f41-b854-bcf5d1d77332:SIT:SDL:User:group"        # GRPAAD_CS_DAH_DataEngineers_SDL
          "d9cdc1c5-97e9-4f41-b854-bcf5d1d77332:SIT:CDL:User:group"        # GRPAAD_CS_DAH_DataEngineers_CDL

    * UAT
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:UAT:IDL:Owner:group"        # GRPAAD_CS_DAH_Admins_IDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:UAT:SDL:Owner:group"        # GRPAAD_CS_DAH_Admins_SDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:UAT:CDL:Owner:group"        # GRPAAD_CS_DAH_Admins_CDL
          "1fbccfb1-ac08-46a1-835b-347c06cacebb:UAT:IDL:User:group"        # GRPAAD_CS_DAH_ReleaseEngineers_IDL
          "1fbccfb1-ac08-46a1-835b-347c06cacebb:UAT:SDL:User:group"        # GRPAAD_CS_DAH_ReleaseEngineers_SDL
          "1fbccfb1-ac08-46a1-835b-347c06cacebb:UAT:CDL:User:group"        # GRPAAD_CS_DAH_ReleaseEngineers_CDL

    * PRD
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:PRD:IDL:Owner:group"       # GRPAAD_CS_DAH_Admins_IDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:PRD:SDL:Owner:group"       # GRPAAD_CS_DAH_Admins_SDL
          "a7c91457-a48e-48fa-ba3a-9bf151203ce6:PRD:CDL:Owner:group"       # GRPAAD_CS_DAH_Admins_CDL

```

## Managing Microsoft Fabric Capacity

This repository contains an Azure DevOps pipeline that **pauses and resumes Microsoft Fabric capacity at specified times** during weekdays. The capacity is paused at 17:00 PM CET and resumed at 8:00 AM CET from Monday to Friday. Over the weekends, the capacity remains paused.

### List of existing Manage MS Fabric Capacity pipelines in Azure Devops(DEV, PRD envs)
* [DEV/MANAGE_MSFABRIC_CAPACITY/GFCS_DAH_manage_msfabric_capacity(Resume,Pause)_DEV_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=7)
* [PRD/MANAGE_MSFABRIC_CAPACITY/GFCS_DAH_manage_msfabric_capacity(Resume,Pause)_PRD_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=6)

### Prerequisites
- Azure subscription with Microsoft Fabric capacity.
- Service principal with necessary permissions to manage Azure resources.

## Managing Microsoft Fabric Deployment Pipelines

> **WIP!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!**

This script automates the deployment of resources from one environment stage to another in Microsoft Fabric. It uses the Azure CLI and REST API to perform various tasks such as fetching workspace IDs, deployment pipeline IDs, and deploying resources.

### Prerequisites

- **Azure CLI**: Ensure you have the Azure CLI installed and configured.
- **jq**: A command-line JSON processor.

### List of existing pipelines for Microsoft Fabric Deployment Pipeline in Azure Devops
* [GFCS_DAH_run_msfabric_deployment_pipeline_SIT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=8)

### Script Parameters

The script takes three parameters:
1. **source_environment_stage**: The source environment stage (`DEV`, `SIT`, `UAT`, or `PRD`).
2. **target_environment_stage**: The target environment stage (`DEV`, `SIT`, `UAT`, or `PRD`).
3. **workspace**: Workspace name (`GFCS SIT IDL`).

#### Usage

Run the script as follows:

```bash
./dah_devops/pipelines/script/msfabric_deployment_pipeline.sh <source_env_stage> <target_env_stage> <workspace_type>
```

## DACPAC Management
This project contains a bash script for managing DACPAC files, including creating and publishing them to a SQL server via the Microsoft Fabric API.
MS Fabric dacpac is a file that contains the definitions of objects in a SQL database. It serves to export and import databases, which means you can easily migrate data between different platforms like SQL Server or Azure SQL Managed Instance. It also allows for practical database deployment using the SqlPackage tool, which is a CLI tool for working with databases in Microsoft Fabric.

### List of existing pipelines for DACPAC Management in Azure Devops
* **SIT**
  * [SIT/MANAGE_MSFABRIC_DACPAC/GFCS_DAH_msfabric_create_dacpac_SIT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=10)
  * [SIT/MANAGE_MSFABRIC_DACPAC/GFCS_DAH_msfabric_publish_dacpac_SIT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=11)
* **UAT**
  * [UAT/MANAGE_MSFABRIC_DACPAC/GFCS_DAH_msfabric_create_dacpac_UAT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=17)
  * [UAT/MANAGE_MSFABRIC_DACPAC/GFCS_DAH_msfabric_publish_dacpac_UAT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=18)
* **PRD**
  * [PRD/MANAGE_MSFABRIC_DACPAC/GFCS_DAH_msfabric_create_dacpac_PRD_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=14)
  * [PRD/MANAGE_MSFABRIC_DACPAC/GFCS_DAH_msfabric_publish_dacpac_PRD_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=15)

### Requirements

Before running the script, ensure that `sqlpackage` is installed. You can install it using the following steps:

```bash
echo "Installing sqlpackage..."
wget https://aka.ms/sqlpackage-linux -O sqlpackage.zip
unzip sqlpackage.zip -d sqlpackage
chmod +x ./sqlpackage/sqlpackage
sudo mkdir -p /opt/sqlpackage
sudo cp ./sqlpackage/sqlpackage /opt/sqlpackage/
sudo ln -s /opt/sqlpackage/sqlpackage /usr/local/bin/sqlpackage
echo "sqlpackage installed successfully."
```

### Usage

#### Running the Script
The script takes four parameters:

1. **--dacpac-file-path \<dacpac_file_path\>**: Path to the DACPAC file.
2. **--workspace \<workspace\>**: Workspace name (`GFCS SIT IDL`).
3. **--dbac-action \<dbac_action\>**: Action the script should perform (`create` or `publish`).
4. **--help**: Get DACPAC script help

```bash
./dah_devops/pipelines/script/msfabric_manage_dacpac.sh --dacpac-file-path <dacpac_file_path> --workspace <workspace> --dbac-action <dbac_action>
```

## MS Fabric Post Deployment

This Azure Pipeline is designed to handle the deletion and upload of CSV files to Lakehouse for IDL workspace types, and then execute a notebook for the MS Fabric workspaces configurations.

> This Python script [msfabric_manage_csv_files_for_lakehouse.py](https://dev.azure.com/gfcs/DAH/_git/dah_devops?path=/pipelines/scripts/msfabric_manage_csv_files_for_lakehouse.py) helps manage CSV files on OneLake by allowing users to delete existing CSV files and upload new ones to a specified directory.

> Also, there is bash script [msfabric_manage_notebooks.sh](https://dev.azure.com/gfcs/DAH/_git/dah_devops?path=/pipelines/scripts/msfabric_manage_notebooks.sh) which is designed to run or create a specified notebook in Microsoft Fabric, given the workspace, environment, action and notebook name.

> Also, in pipeline stage `AzureADFpostDeployment` we execute this script [Azure ADF Post Deployment Script](#azure-adf-post-deployment-script) to implement a few ADF post-deployment setups.

### Overview

The python script `msfabric_manage_csv_files_for_lakehouse.py` can perform two main actions based on the provided arguments:
> 1. **Delete**: Deletes the specified CSV files in a given directory.
> 2. **Upload**: Uploads new CSV files to a specific directory.

The script is designed to work with the Azure DataLake service and Microsoft Fabric.

### Prerequisites for Python and Bash script
* **Python 3.x**
  - `azure-storage-file-datalake` Python package
  - `azure-identity` Python package
  - `argparse` Python package
* **Azure CLI:** Ensure you have the Azure CLI installed and configured.
* **jq:** A command-line JSON processor.

Install the required python packages with the following command:

```bash
pip install azure-storage-file-datalake azure-identity argparse pyspark p2j
```

### Usage 

The script takes four parameters:
1. **action:** The action to perform - either `delete` or `upload`.
<!--  2. **csv_files:** Paths to the local CSV files to upload or delete (can be multiple files as array(Bash)). This argument is not mandatory when action=delete.-->
2. **workspace_name:** The name of the workspace in MS Fabric, e.g., GFCS IDL SIT.
3. **directory_path:** The path to the directory in OneLake where the files will be uploaded or deleted, e.g., system_lh.Lakehouse/Files/_config/Data_Mapping_Silver/S4SALES.

#### Example:
<!--
##### Delete CSV files
```bash
python3 ./pipelines/script/msfabric_manage_csv_files_for_lakehouse.py "delete" "GFCS IDL SIT" "system_lh.Lakehouse/Files/_config/Data_Mapping_Silver/S4SALES"
```

##### Upload CSV files
```bash
python3 ./pipelines/script/msfabric_manage_csv_files_for_lakehouse.py "upload" "/path/to/file.csv" "GFCS IDL SIT" "system_lh.Lakehouse/Files/_config/Data_Mapping_Silver/S4SALES"
```

##### Run notebook

The script takes these parameters:
1. **--workspace \<workspace\>**: Workspace name (e.g., `GFCS SIT IDL`).
2. **--env \<environment\>**: The environment of the workspace (e.g., `DEV`, `SIT`, `UAT`, `PRD`).
3. **--nb-name \<notebook_name\>**: The name of the notebook to run (e.g., `Notebook 1`, `Notebook 2`).
4. **--action \<action\>**: Action to perform (e.g., `run` or `create`).
5. **--help**: Get Manage Notebooks script help

```bash
./dah_devops/pipelines/script/msfabric_manage_notebooks.sh --workspace <workspace> --env <environment> --nb-name <notebook_name> --action run 
```

##### Create notebook


The script takes these parameters:
1. **--workspace \<workspace\>**: Workspace name (e.g., `GFCS SIT IDL`).
2. **--env \<environment\>**: The environment of the workspace (e.g., `DEV`, `SIT`, `UAT`, `PRD`).
3. **--nb-name \<notebook_name\>**: The name of the notebook to run (e.g., `Notebook 1`, `Notebook 2`).
4. **--action \<action\>**: Action to perform (e.g., `run` or `create`).
6. **--help**: Get Manage Notebooks script help

```bash
./dah_devops/pipelines/script/msfabric_manage_notebooks.sh --workspace <workspace> --env <environment> --nb-name <notebook_name> --action create
```

##### delete notebook

The script takes these parameters:
1. **--workspace \<workspace\>**: Workspace name (e.g., `GFCS SIT IDL`).
2. **--env \<environment\>**: The environment of the workspace (e.g., `DEV`, `SIT`, `UAT`, `PRD`).
3. **--nb-name \<notebook_name\>**: The name of the notebook to run (e.g., `Notebook 1`, `Notebook 2`).
4. **--action \<action\>**: Action to perform (e.g., `run` or `create`).
5. **--delete-nb-in-workspaces \<delete_nb_in_workspaces\>** Comma-separated list of workspaces to delete notebook from (required if action is 'delete'; e.g., `GFCS UAT CDL OtC,GFCS UAT IDL,GFCS UAT SDL SAP-S4`)"
6. **--help**: Get Manage Notebooks script help

```bash
./dah_devops/pipelines/script/msfabric_manage_notebooks.sh --workspace <workspace> --env <environment> --nb-name <notebook_name> --action delete  --delete-nb-in-workspaces <delete_nb_in_workspaces>
```
-->
### Create MS Fabric connections

This script [msfabric_create_connection.sh](https://dev.azure.com/gfcs/DAH/_git/dah_devops?version=GBfeature/msfabric_postdeployment_config&path=/pipelines/scripts/msfabric_create_connection.sh) automates the creation of connections in Microsoft Fabric for Dataverse. It supports creating, deleting, and managing role assignments for connections.

#### Example:

##### Create dataverse connection

The script takes these parameters:

1. **--connection-name \<connection_name\>**:The name of the connection to be created. This will be displayed as the 'displayName' in the Microsoft Fabric API."The name of the connection to be created. This will be displayed as the 'displayName' in the Microsoft Fabric API."
2. **--env \<environment\>**: The environment of the workspace (e.g., `DEV`, `SIT`, `UAT`, `PRD`).
3. **--dataverse-storage-container) \<dataverse_storage_container\>**: Required only for Dataverse connections. Specifies the name of the Azure Data Lake Storage container used for Dataverse."
4. **--fabric-setup-admin-principal-key \<fabric_setup_admin_principal_key\>** The secret key for the MS Fabric Admin Principal. Required for authentication.
5. **--fabric-setup-admin-principal-id \<fabric_setup_admin_principal_id\>**:The client ID of the MS Fabric Admin Principal. Required for authentication.
6. **--tenant-id \<tenant_id\>**:  The tenant ID for Azure Active Directory. Required for authentication
7. **--action \<action\>**: Action to perform (e.g., `create_systemdb_conn` or `create_dataverse_conn`).
8. **--help**: Get script help

```bash
./dah_devops/pipelines/scripts/msfabric_create_connection.sh --env <environment> --connection-name <connection_name> --dataverse-storage-container <dataverse_storage_container> --fabric-setup-admin-principal-key <fabric_setup_admin_principal_key> --fabric-setup-admin-principal-id <fabric_setup_admin_principal_id> --tenant-id <tenant_id> --action <create_dataverse_conn>
```

#### Note
Currently, the script assigns the role to the group OR user for each newly created connection based on environment and workspace type.

```bash
"d9cdc1c5-97e9-4f41-b854-bcf5d1d77332:group:User"  # GRPAAD_CS_DAH_DataEngineers
"eb7aa397-616f-48c2-8187-65614b13a534:group:Owner" # GRPAAD_CS_DAH_InfrastructureEngineers
"a7c91457-a48e-48fa-ba3a-9bf151203ce6:group:Owner" # GRPAAD_CS_DAH_Admins

```

### List of existing MS Fabric Post deployment pipelines in Azure Devops
This pipeline relies on an external Azure DevOps repository called [dah_fabric_ws](https://dev.azure.com/gfcs/DAH/_git/dah_fabric_ws). The repository is necessary for accessing the required files and scripts for uploading and deleting CSV files in OneLake.

* [SIT/MSFABRIC_POST_DEPLOYMENT/GFCS_DAH_msfabric_post_deployment_SIT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=9)
* [UAT/MSFABRIC_POST_DEPLOYMENT/GFCS_DAH_msfabric_post_deployment_UAT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=16)
* [PRD/MSFABRIC_POST_DEPLOYMENT/GFCS_DAH_msfabric_post_deployment_PRD_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=13)

## Azure ADF Post Deployment

This script `azure_adf_post_deployment.sh` automates the process of deploying Azure Data Factory (ADF) resources using Azure CLI. It handles various parameters such as workspace, environment, ADF templates, and system database connection strings to facilitate a smooth deployment process.

> The script `azure_adf_post_deployment.sh` also uses the [dah_adf](https://dev.azure.com/gfcs/DAH/_git/dah_adf?version=GBadf_publish&_a=contents) repository as input, from which it retrieves ARM templates and dynamically modifies their parameters (several IDs).

> The script `azure_adf_post_deployment.sh` is executed as part of the [MS Fabric Post Deployment pipeline](#ms-fabric-post-deployment-pipeline).

<div style="border: 2px solid red; padding: 10px;">
IMPORTANT: The script needs the parameter "--systemdb-conn" and its value from the "input_vars.yaml" file. This is not an ideal solution, and if Microsoft supports REST API to retrieve the systemdb-conn string in the future, this will need to be changed. 


FOR NOW, IT IS NECESSARY TO ALWAYS VERIFY OR MODIFY ITS VALUE BEFORE RUNNING THE POST-DEPLOYMENT PIPELINE!
</div>


The script takes these parameters:
1. **--workspace \<workspace\>**: Workspace name (e.g., `GFCS SIT IDL`).
2. **--env \<environment\>**: The environment of the workspace (e.g., `DEV`, `SIT`, `UAT`, `PRD`).
3. **--adf-params-template \<adf_params_template\>** The ADF parameters ARM template file (e.g., `adf_template_params.json`).
4. **--adf-template-file \<adf_template_file\>** The ADF ARM template file (e.g., `ARMTemplateForFactory.json`).
5. **--adf-name \<adf_name\>** The ADF name (e.g., `gfcsneuwadf001i`).
6. **--keyvault-name \<keyvault_name\>** The KeyVault name (e.g., `GFCSKV0002I`).
7. **--systemdb-conn \<systemdb_conn\>** The system database connection string (e.g., `ula7lufi5h7ujiomwckmhgue3a-7q65wn5jmtqezlqvh5yftjq3hu.datawarehouse.fabric.microsoft.com`).
8. **--resource-group \<resource_group\>** The resource group name (e.g., `GFCS-P-EUW-RG-10093553-DAH-I`).
9. **--service-principal-id \<service_principal_id\>** The Azure Service Principal ID (e.g., `6573cd66-a81e-4b26-8683-01114ddfe17d`).
10. **--storage-account-name \<storage_account_name\>** The storage account name (e.g., `gfcsneuwsa001i`).
11. **--subscription-id \<subscription_id\>** Subscription id.
12. **--adf-shir-adf-name \<adf_shir_adf_name\>** ADF SHIR adf name (e.g., `gfcspeuwadf001`). 
13. **--adf-shir-resource-group \<adf_shir_resource_group>** ADF SHIR adf resource group name (e.g., `GFCS-P-EUW-RG-10093255-DAH-P`). 
14. **--help**: Get Manage Notebooks script help

#### Example:
```bash
dah_devops/pipelines/scripts/azure_adf_deployment.sh --workspace "GFCS SIT IDL" --env "SIT" --adf-template-file "ARMTemplateForFactory.json" --adf-name "gfcsneuwadf001i" --keyvault-name "GFCSKV0002I" --systemdb-conn "ula7lufi5h7ujiomwckmhgue3a-7q65wn5jmtqezlqvh5yftjq3hu.datawarehouse.fabric.microsoft.com" --resource-group "GFCS-P-EUW-RG-10093553-DAH-I" --service-principal-id "6573cd66-a81e-4b26-8683-01114ddfe17d" --adf-params-template "adf_template_params.json" --storage-account-name "gfcsneuwsa001i" --subscription-id "cf329f3a-318f-45e5-9130-7a2a40d8cb6f" --adf-shir-adf-name "gfcspeuwadf001" --adf-shir-resource-group "GFCS-P-EUW-RG-10093255-DAH-P"
```

## Power BI import new resources to Fabric pipeline

This PowerShell script [powerbi_manage_resources.ps1](https://dev.azure.com/gfcs/DAH/_git/dah_devops?path=/pipelines/scripts/powerbi_manage_resources.ps1) is used to automate the process of importing Power BI reports and semantic models into a Fabric workspace. It utilizes a service principal for authentication, validates the paths for the semantic model and report files, and communicates with the Fabric API to import items into the workspace.

### Prerequisities
* Powershell version 7
* 3rd party PowerBI wrapper/package [FabricPS-PBIP](https://github.com/microsoft/Analysis-Services/tree/master/pbidevmode/fabricps-pbip) in GitHub which was copied within `dah_devops` repository: [pwsh_modules](https://dev.azure.com/gfcs/DAH/_git/dah_devops?path=/pipelines/scripts/pwsh_modules)
* Az.Accounts package
* MicrosoftPowerBIMgmt package
* Access to KeyVault for Azure Devops Variable Group

### Usage

#### List of existing PowerBI manage resources pipelines in Azure Devops

This pipeline relies on an external Azure DevOps repository called [dah_fabric_ws](https://dev.azure.com/gfcs/DAH/_git/dah_pbi). The repository is necessary for accessing the required files and scripts for uploading and deleting CSV files in OneLake.

* [SIT/POWERBI_MANAGE_AND_CREATE_RESOURCES/GFCS_DAH_powerbi_manage_and_create_resources_deployment_SIT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=23)
* [UAT/POWERBI_MANAGE_AND_CREATE_RESOURCES/GFCS_DAH_powerbi_manage_and_create_resources_deployment_UAT_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=24)
* [UAT/POWERBI_MANAGE_AND_CREATE_RESOURCES/GFCS_DAH_powerbi_manage_and_create_resources_deployment_PRD_env](https://dev.azure.com/gfcs/DAH/_build?definitionId=25)

#### Example

##### Import new PowerBI resorces(Semantic model && Reports)

1. **-pbiReportPath \<pbiReportPath\>**: Power BI Report path in `dah_pbi` repository.
2. **-pbiSemanticModelPath \<pbiSemanticModelPath\>**: Power BI Semantic Model path in `dah_pbi` repository.
3. **-workspaceName \<workspaceName\>**: Workspace name (e.g., `GFCS SIT IDL`).
4. **-servicePrincipalSecret \<servicePrincipalSecret\>** The secret key for Devops Service Principal. Required for authentication.
5. **-servicePrincipalId \<servicePrincipalId\>**:The client ID of Devops Service Principal. Required for authentication.
6. **-tenantId \<tenantId\>**:  The tenant ID for Azure Active Directory. Required for authentication.
7. **-semanticModelName \<semanticModelName\>**:  A name of the new Semantic Model to create.
8. **-warehouseDisplayName \<warehouseDisplayName\>**:  Warehouse display name.


```pwsh
 pwsh.exe .\dah_devops\pipelines\scripts\powerbi_manage_resources.ps1 -tenantId "${{ parameters.tenant_id }}" -servicePrincipalId "${{ parameters.devops_admin_principal_id }}" -servicePrincipalSecret "$(DevOps-SP-Secret)" -workspaceName "GFCS SIT CDL OtC" -pbiSemanticModelPath "${sales_pricing_semantic_model_path}" -pbiReportPath "${sales_pricing_report_path}"
 -semanticModelName "sales_pricing" -warehouseDisplayName "pl_sales_pricing_dm_wh"
```

## Used Links
* [GFCS DevOps Architecture](https://georgfischer.sharepoint.com/:w:/r/sites/GFAG-TranS4mation/_layouts/15/doc2.aspx?sourcedoc=%7Bc14c3814-901e-4f1d-9567-2374d3d728f1%7D&action=edit&wdPid=4a078234)
* [Azure Devops pipelines doc](https://learn.microsoft.com/en-us/azure/devops/pipelines/?view=azure-devops)
* [Bicep doc](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
* [MS Fabric REST API doc](https://learn.microsoft.com/en-us/rest/api/fabric/articles/)
* [DACPAC extract doc](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-extract?view=sql-server-ver16)
* [DACPAC publish doc](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-publish?view=sql-server-ver16)
* [Use Python to manage files and folders in Microsoft OneLake](https://learn.microsoft.com/en-us/fabric/onelake/onelake-access-python)
* [3rd party Powershell fabricps-pbip wrapper/package in Github](https://github.com/microsoft/Analysis-Services/tree/master/pbidevmode/fabricps-pbip)
* [Deploy a Power BI project using Fabric APIs](https://learn.microsoft.com/en-us/rest/api/fabric/articles/get-started/deploy-project?toc=%2Fpower-bi%2Fdeveloper%2Fprojects%2FTOC.json)