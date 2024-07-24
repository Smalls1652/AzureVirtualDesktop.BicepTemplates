
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

# Template content for the FSLogix config profile.
$fslogixSettingsTemplateContent = @"
{
  "description": "{{ PROFILE_DESCRIPTION }}",
  "name": "{{ PROFILE_NAME }}",
  "platforms": "windows10",
  "roleScopeTagIds": [ "0" ],
  "technologies": "mdm",
  "settings": [
    {
      "id": "0",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcodfcenabled_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcodfcenabled"
      }
    },
    {
      "id": "1",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeofficeactivation_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeofficeactivation"
      }
    },
    {
      "id": "2",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeonedrive_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeonedrive"
      }
    },
    {
      "id": "3",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeonenote_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeonenote"
      }
    },
    {
      "id": "4",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeonenoteuwp_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeonenoteuwp"
      }
    },
    {
      "id": "5",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeoutlook_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeoutlook"
      }
    },
    {
      "id": "6",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeoutlookpersonalization_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeoutlookpersonalization"
      }
    },
    {
      "id": "7",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludesharepoint_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludesharepoint"
      }
    },
    {
      "id": "8",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeskype_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeskype"
      }
    },
    {
      "id": "9",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeteams_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcincludeteams"
      }
    },
    {
      "id": "10",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcisdynamicvhd_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcisdynamicvhd"
      }
    },
    {
      "id": "11",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcmirrorlocalosttovhd_1",
          "children": [
            {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
              "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcmirrorlocalosttovhd_odfcmirrorlocalosttovhd",
              "choiceSettingValue": {
                "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcmirrorlocalosttovhd_odfcmirrorlocalosttovhd_2",
                "children": [ ]
              }
            }
          ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcmirrorlocalosttovhd"
      }
    },
    {
      "id": "12",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcvhdlocations_1",
          "children": [
            {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
              "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcvhdlocations_odfcvhdlocations",
              "simpleSettingValue": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                "value": "{{ PROFILE_FSLOGIX_FILESHARE }}"
              }
            }
          ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcvhdlocations"
      }
    },
    {
      "id": "13",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcvolumetypevhdorvhdx_1",
          "children": [
            {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
              "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcvolumetypevhdorvhdx_odfcvolumetypevhdorvhdx",
              "choiceSettingValue": {
                "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcvolumetypevhdorvhdx_odfcvolumetypevhdorvhdx_vhdx",
                "children": [ ]
              }
            }
          ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~odfc_odfcvolumetypevhdorvhdx"
      }
    },
    {
      "id": "14",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesdeletelocalprofilewhenvhdshouldapply_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesdeletelocalprofilewhenvhdshouldapply"
      }
    },
    {
      "id": "15",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesenabled_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesenabled"
      }
    },
    {
      "id": "16",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesinstallappxpackages_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesinstallappxpackages"
      }
    },
    {
      "id": "17",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesisdynamicvhd_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesisdynamicvhd"
      }
    },
    {
      "id": "18",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profileskeeplocaldirectoryafterlogoff_0",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profileskeeplocaldirectoryafterlogoff"
      }
    },
    {
      "id": "19",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesroamidentity_0",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesroamidentity"
      }
    },
    {
      "id": "20",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesvhdlocations_1",
          "children": [
            {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
              "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesvhdlocations_profilesvhdlocations",
              "simpleSettingValue": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                "value": "{{ PROFILE_FSLOGIX_FILESHARE }}"
              }
            }
          ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix~profiles_profilesvhdlocations"
      }
    },
    {
      "id": "21",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "choiceSettingValue": {
          "value": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix_vhdcompactdisk_1",
          "children": [ ]
        },
        "settingDefinitionId": "device_vendor_msft_policy_config_fslogixv1~policy~fslogix_vhdcompactdisk"
      }
    }
  ],
  "templateReference": {
    "templateFamily": "none",
    "templateId": ""
  }
}
"@

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

# Replace the placeholders with the provided values in the template.
$fslogixSettingsContent = $fslogixSettingsTemplateContent.Replace("{{ PROFILE_NAME }}", $ProfileName).Replace("{{ PROFILE_DESCRIPTION }}", $ProfileDescription).Replace("{{ PROFILE_FSLOGIX_FILESHARE }}", [System.Text.Json.JsonEncodedText]::Encode($FSLogixFileSharePath).Value)

# Convert the template content to the required object type.
$newFslogixProfile = $null
try {
	$newFslogixProfile = [Microsoft.Graph.Beta.PowerShell.Models.MicrosoftGraphDeviceManagementConfigurationPolicy]::FromJsonString($fslogixSettingsContent)
}
catch [System.Exception] {
	$exceptionData = $PSItem

	$PSCmdlet.ThrowTerminatingError($exceptionData)
}

# Create the Intune configuration profile.
$createdProfile = $null
if ($PSCmdlet.ShouldProcess($ProfileName, "Create Intune config profile")) {
	$createdProfile = New-MgBetaDeviceManagementConfigurationPolicy -BodyParameter $newFslogixProfile -ErrorAction "Stop"

	Write-Output -InputObject $createdProfile
}
else {
	Write-Output -InputObject $newFslogixProfile
}
