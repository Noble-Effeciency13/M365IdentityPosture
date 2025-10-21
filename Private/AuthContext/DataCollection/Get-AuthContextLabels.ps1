function Get-AuthContextLabels {
	<#
	.SYNOPSIS
		Retrieves and expands sensitivity labels extracting embedded Authentication Context metadata.

	.DESCRIPTION
		Uses Get-Label (with detailed expansion) to populate LabelActions for parsing; detects protectionlevel JSON and
		SiteAndGroupSettings fallbacks to obtain context Id/Name pairs.

	.PARAMETER Raw
		When set returns both raw label objects and parsed output (tuple style) instead of parsed only.

	.OUTPUTS
		Parsed PSCustomObject rows or raw+parsed arrays when -Raw specified.

	.EXAMPLE
		$labels = Get-AuthContextLabels
	#>
	[CmdletBinding()] param([switch]$Raw)
	$labels = @()
	try {
		$params = (Get-Command Get-Label).Parameters
		if ($params.ContainsKey('IncludeDetailedProperties')) { $labels = Get-Label -IncludeDetailedProperties } else { $labels = Get-Label }
	}
	catch { Write-Warning "Initial Get-Label failed: $($_.Exception.Message)" }
	if (-not $labels) { return @() }
	# Always expand each label to ensure LabelActions populated
	$expanded = foreach ($labelBrief in $labels) { try { Get-Label -Identity $labelBrief.Guid -ErrorAction Stop } catch { $labelBrief } }
	if ($expanded) { $labels = $expanded }
	$output = foreach ($label in $labels) {
		$contextId = $null; $contextName = $null
		# Parse LabelActions strings for embedded Authentication Context protectionlevel data
		if ($label.LabelActions) {
			foreach ($labelAction in $label.LabelActions) {
				if (-not $labelAction) { continue }
				$labelActionObject = $null
				try { $labelActionObject = $labelAction | ConvertFrom-Json -ErrorAction Stop } catch { continue }
				if ($labelActionObject.Type -ne 'protectsite' -and $labelActionObject.Type -ne 'protectgroup') { continue }
				if ($labelActionObject.Settings) {
					foreach ($setting in $labelActionObject.Settings) {
						if ($setting.Key -eq 'protectionlevel' -and $setting.Value) {
							try {
								$protectionInfo = $setting.Value | ConvertFrom-Json -ErrorAction Stop
								if ($protectionInfo.Id) { $contextId = $protectionInfo.Id }
								if ($protectionInfo.DisplayName) { $contextName = $protectionInfo.DisplayName }
							}
							catch { }
						}
					}
				}
			}
		}
		# Fallback to SiteAndGroupSettings property if not found in LabelActions
		if (-not $contextName -and $label.SiteAndGroupSettings) {
			$siteGroupSettings = $label.SiteAndGroupSettings
			$contextName = $siteGroupSettings.AuthenticationContextName
			if (-not $contextName -and $siteGroupSettings.PSObject.Properties['AuthenticationContext']) { $contextName = $siteGroupSettings.AuthenticationContext }
			if (-not $contextName -and $siteGroupSettings.PSObject.Properties['AuthContextName']) { $contextName = $siteGroupSettings.AuthContextName }
		}
		if ($contextName) {
			[pscustomobject]@{
				LabelName       = $label.DisplayName
				LabelId         = $label.Guid
				AuthContextId   = $contextId
				AuthContextName = $contextName
				Scope           = 'SitesAndGroups'
			}
		}
	}
	$parsed = $output | Sort-Object AuthContextName, LabelName
	if ($Raw) { return , @($labels), @($parsed) } else { return $parsed }
}
