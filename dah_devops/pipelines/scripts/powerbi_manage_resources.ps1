[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$tenantId,

    [Parameter(Mandatory=$true)]
    [string]$servicePrincipalId,

    [Parameter(Mandatory=$true)]
    [string]$servicePrincipalSecret,

    [Parameter(Mandatory=$true)]
    [string]$workspaceName,

    [Parameter(Mandatory=$true)]
    [string]$pbiSemanticModelPath,

    [Parameter(Mandatory=$true)]
    [string]$pbiReportPath,

    [Parameter(Mandatory=$true)]
    [string]$semanticModelName,

    [Parameter(Mandatory=$true)]
    [string]$warehouseName
)

Write-Host "Tenant ID: $tenantId"
Write-Host "Service Principal ID: $servicePrincipalId"
Write-Host "Service Principal SECRET: ********"
Write-Host "Workspace NAME: $workspaceName"
Write-Host "Power BI Semantic Model PATH: $pbiSemanticModelPath"
Write-Host "Power BI Report PATH: $pbiReportPath"
Write-Host "Semantic Model NAME: $semanticModelName"
Write-Host "Warehouse NAME: $warehouseName"

if (-not (Test-Path $pbiSemanticModelPath)) {
    throw "The semantic model path '$pbiSemanticModelPath' does not exist."
}

if (-not (Test-Path $pbiReportPath)) {
    throw "The report path '$pbiReportPath' does not exist."
}

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

Import-Module ".\dah_devops\pipelines\scripts\pwsh_modules\FabricPS-PBIP.psm1" -Force

$fabricBaseUrl = "https://api.fabric.microsoft.com"

$tmdl_files = Get-ChildItem -Path "$pbiSemanticModelPath\*" -File -Recurse
$tmdls = @() # [(name, upd, is_conn)]
foreach ($f in $tmdl_files){
    if ($f.Extension -eq ".tmdl") {
        $tmdls += [PSCustomObject]@{
            name     = $f.FullName
            f_name   = $f.Name
            upd      = "$($f.Directory)\updated_$($f.Name)"
            is_conn  = $(if ( ($f.Name.Substring(0, 3) -eq "vw_") ) {"True"} else {"False"} )
        }
    }
}

foreach ($tmdl in $tmdls) {
    New-Item -Path $tmdl.upd -Force
}

function Get-WarehouseConnectionString {
    param (
        [Parameter(Mandatory = $true)]
        [string]$accessToken,

        [Parameter(Mandatory = $true)]
        [string]$workspaceId,

        [Parameter(Mandatory = $true)]
        [string]$warehouseDisplayName
    )

    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }

    try {
        $url = "$fabricBaseUrl/v1/workspaces/$workspaceId/warehouses"
        $response = Invoke-RestMethod -Uri $url -Method 'GET' -Headers $headers

        foreach ($item in $response.value) {
            if ($item.displayName -eq $warehouseDisplayName) {
                return $item.properties.connectionString
            }
        }

        Write-Error "Warehouse with displayName '$warehouseDisplayName' not found."
    } catch {
        Write-Error "An unexpected error occurred: $_"
        if ($_.Exception.Response) {
            Write-Output "Response: $($_.Exception.Response)"
        }
    }
}

function New-SemanticModel {
    param (
        [Parameter(Mandatory = $true)]
        [string]$workspaceId,

        [Parameter(Mandatory = $true)]
        [string]$displayName,

        [Parameter(Mandatory = $false)]
        [string]$description = "",

        [Parameter(Mandatory = $true)]
        [array]$definitionParts,

        [Parameter(Mandatory = $true)]
        [string]$accessToken
    )

    $url = "$fabricBaseUrl/v1/workspaces/$workspaceId/semanticModels"

    $body = @{
        displayName = $displayName
        description = $description
        definition  = @{
            parts = $definitionParts
        }
    } | ConvertTo-Json -Depth 10

    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }

    Write-Output "Request body: $body"

    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body

    return $response
}

function New-ConnectionString {
	param (
        [Parameter(Mandatory = $true)]
        [string]$newWarehouseConnectionString,

        [Parameter(Mandatory = $true)]
        [string]$inputFilePath,

        [Parameter(Mandatory = $true)]
        [string]$outputFilePathLocation
    )

	$outputFilePath = $outputFilePathLocation
	$newString = $newWarehouseConnectionString
	$content = Get-Content -Path $inputFilePath -Raw
	$pattern = "ula7lufi5h7ujiomwckmhgue3a-[\w-]+\.datawarehouse\.fabric\.microsoft\.com"
	$updatedContent = $content -replace $pattern, $newString

	Set-Content -Path $outputFilePath -Value $updatedContent

	Write-Output "New *.tmdl file stored as '$outputFilePath'."
}


function Get-FileBase64 {
    param (
        [Parameter(Mandatory = $true)]
        [string]$filePath
    )
    $fileContent = [System.IO.File]::ReadAllBytes($filePath)
    return [System.Convert]::ToBase64String($fileContent)
}


