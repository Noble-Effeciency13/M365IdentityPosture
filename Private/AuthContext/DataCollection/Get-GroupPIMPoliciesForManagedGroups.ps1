function Get-GroupPIMPoliciesForManagedGroups {
	<#
	.SYNOPSIS
		Fetches roleManagementPolicies (with rules) and assignments only for already discovered managed PIM groups.

	.DESCRIPTION
		Retrieves Privileged Identity Management (PIM) role management policies and their associated rules
		for specific groups that have been identified as PIM-managed. This function focuses on groups that
		are already known to have PIM policies rather than discovering all groups.

	.PARAMETER GroupIds
		Array of group objectIds for which to retrieve PIM policies.

	.PARAMETER AuthContexts
		Array of authentication context objects to cross-reference with PIM policies.

	.PARAMETER NameMap
		Hashtable mapping groupId -> displayName for display purposes (optional).

	.OUTPUTS
		Array of PIM policy objects with associated rules and assignments for the specified groups.

	.EXAMPLE
		$policies = Get-GroupPIMPoliciesForManagedGroups -GroupIds @("group1-id", "group2-id") -AuthContexts $authContexts
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][string[]]$GroupIds,
		[object[]]$AuthContexts,
		[hashtable]$NameMap
	)
	if (-not $GroupIds -or $GroupIds.Count -eq 0) { return @() }
	$policies = @()
	for ($i = 0; $i -lt $GroupIds.Count; $i++) {
		$gid = $GroupIds[$i]
		$groupDisplayName = if ($NameMap -and $NameMap.ContainsKey($gid)) { $NameMap[$gid] } else { $gid }
		if (-not $NoProgress) {
			$pct = [int](( ([double]$i / [double]$GroupIds.Count) * 100 ))
			Write-Progress -Id 66 -Activity 'PIM Policies (Managed Groups)' -Status ('Group {0}/{1}' -f ($i + 1), $GroupIds.Count) -PercentComplete $pct
		}
		try {
			$assignmentMap = @{}
			$assignmentUri = "https://graph.microsoft.com/v1.0/policies/roleManagementPolicyAssignments?`$filter=scopeId%20eq%20'$gid'%20and%20scopeType%20eq%20'Group'&`$select=policyId,roleDefinitionId"
			try {
				$assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentUri -Method GET -ErrorAction Stop
				if ($assignmentResponse.value) { foreach ($assignment in $assignmentResponse.value) { if ($assignment.policyId -and $assignment.roleDefinitionId) { $assignmentMap[$assignment.policyId] = $assignment.roleDefinitionId } } }
			}
			catch {}
			$policyUri = "https://graph.microsoft.com/v1.0/policies/roleManagementPolicies?`$filter=scopeId%20eq%20'$gid'%20and%20scopeType%20eq%20'Group'&`$expand=rules"
			$policyResponse = Invoke-MgGraphRequest -Uri $policyUri -Method GET -ErrorAction Stop
			if ($policyResponse.value) {
				foreach ($policy in $policyResponse.value) {
					$policy | Add-Member -NotePropertyName GroupName -NotePropertyValue $groupDisplayName -Force
					if ($assignmentMap.ContainsKey($policy.id)) { $policy | Add-Member -NotePropertyName RoleDefinitionId -NotePropertyValue $assignmentMap[$policy.id] -Force }
					$policies += $policy
				}
			}
		}
		catch { }
	}
	if (-not $NoProgress) { Write-Progress -Id 66 -Activity 'PIM Policies (Managed Groups)' -Completed -Status ('Processed {0}' -f $GroupIds.Count) }
	if (-not $policies) { return @() }
	return (Convert-PIMPoliciesToAuthContext -Policies $policies -AuthContexts $AuthContexts)
}
