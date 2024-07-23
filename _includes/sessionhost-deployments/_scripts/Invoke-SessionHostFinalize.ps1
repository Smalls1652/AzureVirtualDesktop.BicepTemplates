[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [string]$TenantId,
    [Parameter(Position = 1, Mandatory)]
    [string]$SubscriptionId,
    [Parameter(Position = 2, Mandatory = $true)]
    [string]$VmResourceId,
    [Parameter(Position = 3, Mandatory = $true)]
    [string]$HostPoolName,
    [Parameter(Position = 4)]
    [string]$DomainName
)

$writeInfoSplat = @{
    "InformationAction" = "Continue";
}

Connect-AzAccount -Identity -Tenant $TenantId -Subscription $SubscriptionId

$vmObj = Get-AzResource -ResourceId $VmResourceId | Get-AzVM

$vmName = $null

if ($null -eq $DomainName -or [string]::IsNullOrWhiteSpace($DomainName)) {
  $vmName = $vmObj.Name
}
else {
  $vmName = "$($vmObj.Name).$($DomainName)"
}

$sessionHostFound = $false
while ($sessionHostFound -eq $false) {
    try {
        Get-AzWvdSessionHost -ResourceGroupName $vmObj.ResourceGroupName -HostPoolName $HostPoolName -Name $vmName -ErrorAction "Stop"
        $sessionHostFound = $true
    }
    catch {
        Write-Warning "Session host not registered yet."
        Start-Sleep -Seconds 30
    }
}

Write-Information @writeInfoSplat -MessageData "Setting session host to drain mode."
$null = Update-AzWvdSessionHost -ResourceGroupName $vmObj.ResourceGroupName -HostPoolName $HostPoolName -Name $vmName -AllowNewSession:$false

Write-Information @writeInfoSplat -MessageData "Waiting for session host to switch to drain mode."
Start-Sleep -Seconds 30
$sessionHostStatusIsAvailable = $false
$sessionHostStatusIsValid = $true
$sessionHostUnavailableCounter = 0
while ($sessionHostStatusIsAvailable -eq $false) {
    $sessionHostStatus = Get-AzWvdSessionHost -ResourceGroupName $vmObj.ResourceGroupName -HostPoolName $HostPoolName -Name $vmName

    switch ($sessionHostStatus.Status) {
        "Available" {
            Write-Information @writeInfoSplat -MessageData "Session host status is available."
            $sessionHostStatusIsAvailable = $true
            break
        }

        "Upgrading" {
            Write-Warning "Session host is still in the upgrading status."
            $sessionHostStatusIsAvailable = $false
            break
        }

        "Unavailable" {
            $sessionHostUnavailableCounter++

            if ($sessionHostUnavailableCounter -gt 10) {
                Write-Warning "Session host is still showing as unavailable."
                $sessionHostStatusIsAvailable = $true
                $sessionHostStatusIsValid = $false
            }
            else {
                Write-Warning "Session host is showing as unavailable. Wait counter is at $($sessionHostUnavailableCounter)."
            }
            break
        }

        Default {
            Write-Warning "Session host has a status that was not expected."
            $sessionHostStatusIsAvailable = $true
            $sessionHostStatusIsValid = $false
            break
        }
    }

    Start-Sleep -Seconds 15
}

if ($sessionHostStatusIsValid -eq $true) {
    Write-Information @writeInfoSplat -MessageData "Restarting VM."
    $null = $vmObj | Restart-AzVM -NoWait -Verbose:$false
}
else {
    Write-Warning "VM was not rebooted due to an invalid status returned by the session host."
}
