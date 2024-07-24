[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [string]$TenantId,
    [Parameter(Position = 1, Mandatory)]
    [string]$SubscriptionId,
    [Parameter(Position = 2, Mandatory)]
    [string]$ResourceGroupName,
    [Parameter(Position = 3, Mandatory)]
    [string]$HostPoolName
)

Connect-AzAccount -Identity -Tenant $TenantId -Subscription $SubscriptionId

$expirationDateTime = [datetime]::Now.AddHours(6)
$expirationDateTimeString = $expirationDateTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")

$regToken = New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ExpirationTime $expirationDateTimeString

$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs['regToken'] = $regToken.Token