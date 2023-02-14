[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0, Mandatory)]
    [string]$RegistrationToken
)

<#
        Notes about this script:

        **This script is meant to be passed to a Windows 10/Server VM in Azure with the 'Invoke-AzVMRunCommand' cmdlet.**

        It will take advantage of PowerShell 7. The 'RunPowerShellScript' extension of the Azure VM agent will default to Windows PowerShell 5.1.
        I personally write all of my scripts to work with PowerShell 7 because of the features it brings that PS 5.1 can't do.
        The script will be ran through the PS 5.1 process, but will launch multiple PS 7 processes to execute the primary portions of this script.

        This is easily achievable because 'pwsh.exe' will take a script block in the '-Command' argument.
        Since the PS 5.1 process recognizes the 'ScriptBlock' type, we can pass the core logic to it without having to backport to PS 5.1.
        For more information, see this section in the help docs:
        https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pwsh?view=powershell-7.1#-command---c

        To also make it so that a registration token isn't hardcoded into the script...
        This script will dynamically update the script block with the supplied registration token.
        #>

# Install the 'PSDesiredStateConfiguration' module.
pwsh.exe -Command { Install-Module -Name "PSDesiredStateConfiguration" -MaximumVersion "2.99" -Scope "AllUsers" -Force -Verbose }

# Install the 'xPSDesiredStateConfiguration' module in the global modules directory for PowerShell 7.
pwsh.exe -Command { Install-Module -Name "xPSDesiredStateConfiguration" -Scope "AllUsers" -Force -Verbose }

# Enable the ability for PowerShell 7 to utilize the 'Invoke-DscResource' cmdlet.
pwsh.exe -Command { Enable-ExperimentalFeature -Name "PSDesiredStateConfiguration.InvokeDscResource" -Scope "AllUsers" }

