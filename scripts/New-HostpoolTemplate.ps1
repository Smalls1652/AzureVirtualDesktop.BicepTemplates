[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,
		[Parameter(Position = 1)]
		[ValidateNotNullOrWhiteSpace()]
		[string]$RootPath
)

$templatePath = Join-Path -Path $RootPath -ChildPath ".template-files/"
$filesToCopy = Get-ChildItem -Path $templatePath | Where-Object { $PSItem.Extension -eq ".bicepparam" }
$hostpoolsDirPath = Join-Path -Path $RootPath -ChildPath "Hostpools/"
$outPath = Join-Path -Path $hostpoolsDirPath -ChildPath "$($HostPoolName)/"

$bicepParamUsingRegex = [regex]::new("using '(?'usingPath'.+?)'")

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

    $bicepFile = Get-Item -Path (Join-Path -Path $RootPath -ChildPath "$($fileItem.BaseName).bicep")

    $templateFileContent = Get-Content -Path $fileItem.FullName -Raw

    $updatedTemplateFileContent = $bicepParamUsingRegex.Replace($templateFileContent, "using '$([System.IO.Path]::GetRelativePath($outPath, $bicepFile.FullName))'")

    Write-Verbose "Copying '$($fileItem.Name)' to '$($outFilePath)'."
    Out-File -InputObject $updatedTemplateFileContent -FilePath $outFilePath -Force -Encoding "UTF8"
}

$outDirectory
