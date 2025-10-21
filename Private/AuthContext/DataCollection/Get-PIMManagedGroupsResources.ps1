function Get-PIMManagedGroupsResources {
	<#
	.SYNOPSIS
		Returns ONLY groups truly onboarded in PIM for Groups (excludes merely capable groups).

	.DESCRIPTION
		Queries the Microsoft Graph beta endpoint to retrieve groups that are actively onboarded
		in Privileged Identity Management (PIM) for Groups. This endpoint returns only groups that
		are actually managed by PIM, not just groups that are capable of being managed.

	.OUTPUTS
		Array of group objects with properties: id, displayName, externalId (group objectId), type.
		Returns an empty array if no PIM-managed groups are found.

	.EXAMPLE
		$pimGroups = Get-PIMManagedGroupsResources

	.NOTES
		Endpoint: GET https://graph.microsoft.com/beta/privilegedAccess/aadGroups/resources
		Requires scope PrivilegedAccess.Read.AzureADGroup.
		Uses externalId (group objectId) when present, falls back to id.
	#>
	[CmdletBinding()] param()
	$result = @()
	$uri = "https://graph.microsoft.com/beta/privilegedAccess/aadGroups/resources?`$select=id,displayName,externalId,type&`$top=50"
	try {
		while ($uri) {
			$r = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
			if ($r.value) { $result += $r.value }
			$uri = $r.'@odata.nextLink'
		}
	}
	catch {
		if (-not $Quiet) { Write-Host ('      ⚠ Managed group resource call failed: {0}' -f $_.Exception.Message) -ForegroundColor DarkYellow }
	}
	if (-not $result) { return @() }
	return $result | ForEach-Object {
		[pscustomobject]@{
			ResourceId    = $_.id
			GroupObjectId = $(if ($_.externalId) { $_.externalId } else { $_.id })
			DisplayName   = $_.displayName
			Type          = $_.type
		}
	}
}