# This script block is the actual script to run.
$agentInstallScriptBlock = {
    # 'Invoke-AvdAgentInstall' downloads and installs both the AVD Agent and Agent Bootloader.
    function Invoke-AvdAgentInstall {
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [Parameter(Position = 0, Mandatory)]
            [string]$RegistrationToken
        )

        <#
        .CLASS AvdAgentFile
        Houses information about the agent install file.

        .PROPERTY DisplayName
        A friendly name for the file.

        .PROPERTY FileUri
        The URI for downloading the file.

        .PROPERTY DownloadedFileInfo
        The file info of the downloaded file.
        #>
        class AvdAgentFile {
            [string]$DisplayName
            [string]$FileName
            [string]$FileUri
            [System.IO.FileInfo]$DownloadedFileInfo

            AvdAgentFile() {

            }

            AvdAgentFile([string]$name, [string]$uri) {
                $this.DisplayName = $name
                $this.FileUri = $uri
            }

            AvdAgentFile([string]$name, [string]$uri, [string]$fileNameOut) {
                $this.DisplayName = $name
                $this.FileUri = $uri
                $this.FileName = $fileNameOut
            }
        }

        <#
        .SYNOPSIS
        Download a file from the internet.
        
        .DESCRIPTION
        A simple file downloader that downloads a file to a directory without manually specifying the file's ouput name.
        
        .PARAMETER Uri
        The URI of the resource to download.
        
        .PARAMETER OutDir
        The output directory for the file to be downloaded to.
        #>
        function Invoke-WebDownload {
            [CmdletBinding()]
            param(
                [Parameter(Position = 0, Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Uri,
                [Parameter(Position = 1, Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$OutDir,
                [Parameter(Position = 2, Mandatory)]
                [string]$OutFileName
            )

            # Resolve the path supplied in '-OutDir' and ensure that it's a directory.
            $resolvedOutDir = (Resolve-Path -Path $OutDir -ErrorAction "Stop").Path
            $outDirObj = Get-Item -Path $resolvedOutDir
            if ($outDirObj.Attributes -ne [System.IO.FileAttributes]::Directory) {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("Output directory path is not a directory."),
                        "OutputIsNotDir",
                        [System.Management.Automation.ErrorCategory]::InvalidType,
                        $outDirObj
                    )
                )
            }

            # Run 'Invoke-WebRequest' to download the file.
            # The '$ProgressPreference' variable is set to 'SilentlyContinue' temporarily to prevent the performance drawbacks of it.
            Write-Verbose "Downloading file from '$($Uri)'."
            $ProgressPreference = "SilentlyContinue"
            $downloadData = Invoke-WebRequest -Uri $Uri
            $ProgressPreference = "Continue"

            # Generate the output path.
            $outputFilePath = Join-Path -Path $resolvedOutDir -ChildPath $OutFileName
            Write-Verbose "Output path will be '$($outputFilePath)'."

            # If the file already exists, remove it.
            if (Test-Path -Path $outputFilePath) {
                Write-Verbose "File aready exists. Removing the current file."
                Remove-Item -Path $outputFilePath -Force
            }

            # Write the file to the output path.
            Write-Verbose "Writing contents to file."
            $writtenFileStream = [System.IO.File]::Create($outputFilePath)
            $writtenFileStream.Write($downloadData.Content)
            $writtenFileStream.Dispose()

            # Return the 'System.IO.FileInfo' object of the downloaded file.
            $downloadedItem = Get-Item -Path $outputFilePath
            return $downloadedItem
        }

        <#
        .SYNOPSIS
        Get the MSI product code of a MSI installer.
        
        .DESCRIPTION
        Get the MSI product code of a MSI installer without utilizing Orca or any other manual retrieval method.
        
        .PARAMETER FilePath
        The path to the MSI installer.
        #>
        function Get-MsiProductCode {
            [CmdletBinding()]
            param(
                [Parameter(Position = 0, Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$FilePath
            )

            # Resolve the path provided in '-FilePath'.
            $filePathResolved = (Resolve-Path -Path $FilePath -ErrorAction "Stop").Path

            # Create a list to store all of the COM objects into.
            # This will help with disposing them at the end of execution.
            $comObjectList = [System.Collections.Generic.List[System.Object]]::new()

            # Assign the COM object for 'WindowsInstaller.Installer' to a variable and open the database of the provided MSI installer.
            $comObjectList.Add(($msiComObj = New-Object -ComObject "WindowsInstaller.Installer"))
            $comObjectList.Add(($msiObj = $msiComObj.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $msiComObj, @($filePathResolved, 0))))

            # Run a query on the MSI installer to get the product code.
            $comObjectList.Add(($msiView = $msiObj.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $msiObj, "SELECT Value FROM Property WHERE Property = 'ProductCode'")))
            $msiView.GetType().InvokeMember("Execute", "InvokeMethod", $null, $msiView, $null)

            # Get the product code and return it as a string.
            $comObjectList.Add(($msiRecord = $msiView.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $msiView, $null)))
            $msiProductCode = $msiRecord.GetType().InvokeMember("StringData", "GetProperty", $null, $msiRecord, 1)

            # Release all of the COM objects created during execution.
            foreach ($comObj in $comObjectList) {
                $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($comObj)
            }

            return [string]($msiProductCode)
        }

        Import-Module -Name "PSDesiredStateConfiguration"
        Import-Module -Name "xPSDesiredStateConfiguration"

        # Initialize an array of the AVD agents to get.
        $avdAgentFilesToGet = @(
            [AvdAgentFile]::new("AVD Desktop Agent", "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv", "avd-agent.msi"),
            [AvdAgentFile]::new("AVD Desktop Agent Bootloader", "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH", "avd-bootloader.msi")
        )

        # Create a temporary directory at the root of the system drive (Typically C:\) to store the agent installers.
        $tmpDirPath = Join-Path -Path "$($env:SystemDrive)\" -ChildPath "AvdAgentInstall"
        Remove-Item -Path $tmpDirPath -Force -Recurse -ErrorAction "SilentlyContinue"
        $tmpDir = New-Item -Path $tmpDirPath -ItemType "Directory"

        # Download each AVD agent installer.
        foreach ($avdAgent in $avdAgentFilesToGet) {
            Write-Verbose "Downloading '$($avdAgent.DisplayName)''."

            $downloadFileSplat = @{
                "Uri"         = $avdAgent.FileUri;
                "OutDir"      = $tmpDir.FullName;
                "OutFileName" = $avdAgent.FileName;
            }

            $downloadedFile = Invoke-WebDownload @downloadFileSplat

            # Set the 'DownloadedFileInfo' property of the item to the downloaded file's 'System.IO.FileInfo' object.
            $avdAgent.DownloadedFileInfo = $downloadedFile
        }

        # Initialize a generic splat to use with 'Invoke-DscResource'.
        $msiDscMainSplat = @{
            "ModuleName" = "xPSDesiredStateConfiguration";
            "Name"       = "xMsiPackage";
        }

        # AVD agent
        Write-Verbose "Ensuring that the desktop agent is installed."
        $productCodeForAgent = Get-MsiProductCode -FilePath $avdAgentFilesToGet[0].DownloadedFileInfo.FullName
        $msiInstallAgentDsc = @{
            "Path"         = $avdAgentFilesToGet[0].DownloadedFileInfo.FullName;
            "Ensure"       = "Present";
            "ProductId"    = "$($productCodeForAgent)";
            "Arguments"    = "REGISTRATIONTOKEN=$($RegistrationToken)";
            "IgnoreReboot" = $true;
        }

        # Test if the AVD agent is already installed.
        # If not, install the AVD agent.
        $agentTest = Invoke-DscResource @msiDscMainSplat -Method "Test" -Property $msiInstallAgentDsc
        if ($agentTest.InDesiredState -eq $false) {
            if ($PSCmdlet.ShouldProcess("$($avdAgentFilesToGet[0].DisplayName)", "Install")) {
                Invoke-DscResource @msiDscMainSplat -Method "Set" -Property $msiInstallAgentDsc
            }
        }

        # AVD bootloader agent
        Write-Verbose "Ensuring that the desktop agent bootloader is installed."
        $productCodeForAgentBootloader = Get-MsiProductCode -FilePath $avdAgentFilesToGet[1].DownloadedFileInfo.FullName
        $msiInstallAgentBootloaderDsc = @{
            "Path"         = $avdAgentFilesToGet[1].DownloadedFileInfo.FullName;
            "Ensure"       = "Present";
            "ProductId"    = "$($productCodeForAgentBootloader)";
            "IgnoreReboot" = $true;
        }

        # Test if the AVD bootloader agent is already installed.
        # If not, install the AVD bootloader agent.
        $agentBootloaderTest = Invoke-DscResource @msiDscMainSplat -Method "Test" -Property $msiInstallAgentBootloaderDsc
        if ($agentBootloaderTest.InDesiredState -eq $false) {
            if ($PSCmdlet.ShouldProcess("$($avdAgentFilesToGet[1].DisplayName)", "Install")) {
                Invoke-DscResource @msiDscMainSplat -Method "Set" -Property $msiInstallAgentBootloaderDsc
            }
        }

        # Remove the temporary directory.
        Remove-Item -Path $tmpDirPath -Force -Recurse -ErrorAction "SilentlyContinue"
    }

    # Run the 'Invoke-AvdAgentInstall' function.
    Invoke-AvdAgentInstall -RegistrationToken "{{REG_TOKEN_REPLACE}}" -Verbose
}

# Convert the script block into a string and replace "{{REG_TOKEN_REPLACE}}" inside of it with the value provided by '-RegistrationToken'.
$agentInstallScriptBlockString = $agentInstallScriptBlock.ToString()
$agentInstallScriptBlockString = $agentInstallScriptBlockString.Replace("{{REG_TOKEN_REPLACE}}", $RegistrationToken)

# Create a new script block with the updated data.
$updatedAgentInstallScriptBlock = [System.Management.Automation.ScriptBlock]::Create($agentInstallScriptBlockString)

# Run the script block with PowerShell 7.
pwsh.exe -NoProfile -Command $updatedAgentInstallScriptBlock