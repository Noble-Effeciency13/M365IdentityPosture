function Get-AllGroupsMinimal {
	<#
	.SYNOPSIS
		Returns minimal id/displayName list of all groups in the tenant.

	.DESCRIPTION
		Paginates through /groups (v1.0) selecting only id & displayName for lightweight mapping / name resolution purposes.

	.OUTPUTS
		PSCustomObject with properties id, displayName.

	.NOTES
		Uses 999 page size; may require Directory.Read.All or Group.Read.All depending on directory settings.

	.EXAMPLE
		$allGroups = Get-AllGroupsMinimal
	#>
	[CmdletBinding()] param()
	$allGroupsCollection = @()
	$groupsApiUri = "https://graph.microsoft.com/v1.0/groups?`$select=id,displayName&`$top=999"
	try {
		while ($groupsApiUri) {
			$groupsResponse = Invoke-MgGraphRequest -Uri $groupsApiUri -Method GET -ErrorAction Stop
			if ($groupsResponse.value) { $allGroupsCollection += $groupsResponse.value }
			$groupsApiUri = $groupsResponse.'@odata.nextLink'
		}
	}
	catch { Write-Warning ('Failed to enumerate groups: {0}' -f $_.Exception.Message) }
	return $allGroupsCollection | ForEach-Object { [pscustomobject]@{ id = $_.id; displayName = $_.displayName } }
}
