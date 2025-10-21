function Resolve-AndProjectPIMPolicies {
	<#
	.SYNOPSIS
		Resolves role names for PIM policies and projects directory and group policy exports.

	.DESCRIPTION
		Encapsulates the role name resolution loop and export projection previously inline in the core orchestrator.
		Maintains identical progress messages and object schema. Returns two arrays corresponding to directory and group exports.

	.PARAMETER DirectoryPolicies
		PIM policies scoped to Entra directory roles (already converted via Convert-PIMPoliciesToAuthContext).

	.PARAMETER GroupPolicies
		PIM policies scoped to managed groups (already converted via Convert-PIMPoliciesToAuthContext).

    .PARAMETER AllPolicies
    	Union of directory + group policies used to determine unique RoleDefinitionId values.

    .PARAMETER GroupsById
    	Hashtable of GroupObjectId -> DisplayName for resolving group names in projection when absent.

    .PARAMETER NoProgress
    	Switch to suppress Write-Progress output identical to upstream behavior.

    .OUTPUTS
    	Two arrays: [0] directory export objects, [1] group export objects.
    #>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)] [object[]] $DirectoryPolicies,
		[Parameter(Mandatory)] [object[]] $GroupPolicies,
		[Parameter(Mandatory)] [object[]] $AllPolicies,
		[Parameter()] [hashtable] $GroupsById,
		[switch] $NoProgress
	)

	$dirExport = @(); $grpExport = @()

	if (-not $AllPolicies -or ($AllPolicies | Measure-Object).Count -eq 0) { return , @($dirExport, $grpExport) }

	$uniqueRoleIds = $AllPolicies | Where-Object { $_.RoleDefinitionId } | Select-Object -Expand RoleDefinitionId -Unique
	if (-not $NoProgress) { Write-Progress -Id 6 -Activity 'PIM Policies' -Status ('Role mapping for {0} unique role ids' -f ($uniqueRoleIds.Count)) -PercentComplete 85 }
	$roleTotal = ($uniqueRoleIds | Measure-Object).Count
	$roleIndex = 0
	$roleMap = @{}
	foreach ($roleDefIdVal in $uniqueRoleIds) {
		$roleIndex++
		$pct = if ($roleTotal -gt 0) { [int](($roleIndex / $roleTotal) * 100) } else { 100 }
		$friendlyDisplay = if ($roleMap.ContainsKey($roleDefIdVal)) { $roleMap[$roleDefIdVal] } else { $roleDefIdVal }
		if (-not $NoProgress) { Write-Progress -Id 8 -Activity 'PIM Role Mapping' -Status ('Resolving role {0}/{1}: {2}' -f $roleIndex, $roleTotal, $friendlyDisplay) -PercentComplete $pct }
		if ($roleDefIdVal -notmatch '^[0-9a-fA-F-]{8}-') {
			$lower = $roleDefIdVal.ToLower()
			if ($lower -eq 'member') { $roleMap[$roleDefIdVal] = 'Group Member' }
			elseif ($lower -eq 'owner') { $roleMap[$roleDefIdVal] = 'Group Owner' }
			continue
		}
		try {
			$roleDefinitionResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions/$roleDefIdVal?`$select=id,displayName" -ErrorAction Stop
			if ($roleDefinitionResponse.id) { $roleMap[$roleDefinitionResponse.id] = $roleDefinitionResponse.displayName; continue }
		}
		catch {}
		try {
			$roleTemplateResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directoryRoleTemplates/$roleDefIdVal?`$select=id,displayName" -ErrorAction Stop
			if ($roleTemplateResponse.id) { $roleMap[$roleTemplateResponse.id] = $roleTemplateResponse.displayName; continue }
		}
		catch {}
		try {
			$roleTemplateFilter = [uri]::EscapeDataString("roleTemplateId eq '$roleDefIdVal'")
			$directoryRolesResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directoryRoles?`$filter=$roleTemplateFilter&`$select=id,displayName" -ErrorAction Stop
			if ($directoryRolesResponse.value -and $directoryRolesResponse.value.Count -gt 0) { $roleMap[$roleDefIdVal] = $directoryRolesResponse.value[0].displayName; continue }
		}
		catch {}
		try {
			$resolvedRoleName = Resolve-DirectoryRoleName -RoleId $roleDefIdVal
			if ($resolvedRoleName) { $roleMap[$roleDefIdVal] = $resolvedRoleName; continue }
		}
		catch {}
	}
	if (-not $NoProgress) { Write-Progress -Id 8 -Activity 'PIM Role Mapping' -Completed -Status 'Role name resolution complete' }

	$projectPim = {
		param($items)
		$out = @()
		foreach ($item in $items) {
			# Collect potential auth context id properties (robust to upstream variations)
			$acCandidates = @()
			foreach ($propName in 'AuthContextClassRefs', 'AuthContextIds', 'AuthContextClassReferences', 'AuthContextClassReferenceIds', 'RequiredAuthContextIds', 'AuthContextId') {
				if ($item.PSObject.Properties.Name -contains $propName) {
					$val = $item.$propName
					if ($val) { $acCandidates += $val }
				}
			}
			$acIdOut = if ($acCandidates.Count -gt 0) { ($acCandidates -join ',') } else { $null }

			$isGroup = ($item.PSObject.Properties.Name -contains 'ScopeType' -and $item.ScopeType -eq 'Group')
			$grpName = $null
			if ($isGroup) {
				if ($item.PSObject.Properties.Name -contains 'GroupName' -and $item.GroupName) { $grpName = $item.GroupName }
				elseif ($item.PSObject.Properties.Name -contains 'ScopeId') {
					$groupScopeId = $item.ScopeId
					if ($groupScopeId -and $groupScopeId -match '^[0-9a-fA-F-]{36}$' -and $GroupsById) { $grpName = $GroupsById[$groupScopeId] }
				}
			}

			# Determine role identifiers list (some upstream conversions concatenate multiple role ids / names)
			$rawRole = $null
			if ($item.PSObject.Properties.Name -contains 'RoleDefinitionId') { $rawRole = $item.RoleDefinitionId }
			elseif ($item.PSObject.Properties.Name -contains 'RoleDefinitionIds') { $rawRole = $item.RoleDefinitionIds }
			elseif ($item.PSObject.Properties.Name -contains 'RoleId') { $rawRole = $item.RoleId }
			$roleTokens = @()
			if ($rawRole) {
				if ($rawRole -is [System.Collections.IEnumerable] -and $rawRole -isnot [string]) { $roleTokens = @($rawRole | ForEach-Object { $_ }) }
				else { $roleTokens = @($rawRole -split '[,\s]+' | Where-Object { $_ }) }
			}
			if ($roleTokens.Count -eq 0) { $roleTokens = @($rawRole) }

			foreach ($roleDefValue in $roleTokens) {
				if (-not $roleDefValue) { continue }
				$roleName = $null
				$lower = $roleDefValue.ToLower()
				if ($lower -eq 'owner') { $roleName = 'Owner' }
				elseif ($lower -eq 'member') { $roleName = 'Member' }
				elseif ($roleMap.ContainsKey($roleDefValue)) { $roleName = $roleMap[$roleDefValue] }
				else { $roleName = $roleDefValue }

				$row = if ($isGroup) {
					[pscustomobject]@{
						'Group Name'        = $grpName
						'Role Name'         = $roleName
						'Auth Context Id'   = $acIdOut
						'Auth Context Name' = $item.AuthContextNames
					}
				}
				else {
					[pscustomobject]@{
						'Role Name'         = $roleName
						'Auth Context Id'   = $acIdOut
						'Auth Context Name' = $item.AuthContextNames
					}
				}
				$out += $row
			}
		}
		$out
	}

	$dirExport = & $projectPim $DirectoryPolicies
	$grpExport = & $projectPim $GroupPolicies

	return , @($dirExport, $grpExport)
}
