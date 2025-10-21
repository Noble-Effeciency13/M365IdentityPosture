function Get-LabelledUnifiedGroups {
	<#
	.SYNOPSIS
		Returns Unified (M365) Groups whose sensitivity label is linked to an Authentication Context.

	.DESCRIPTION
		Calls Get-UnifiedGroup (Exchange Online) and filters results where SensitivityLabelId is present in the
		provided HashSet of label IDs associated with authentication contexts. Emits a simplified object suitable
		for downstream HTML reporting.

	.PARAMETER LabelIdsWithContext
		HashSet[string] of SensitivityLabel GUIDs that carry AuthenticationContext information.

	.OUTPUTS
		PSCustomObject: GroupName, GroupId, PrimarySmtpAddress, SensitivityLabel, SensitivityLabelId, SharePointSiteUrl.

	.NOTES
		Requires ExchangeOnlineManagement module & sufficient rights (e.g., Exchange View-Only Org role / Global Reader).

	.EXAMPLE
    $groups = Get-LabelledUnifiedGroups -LabelIdsWithContext $labelSet
  	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][System.Collections.Generic.HashSet[string]]$LabelIdsWithContext
	)
	$groups = @()
	try {
		# EXO: Get-UnifiedGroup exposes SensitivityLabel / SensitivityLabelId (GUID). Use -ResultSize Unlimited.
		$groups = Get-UnifiedGroup -ResultSize Unlimited -ErrorAction Stop | Select-Object DisplayName, PrimarySmtpAddress, ExternalDirectoryObjectId, SensitivityLabel, SensitivityLabelId, SharePointSiteUrl
	}
	catch { Write-Warning "Unified group retrieval failed: $($_.Exception.Message)"; return @() }
	$matched = $groups | Where-Object { $_.SensitivityLabelId -and $LabelIdsWithContext.Contains([string]$_.SensitivityLabelId) }
	return $matched | ForEach-Object {
		[pscustomobject]@{
			GroupName          = $_.DisplayName
			GroupId            = $_.ExternalDirectoryObjectId
			PrimarySmtpAddress = $_.PrimarySmtpAddress
			SensitivityLabel   = $_.SensitivityLabel
			SensitivityLabelId = $_.SensitivityLabelId
			SharePointSiteUrl  = $_.SharePointSiteUrl
		}
	}
}
