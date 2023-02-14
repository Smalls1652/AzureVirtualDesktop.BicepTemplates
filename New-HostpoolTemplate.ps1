[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName
)

$templatePath = Join-Path -Path $PSScriptRoot -ChildPath "_template/"
$outPath = Join-Path -Path $PSScriptRoot -ChildPath "$($HostPoolName)/"

if (Test-Path -Path $outPath) {
    $PSCmdlet.ThrowTerminatingError(
        [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new("A directory for '$($HostPoolName)' already exists."),
            "HostpoolDirAlreadyExists",
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $outPath
        )
    )
}

Copy-Item -Path $templatePath -Destination $outPath -Recurse