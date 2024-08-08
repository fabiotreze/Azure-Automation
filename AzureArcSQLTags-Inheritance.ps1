# Requirements 
# Install modules most recent: Az.Accounts and Az.ResourceGraph latest version

# Define the parameters to be required at runtime
param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,  # Nome do Resource Group

    [Parameter(Mandatory=$true)]
    [string]$Subscription  # Nome da Subscrição
)

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process | Out-Null

try {
    # Connect to Azure with user-assigned managed identity
    $AzureContext = (Connect-AzAccount -Identity -AccountId SeuID).context
    
    # Set and store context with the specified subscription
    $AzureContext = Set-AzContext -SubscriptionName $Subscription -DefaultProfile $AzureContext
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

# Executes the query and store the result in the variable $result
$query = @"
resources
| where type =~ 'Microsoft.AzureArcData/SqlServerInstances'
| where resourceGroup == '$ResourceGroupName'  // Filtra pelo Resource Group
| extend subscriptionId = subscriptionId, 
         arcInstanceContainerId = tostring(split(properties['containerResourceId'], '/')[8])  // Captura o containerResourceId do recurso Arc
| join kind=inner (
    resources
    | where type =~ 'Microsoft.HybridCompute/machines'
    | extend hybridMachineName = name,  // Captura o nome da maquina hibrida
             hybridMachineTagCentroDeCusto = coalesce(tags['centro_de_custo'], '') // Captura a tag centro_de_custo da maquina hibrida, tratando nulos
) on `$left.arcInstanceContainerId == `$right.hybridMachineName and `$left.subscriptionId == `$right.subscriptionId
| extend sqlInstanceTagCentroDeCusto = coalesce(tags['centro_de_custo'], '') // Captura a tag centro_de_custo do SQL Instance, tratando nulos
| extend tagsDiffer = sqlInstanceTagCentroDeCusto != hybridMachineTagCentroDeCusto // Adiciona um campo para indicar se as tags sao diferentes
| extend complianceStatus = case(
    isnull(sqlInstanceTagCentroDeCusto) or isnull(hybridMachineTagCentroDeCusto), 'Nao Conformidade',  // Se qualquer tag for nula, esta em nao conformidade
    tagsDiffer, 'Nao Conformidade',  // Se as tags forem diferentes, esta em nao conformidade
    'Em Conformidade'  // Caso contrario, esta em conformidade
)
| project 
    ['Azure Arc VM Source Name'] = hybridMachineName,  // Nome da maquina hibrida
    ['Azure Arc VM Source Name Tag centro_de_custo'] = hybridMachineTagCentroDeCusto, // Azure Arc VM Source Name Tag centro_de_custo
    ['SQL Instance ID'] = id, // SQL Instance ID
    ['SQL Instance'] = name,  // Nome do SQL Server e SQL Instance
    ['SQL Instance Tag centro_de_custo'] = sqlInstanceTagCentroDeCusto, // SQL Instance Tag centro_de_custo
    ['Azure Arc VM Source Name by SQL Instance'] = arcInstanceContainerId,  // ID do container associado ao recurso Arc
    ['Tags Differ'] = tagsDiffer,  // Adiciona campo para indicar se as tags sao diferentes
    ['Compliance Status'] = complianceStatus  // Adiciona campo para indicar o status de conformidade
"@

# Execute the query
$result = Search-AzGraph -Query $query
    
# Project the desired columns
$projectedResult = $result | Select-Object 'Azure Arc VM Source Name', 'Azure Arc VM Source Name Tag centro_de_custo', 'SQL Instance ID', 'SQL Instance', 'SQL Instance Tag centro_de_custo', 'Azure Arc VM Source Name by SQL Instance', 'Tags Differ', 'Compliance Status'

# Filter the projected result based on Compliance Status
$filteredResult = $projectedResult | Where-Object { $_.'Compliance Status' -eq 'Nao Conformidade' }

Write-Output "Recursos em Nao Conformidade"
$filteredResult

# Check if the filtered result is empty
if ($filteredResult.Count -eq 0) {
    Write-Output "No results found in the query."
}
else {
    # Loop through resources to add tags
    foreach ($resource in $filteredResult) {
        $id = $resource.'SQL Instance ID'
        $arcVMName = $resource.'Azure Arc VM Source Name'
        $arcVMTagValue = $resource.'Azure Arc VM Source Name Tag centro_de_custo'
        
        # Check if the values are present
        if ($id -and $arcVMName -and $arcVMTagValue) {
            # Create the tag using the Azure Arc VM tag value
            $tag = @{
                'centro_de_custo' = $arcVMTagValue
            }
            # Apply the tag to the SQL instance
            Update-AzTag -Tag $tag -ResourceId $id -Operation Merge -Verbose
            
            # Output the modified resource information
            Write-Output "Resource modified: SQL Instance ID: $id, Tag: centro_de_custo = $arcVMTagValue"
        }
        else {
            Write-Output "Incomplete values to create the tag. ID: $id, Tag Name: $arcVMName, Tag Value: $arcVMTagValue"
        }
    }
}
