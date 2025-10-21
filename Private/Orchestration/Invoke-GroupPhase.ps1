function Invoke-GroupPhase {
	<#
	.SYNOPSIS
		Enumerates Microsoft 365 Groups / Teams and enriches with primary sensitivity label metadata.

	.DESCRIPTION
		Retrieves unified groups via Graph (paged), then issues beta calls to obtain assignedLabels (first label only) for correlation with Authentication Context enforcing labels.

	.PARAMETER QuietMode
		Reduce console output.

	.OUTPUTS
		Updates global PurviewAuthenticationData.UnifiedGroupsCollection collection and returns it.
	#>
	[CmdletBinding()] param([switch]$QuietMode)
	$unifiedGroupsData = $script:PurviewAuthenticationData
	if (-not $QuietMode) { Write-Host '[Groups] Enumerating M365 groups via Microsoft Graph...' -ForegroundColor Green }
	$unifiedGroupsCollection = @()
	try {
		$groupsApiUri = "https://graph.microsoft.com/v1.0/groups?`$filter=groupTypes/any(c:c eq 'Unified')&`$select=id,displayName,mail,mailNickname,createdDateTime,visibility&`$top=999"
		while ($groupsApiUri) {
			$graphResponse = Invoke-MgGraphRequest -Uri $groupsApiUri -Method GET -ErrorAction Stop
			if ($graphResponse.value) { $unifiedGroupsCollection += $graphResponse.value }
			$groupsApiUri = $graphResponse.'@odata.nextLink'
			if (-not $QuietMode) { Write-Progress -Id 14 -Activity 'Groups (Graph)' -Status ('Retrieved {0}...' -f $unifiedGroupsCollection.Count) -PercentComplete 50 }
		}
		if (-not $QuietMode) { Write-Progress -Id 14 -Activity 'Groups (Graph)' -Completed }
	}
	catch {
		$unifiedGroupsData.ProcessingErrors += $_.Exception.Message
		if (-not $QuietMode) { Write-Host ('   ✗ Group enumeration failed: {0}' -f $_.Exception.Message) -ForegroundColor Red }
	}
	# Optional enrichment: sensitivity label metadata via beta assignedLabels
	$enrichedGroupsWithLabels = @()
	if ($unifiedGroupsCollection.Count -gt 0) {
		foreach ($currentGroup in $unifiedGroupsCollection) {
			$sensitivityLabelName = $null; $sensitivityLabelId = $null
			try {
				$betaLabelsResponse = Invoke-MgGraphRequest -Uri ("https://graph.microsoft.com/beta/groups/{0}?`$select=assignedLabels" -f $currentGroup.id) -Method GET -ErrorAction Stop
				if ($betaLabelsResponse.assignedLabels -and $betaLabelsResponse.assignedLabels.Count -gt 0) {
					$assignedLabelData = $betaLabelsResponse.assignedLabels[0]
					if ($assignedLabelData.displayName) { $sensitivityLabelName = $assignedLabelData.displayName }
					if ($assignedLabelData.labelId) { $sensitivityLabelId = $assignedLabelData.labelId }
				}
			}
			catch { }
			$enrichedGroupsWithLabels += [pscustomobject]@{
				DisplayName               = $currentGroup.displayName
				PrimarySmtpAddress        = $currentGroup.mail
				ExternalDirectoryObjectId = $currentGroup.id
				SensitivityLabel          = $sensitivityLabelName
				SensitivityLabelId        = $sensitivityLabelId
				SharePointSiteUrl         = $null
			}
		}
	}
	$unifiedGroupsData.UnifiedGroupsCollection = $enrichedGroupsWithLabels
	if (-not $QuietMode) { Write-Host ('   ✓ Retrieved {0} groups (Graph)' -f ($unifiedGroupsData.UnifiedGroupsCollection.Count)) -ForegroundColor DarkGreen }
	if (-not $QuietMode) { Write-Host '[Groups] Phase complete' -ForegroundColor DarkGray }
	return $unifiedGroupsData
}
