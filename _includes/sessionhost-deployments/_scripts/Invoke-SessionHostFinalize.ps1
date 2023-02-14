[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$VmResourceId,
    [Parameter(Position = 1, Mandatory = $true)]
    [string]$HostPoolName,
    [Parameter(Position = 2, Mandatory = $true)]
    [string]$DomainName
)

$writeInfoSplat = @{
    "InformationAction" = "Continue";
}

Connect-AzAccount -Identity -Tenant "16cc8ad9-84fe-481d-b9b0-48e7758c41aa" -Subscription "f01b1a05-dca3-4a19-9132-f1d18d758182"

$vmObj = Get-AzResource -ResourceId $VmResourceId | Get-AzVM

$sessionHostFound = $false
while ($sessionHostFound -eq $false) {
    try {
        Get-AzWvdSessionHost -ResourceGroupName $vmObj.ResourceGroupName -HostPoolName $HostPoolName -Name "$($vmObj.Name).$($DomainName)" -ErrorAction "Stop"
        $sessionHostFound = $true
    }
    catch {
        Write-Warning "Session host not registered yet."
        Start-Sleep -Seconds 30
    }
}

Write-Information @writeInfoSplat -MessageData "Setting session host to drain mode."
$null = Update-AzWvdSessionHost -ResourceGroupName $vmObj.ResourceGroupName -HostPoolName $HostPoolName -Name "$($vmObj.Name).$($DomainName)" -AllowNewSession:$false

Write-Information @writeInfoSplat -MessageData "Waiting for session host to switch to drain mode."
Start-Sleep -Seconds 30
$sessionHostStatusIsAvailable = $false
$sessionHostStatusIsValid = $true
$sessionHostUnavailableCounter = 0
while ($sessionHostStatusIsAvailable -eq $false) {
    $sessionHostStatus = Get-AzWvdSessionHost -ResourceGroupName $vmObj.ResourceGroupName -HostPoolName $HostPoolName -Name "$($vmObj.Name).$($DomainName)"

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