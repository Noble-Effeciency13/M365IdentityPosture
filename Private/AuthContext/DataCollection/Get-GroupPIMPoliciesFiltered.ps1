function Get-GroupPIMPoliciesFiltered {
	<#
	.SYNOPSIS
		Retrieves PIM policies for specified group object IDs (Group scope) including rule expansion.

	.DESCRIPTION
		For each group ID, fetches policy assignments to capture RoleDefinitionId then retrieves each policy (v1.0, falls back
		to beta on certain errors) with rules expanded. Aggregates all policies and converts to Authentication Context objects.

	.PARAMETER GroupIds
		Array of Azure AD group object IDs (GUIDs) to inspect.

	.PARAMETER AuthContexts
		Collection of authentication contexts for mapping in conversion stage.

	.OUTPUTS
		PSCustomObject (see Convert-PIMPoliciesToAuthContext schema).

	.NOTES
		Optimized to avoid unreliable direct filters on v1.0 by enumerating assignments first.
		
	.EXAMPLE
		$grpPim = Get-GroupPIMPoliciesFiltered -GroupIds $managedGroups -AuthContexts $authContexts
	#>
	[CmdletBinding()] param([object[]]$GroupIds, [object[]]$AuthContexts)
	$all = @()
	if ($GroupIds -and ($GroupIds | Measure-Object).Count -gt 0) {
		foreach ($groupId in $GroupIds) {
			# Assignments-first approach to avoid v1.0 filter issues
			$assignments = @()
			$aUri = "https://graph.microsoft.com/v1.0/policies/roleManagementPolicyAssignments?`$filter=scopeId%20eq%20'$groupId'%20and%20scopeType%20eq%20'Group'"
			try {
				$ar = Invoke-MgGraphRequest -Uri $aUri -Method GET -ErrorAction Stop
				if ($ar.value) { $assignments = $ar.value }
			}
			catch {
				if ($_.Exception.Message -match 'BadRequest' -or $_.Exception.Message -match '403') {
					$aUri = $aUri -replace '/v1.0/', '/beta/'
					try { $ar = Invoke-MgGraphRequest -Uri $aUri -Method GET -ErrorAction Stop; if ($ar.value) { $assignments = $ar.value } } catch { }
				}
			}
			if (-not $assignments -or $assignments.Count -eq 0) { continue }
			foreach ($assignmentItem in $assignments) {
				if (-not $assignmentItem.policyId) { continue }
				$policyUri = "https://graph.microsoft.com/v1.0/policies/roleManagementPolicies/$($assignmentItem.policyId)?`$expand=rules"
				$policyFull = $null
				try { $policyFull = Invoke-MgGraphRequest -Uri $policyUri -Method GET -ErrorAction Stop } catch {
					if ($_.Exception.Message -match 'BadRequest' -or $_.Exception.Message -match '403') {
						$policyUri = $policyUri -replace '/v1.0/', '/beta/'
						try { $policyFull = Invoke-MgGraphRequest -Uri $policyUri -Method GET -ErrorAction Stop } catch { $policyFull = $null }
					}
				}
				if ($policyFull) {
					if ($assignmentItem.roleDefinitionId) { $policyFull | Add-Member -NotePropertyName RoleDefinitionId -NotePropertyValue $assignmentItem.roleDefinitionId -Force }
					$all += $policyFull
				}
			}
		}
	}
	if (-not $all) { return @() }
	return (Convert-PIMPoliciesToAuthContext -Policies $all -AuthContexts $AuthContexts)
}
