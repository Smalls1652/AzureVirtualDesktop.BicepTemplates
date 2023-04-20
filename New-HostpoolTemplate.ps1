[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName
)

$templatePath = Join-Path -Path $PSScriptRoot -ChildPath "_template/"
$filesToCopy = Get-ChildItem -Path $templatePath
$hostpoolsDirPath = Join-Path -Path $PSScriptRoot -ChildPath "hostpools/"
$outPath = Join-Path -Path $hostpoolsDirPath -ChildPath "$($HostPoolName)/"

if (!(Test-Path -Path $hostpoolsDirPath)) {
    Write-Warning "'$($hostpoolsDirPath)' does not already exist. Creating..."
    $null = New-Item -Path $hostpoolsDirPath -ItemType "Directory"
}

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

Write-Verbose "Output folder will be: $($outPath)"
$outDirectory = New-Item -Path $outPath -ItemType "Directory"
foreach ($fileItem in $filesToCopy) {
    $outFilePath = Join-Path -Path $outPath -ChildPath $fileItem.Name
    Write-Verbose "Copying '$($fileItem.Name)' to '$($outFilePath)'."
    Copy-Item -Path $fileItem.FullName -Destination $outFilePath
}

$outDirectory