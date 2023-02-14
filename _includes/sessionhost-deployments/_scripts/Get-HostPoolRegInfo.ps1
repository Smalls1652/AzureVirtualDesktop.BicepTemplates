[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [string]$ResourceGroupName,
    [Parameter(Position = 1, Mandatory)]
    [string]$HostPoolName
)

Connect-AzAccount -Identity -Tenant "16cc8ad9-84fe-481d-b9b0-48e7758c41aa" -Subscription "f01b1a05-dca3-4a19-9132-f1d18d758182"

$expirationDateTime = [datetime]::Now.AddHours(6)
$expirationDateTimeString = $expirationDateTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")

$regToken = New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ExpirationTime $expirationDateTimeString

$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs['regToken'] = $regToken.Token