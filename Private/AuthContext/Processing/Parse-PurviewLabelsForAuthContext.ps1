function Parse-PurviewLabelsForAuthContext {
	<#
	.SYNOPSIS
		Extracts Authentication Context mappings from expanded labels.

	.DESCRIPTION
		Processes label objects to identify those with authentication context
        settings in their actions or site/group settings. Returns a simplified
        object with relevant authentication context information.

	.PARAMETER Labels
		Expanded (or raw) label objects.

	.OUTPUTS
		Array of parsed label context objects.
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]$Labels
	)
	$parsed = foreach ($currentLabel in $Labels) {
		$authenticationContextName = $null; $authenticationContextId = $null
		if ($currentLabel.LabelActions) {
			foreach ($labelAction in $currentLabel.LabelActions) {
				if (-not $labelAction) { continue }
				try { $labelActionObject = $labelAction | ConvertFrom-Json -ErrorAction Stop } catch { continue }
				if ($labelActionObject.Type -notin @('protectsite', 'protectgroup')) { continue }
				if ($labelActionObject.Settings) {
					foreach ($labelSetting in $labelActionObject.Settings) {
						if ($labelSetting.Key -eq 'protectionlevel' -and $labelSetting.Value) {
							try {
								$protectionLevelData = $labelSetting.Value | ConvertFrom-Json -ErrorAction Stop
								if ($protectionLevelData.Id) { $authenticationContextId = $protectionLevelData.Id }
								if ($protectionLevelData.DisplayName) { $authenticationContextName = $protectionLevelData.DisplayName }
							}
							catch {}
						}
					}
				}
			}
		}
		if (-not $authenticationContextName -and $currentLabel.SiteAndGroupSettings) {
			$siteAndGroupSettings = $currentLabel.SiteAndGroupSettings
			$authenticationContextName = $siteAndGroupSettings.AuthenticationContextName
			if (-not $authenticationContextName -and $siteAndGroupSettings.PSObject.Properties['AuthenticationContext']) { $authenticationContextName = $siteAndGroupSettings.AuthenticationContext }
			if (-not $authenticationContextName -and $siteAndGroupSettings.PSObject.Properties['AuthContextName']) { $authenticationContextName = $siteAndGroupSettings.AuthContextName }
		}
		if ($authenticationContextName) {
			[pscustomobject]@{
				LabelName       = $currentLabel.DisplayName
				LabelId         = $currentLabel.Guid
				AuthContextId   = $authenticationContextId
				AuthContextName = $authenticationContextName
				Scope           = 'SitesAndGroups'
			}
		}
	}
	return $parsed
}
