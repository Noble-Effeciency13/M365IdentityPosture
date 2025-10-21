function Get-DirectoryPIMPoliciesFiltered {
	<#
	.SYNOPSIS
		Retrieves directory-scoped PIM policies with rule expansion and maps role assignments.

	.DESCRIPTION
		Issues filtered Graph queries (scopeId '/' & scopeType 'Directory') for roleManagementPolicies and their assignments
		to attach RoleDefinitionId, then converts to Authentication Context aware objects via Convert-PIMPoliciesToAuthContext.

	.PARAMETER AuthContexts
		Collection of authentication contexts for name mapping in downstream conversion.

	.OUTPUTS
		PSCustomObject (see Convert-PIMPoliciesToAuthContext output schema).

	.NOTES
		Progress Id 6. Requires RoleManagementPolicy.Read.Directory or equivalent (PrivilegedAccess.Read.*) scopes.

	.EXAMPLE
		$dirPim = Get-DirectoryPIMPoliciesFiltered -AuthContexts $authContexts
	#>
	[CmdletBinding()] 
	param(
		[object[]]$AuthContexts
	)
	# Escape $filter & $expand to avoid PowerShell variable interpolation
	$uri = "https://graph.microsoft.com/v1.0/policies/roleManagementPolicies?`$filter=scopeId%20eq%20'/'%20and%20scopeType%20eq%20'Directory'&`$expand=rules"
	if (-not $NoProgress) { 
		Write-Progress -Id 6 -Activity 'PIM Policies (Directory)' -Status 'Querying directory policies' -PercentComplete 5 
	}
	
	try {
		$resp = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
	}
	catch {
		if (-not $NoProgress) { 
			Write-Progress -Id 6 -Activity 'PIM Policies (Directory)' -Completed -Status 'Failed' 
		}
		Write-Warning "Directory PIM policies failed: $($_.Exception.Message)"
		return @()
	}
	
	if (-not $resp.value) { 
		return @() 
	}
	if (-not $NoProgress) { 
		Write-Progress -Id 6 -Activity 'PIM Policies (Directory)' -Status ('Processing {0} raw policies' -f $resp.value.Count) -PercentComplete 25 
	}
	
	# Fetch assignments to map policyId -> roleDefinitionId
	$assignmentUri = "https://graph.microsoft.com/v1.0/policies/roleManagementPolicyAssignments?`$filter=scopeId%20eq%20'/'%20and%20scopeType%20eq%20'Directory'"
	$assignmentMap = @{}
	
	try {
		$assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentUri -Method GET -ErrorAction Stop
		if ($assignmentResponse.value) { 
			foreach ($assignment in $assignmentResponse.value) { 
				if ($assignment.policyId -and $assignment.roleDefinitionId) { 
					$assignmentMap[$assignment.policyId] = $assignment.roleDefinitionId 
				} 
			} 
		}
	}
	catch { 
		# Silent failure for assignments - continue without role mapping
	}
	
	if (-not $NoProgress) { 
		Write-Progress -Id 6 -Activity 'PIM Policies (Directory)' -Status 'Mapping role definitions' -PercentComplete 45 
	}
	
	# Attach RoleDefinitionId to policy objects when found
	$policiesWithRoles = foreach ($policyObj in $resp.value) { 
		if ($assignmentMap.ContainsKey($policyObj.id)) { 
			$policyObj | Add-Member -NotePropertyName RoleDefinitionId -NotePropertyValue $assignmentMap[$policyObj.id] -Force 
		}
		$policyObj 
	}
	
	if (-not $NoProgress) { 
		Write-Progress -Id 6 -Activity 'PIM Policies (Directory)' -Completed -Status ('Expanded {0} directory policies' -f $policiesWithRoles.Count) 
	}
	return (Convert-PIMPoliciesToAuthContext -Policies $policiesWithRoles -AuthContexts $AuthContexts)
}