function Get-SemanticModel {
    param (
        [Parameter(Mandatory = $true)]
        [string]$workspaceId,

        [Parameter(Mandatory = $true)]
        [string]$accessToken,

		[Parameter(Mandatory = $true)]
        [string]$displayName
    )

    $url = "$fabricBaseUrl/v1/workspaces/$workspaceId/semanticModels"

    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Method 'GET' -Headers $headers
		$semanticModelId = $response.value | Where-Object { $_.displayName -eq "$displayName" }
		return $semanticModelId
    } catch {
        Write-Error "An unexpected error occurred: $_"
    }
}

function Remove-SemanticModel {
    param (
        [Parameter(Mandatory = $true)]
        [string]$workspaceId,

        [Parameter(Mandatory = $true)]
        [string]$accessToken,

		[Parameter(Mandatory = $true)]
        [string]$semanticModelId
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer $accessToken")

    $response = Invoke-RestMethod "$fabricBaseUrl/v1/workspaces/$workspaceId/semanticModels/$semanticModelId" -Method 'DELETE' -Headers $headers
    $response | ConvertTo-Json
}


try {
    $secureSecret = ConvertTo-SecureString $servicePrincipalSecret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($servicePrincipalId, $secureSecret)

    Set-FabricAuthToken -servicePrincipalId $servicePrincipalId -servicePrincipalSecret $servicePrincipalSecret -tenantId $tenantId -reset

    Connect-PowerBIServiceAccount -ServicePrincipal -TenantId $tenantId -Credential $credential

    $workspaceId =  (Get-PowerBIWorkspace -Scope Individual -All | Where-Object { $_.Name -eq $workspaceName }).Id.Guid
    if (-not $workspaceId) {
        throw "Workspace '$workspaceName' not found or could not be retrieved."
    }
    Write-Host "Workspace ID: $workspaceId"

    Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $tenantId
    $accessToken = (Get-AzAccessToken -ResourceUrl $fabricBaseUrl).Token

    $warehouseConnectionString = Get-WarehouseConnectionString -accessToken $accessToken -workspaceId $workspaceId -warehouseDisplayName $warehouseName
	Write-Host "Warehouse Connection String: $warehouseConnectionString"

    foreach ($tmdl in $tmdls) {
        if($tmdl.is_conn -eq "True") {
            New-ConnectionString -newWarehouseConnectionString $warehouseConnectionString -inputFilePath $tmdl.name $tmdl.upd
        }
    }

	$semanticModels = Get-SemanticModel -workspaceId $workspaceId -accessToken $accessToken -displayName $semanticModelName
    $semanticModelIdsToRemove = @()

    if ($semanticModels) {
        foreach ($model in $semanticModels) {
            if ($model -and $model.id) {
                $semanticModelIdsToRemove += $model.id
            }
        }
    }

    if ($semanticModelIdsToRemove.Count -gt 0) {
        foreach ($id in $semanticModelIdsToRemove) {
            Write-Host "Removing Semantic Model with ID: $id"
            Remove-SemanticModel -workspaceId $workspaceId -accessToken $accessToken -semanticModelId $id
            Write-Host "Semantic Model $id removed."
        }
    } else {
        Write-Host "No existing Semantic Models found with the name '$semanticModelName'."
    }

    [array]$definitionParts = @()
    foreach ($tmdl in $tmdls) {
        $definitionParts += [PSCustomObject]@{
            path        = "definition/$($tmdl.f_name)"
            payload     = Get-FileBase64 -filePath $(if ($tmdl.is_conn -eq "True") { $tmdl.upd } else { $tmdl.name } )
            payloadType = "InlineBase64"
        }
    }
    $definitionParts += [PSCustomObject]@{
        path        = "definition.pbism"
        payload     = Get-FileBase64 -filePath "$pbiSemanticModelPath\definition.pbism"
        payloadType = "InlineBase64"
    }
    $definitionParts += [PSCustomObject]@{
        path        = ".platform"
        payload     = Get-FileBase64 -filePath "$pbiSemanticModelPath\.platform"
        payloadType = "InlineBase64"
    }
    $definitionParts += [PSCustomObject]@{
        path        = "diagramLayout.json"
        payload     = Get-FileBase64 -filePath "$pbiSemanticModelPath\diagramLayout.json"
        payloadType = "InlineBase64"
    }

	New-SemanticModel -workspaceId $workspaceId `
		-displayName $semanticModelName `
		-description "Semantic model: $semanticModelName" `
		-definitionParts $definitionParts `
		-accessToken $accessToken
	Start-Sleep -Seconds 10
	$semanticModelImport = Get-SemanticModel -workspaceId $workspaceId -accessToken $accessToken -displayName $semanticModelName
	Write-Host "New Semantic Model ID: $($semanticModelImport.id)"

    $reportImport = Import-FabricItem -workspaceId $workspaceId -path $pbiReportPath -itemProperties @{"semanticModelId" = $semanticModelImport.id }
    if (-not $reportImport) {
        throw "Failed to import Power BI report from path '$pbiReportPath'."
    }

    Write-Host "Power BI Report import response: $reportImport"
} catch {
    Write-Error "An unexpected error occurred: $_"
    exit 1
}
