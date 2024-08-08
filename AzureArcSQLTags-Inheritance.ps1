# Requirements 
# Install modules most recentes: Az.Accounts and Az.ResourceGraph

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process | Out-Null

try {
    # Connect to Azure with user-assigned managed identity
    $AzureContext = (Connect-AzAccount -Identity -AccountId "ID_DA_USER_ASSIGNED").context
    # set and store context
    $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

# Executes the query and store the result in the variable $result
$query = "resources
| where type =~ 'Microsoft.AzureArcData/SqlServerInstances'
| extend subscriptionId = subscriptionId, 
         arcInstanceContainerId = tostring(split(properties['containerResourceId'], "/")[8])  // Captura o containerResourceId do recurso Arc
| join kind=inner (
    resources
    | where type =~ 'Microsoft.HybridCompute/machines'
    | extend hybridMachineName = name,  // Captura o nome da máquina híbrida
             hybridMachineTagCentroDeCusto = coalesce(['tags']['centro_de_custo'], '') // Captura a tag centro_de_custo da máquina híbrida, tratando nulos
) on $left.arcInstanceContainerId == $right.hybridMachineName and $left.subscriptionId == $right.subscriptionId
| extend sqlInstanceTagCentroDeCusto = coalesce(['tags']['centro_de_custo'], '') // Captura a tag centro_de_custo do SQL Instance, tratando nulos
| extend tagsDiffer = sqlInstanceTagCentroDeCusto != hybridMachineTagCentroDeCusto // Adiciona um campo para indicar se as tags são diferentes
| extend complianceStatus = case(
    isnull(sqlInstanceTagCentroDeCusto) or isnull(hybridMachineTagCentroDeCusto), 'Não Conformidade',  // Se qualquer tag for nula, está em não conformidade
    tagsDiffer, 'Não Conformidade',  // Se as tags forem diferentes, está em não conformidade
    'Conformidade'  // Caso contrário, está em conformidade
)
| project 
    ['Azure Arc VM Source Name'] = hybridMachineName,  // Nome da máquina híbrida
    ['Azure Arc VM Source Name Tag centro_de_custo'] = hybridMachineTagCentroDeCusto, // Azure Arc VM Source Name Tag centro_de_custo
    ['SQL Instance ID'] = ['id'], // SQL Instance ID
    ['SQL Instance'] = name,  // Nome do SQL Server e SQL Instance
    ['SQL Instance Tag centro_de_custo'] = sqlInstanceTagCentroDeCusto, // SQL Instance Tag centro_de_custo
    ['Azure Arc VM Source Name by SQL Instance'] = arcInstanceContainerId,  // ID do container associado ao recurso Arc
    ['Tags Differ'] = tagsDiffer,  // Adiciona campo para indicar se as tags são diferentes
    ['Compliance Status'] = complianceStatus  // Adiciona campo para indicar o status de conformidade"
    
$result = Search-AzGraph -Query $query
    
# Project the desired columns
$projectedResult = $result | Select-Object id, hybridMachineName, hybridMachineTagCentroDeCusto, name, sqlInstanceTagCentroDeCusto, arcInstanceContainerId, tagsDiffer, complianceStatus
    
# Check if the project result is empty
if ($projectedResult.Count -eq 0) {
    Write-Output "No results found in the query."
}
else {
    # Loop for resources to add tags
    foreach ($resource in $projectedResult) {
        $id = $resource.id1
        $vmtag_name = $resource.vmtag_name
        $vmtag_value = $resource.vmtag_value
        # Check if the values are present
        if ($id -and $vmtag_name -and $vmtag_value) {
            # Create the tag
            $tag = @{
                $vmtag_name = $vmtag_value
            }
            # Apply the tag to the resource
            Update-AzTag -Tag $tag -ResourceId $id -Operation Merge -Verbose # Uncomment this line when needed
        }
        else {
            Write-Output "Incomplete values to create the tag. ID: $id, Tag Name: $vmtag_name, Tag Value: $vmtag_value"
        }
    }
}