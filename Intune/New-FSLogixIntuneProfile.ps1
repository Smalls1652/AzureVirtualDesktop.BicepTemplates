
<#PSScriptInfo
.VERSION 1.0.0

.GUID 1f001bda-dbb3-4bb5-878c-d67255a935a2

.AUTHOR Tim Small

.COMPANYNAME Smalls.Online

.COPYRIGHT 2023-2024 Smalls.Online (Timothy Small)

.TAGS

.LICENSEURI https://raw.githubusercontent.com/Smalls1652/AzureVirtualDesktop.BicepTemplates/main/LICENSE

.PROJECTURI https://github.com/Smalls1652/AzureVirtualDesktop.BicepTemplates

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

#requires -Modules @{ ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.20.0" }
#requires -Modules @{ ModuleName = "Microsoft.Graph.Beta.DeviceManagement"; ModuleVersion = "2.20.0" }

<#
.SYNOPSIS
	Create a FSLogix config profile in Intune.

.DESCRIPTION
	Create a FSLogix config profile in Intune for Azure Virtual Desktop.

.PARAMETER ProfileName
	The name for the new config profile.

.PARAMETER ProfileDescription
	The description for the new config profile.

.PARAMETER FSLogixFileSharePath
	The path to the FSLogix SMB file share.

.EXAMPLE
	New-FSLogixIntuneProfile.ps1 -ProfileName "FSLogix Settings" -ProfileDescription "FSLogix settings for Azure Virtual Desktop" -FSLogixFileSharePath "\\fslogix\profiles"

	Creates a new FSLogix config profile in Intune named "FSLogix Settings".
#>
[CmdletBinding(SupportsShouldProcess)]
param(
	[Parameter(Position = 0, Mandatory)]
	[ValidateNotNullOrWhiteSpace()]
	[string]$ProfileName,
	[Parameter(Position = 1)]
	[string]$ProfileDescription,
	[Parameter(Position = 2, Mandatory)]
	[ValidateNotNullOrWhiteSpace()]
	[string]$FSLogixFileSharePath
)

$currentGraphContext = Get-MgContext

# If no current MS Graph context is found, throw an error.
if ($null -eq $currentGraphContext) {
	$PSCmdlet.ThrowTerminatingError(
		[System.Management.Automation.ErrorRecord]::new(
			[System.Exception]::new("No Graph context found. Please run 'Connect-MgGraph' first."),
			"NoGraphContext",
			[System.Management.Automation.ErrorCategory]::ObjectNotFound,
			$null
		)
	)
}

# Check if the current MS Graph context has the required scopes.
if ("DeviceManagementConfiguration.ReadWrite.All" -notin $currentGraphContext.Scopes) {
	$PSCmdlet.ThrowTerminatingError(
		[System.Management.Automation.ErrorRecord]::new(
			[System.Exception]::new("Insufficient Scopes. Please run 'Connect-MgGraph -Scopes DeviceManagementConfiguration.ReadWrite.All' first."),
			"InsufficientScopes",
			[System.Management.Automation.ErrorCategory]::PermissionDenied,
			$null
		)
	)
}

# Load the FSLogix settings template and replace the placeholders with the provided values.
$fslogixSettingsTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath "templates/fslogix-core-settings.json"
$fslogixSettingsTemplateContent = Get-Content -Path $fslogixSettingsTemplatePath -Raw -ErrorAction "Stop"

$fslogixSettingsTemplateContent = $fslogixSettingsTemplateContent.Replace("{{ PROFILE_NAME }}", $ProfileName).Replace("{{ PROFILE_DESCRIPTION }}", $ProfileDescription).Replace("{{ PROFILE_FSLOGIX_FILESHARE }}", [System.Text.Json.JsonEncodedText]::Encode($FSLogixFileSharePath).Value)

# Convert the template content to the required object type.
$newFslogixProfile = $null
try {
	$newFslogixProfile = [Microsoft.Graph.Beta.PowerShell.Models.MicrosoftGraphDeviceManagementConfigurationPolicy]::FromJsonString($fslogixSettingsTemplateContent)
}
catch [System.Exception] {
	$exceptionData = $PSItem

	$PSCmdlet.ThrowTerminatingError($exceptionData)
}

# Create the Intune configuration profile.
$createdProfile = $null
if ($PSCmdlet.ShouldProcess($ProfileName, "Create Intune config profile")) {
	$createdProfile = New-MgBetaDeviceManagementConfigurationPolicy -BodyParameter $newFslogixProfile -ErrorAction "Stop"
}

Write-Output -InputObject $createdProfile
