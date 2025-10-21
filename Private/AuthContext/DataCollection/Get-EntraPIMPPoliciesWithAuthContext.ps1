function Get-EntraPIMPPoliciesWithAuthContext {
	<#
	.SYNOPSIS
		Restores original directory (Entra ID) PIM policy collection with Authentication Context detection.

	.DESCRIPTION
		Queries roleManagementPolicies for directory scope (scopeId '/' AND scopeType 'Directory'), expands rules, maps
		policyId -> roleDefinitionId via assignments, parses rule JSON for authenticationContextIds / authenticationContextClassReferences
		including singular / include* variants and fallback tokens. Returns only policies with evidence of Authentication Context usage.
		Role display names are NOT resolved here (done downstream) to keep retrieval lightweight.

	.PARAMETER AuthContexts
		Authentication Context objects used to map IDs / class refs to names downstream.

	.OUTPUTS
    	PSCustomObject: PolicyId, ScopeId, ScopeType, RoleDefinitionId, AuthContextIds, AuthContextClassRefs, RawContainsAuthContext, RulesJson
  	#>
	[CmdletBinding()] param([object[]]$AuthContexts)
	$policies = @()
	$uri = "https://graph.microsoft.com/v1.0/policies/roleManagementPolicies?`$filter=scopeId%20eq%20'/'%20and%20scopeType%20eq%20'Directory'&`$expand=rules"
	try { $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop } catch { Write-Warning "Directory PIM policies retrieval failed: $($_.Exception.Message)"; return @() }
	if ($resp.value) { $policies = $resp.value } else { return @() }

	# Map policyId -> roleDefinitionId via assignments
	$assignmentUri = "https://graph.microsoft.com/v1.0/policies/roleManagementPolicyAssignments?`$filter=scopeId%20eq%20'/'%20and%20scopeType%20eq%20'Directory'"
	$assignmentMap = @{}
	try {
		$assignResp = Invoke-MgGraphRequest -Method GET -Uri $assignmentUri -ErrorAction Stop
		if ($assignResp.value) {
			foreach ($a in $assignResp.value) { if ($a.policyId -and $a.roleDefinitionId) { $assignmentMap[$a.policyId] = $a.roleDefinitionId } }
		}
	}
	catch { Write-Warning "Directory PIM assignments retrieval failed: $($_.Exception.Message)" }

	$out = @()
	foreach ($pol in $policies) {
		$rules = $pol.rules; if (-not $rules) { continue }
		$ruleJson = $rules | ConvertTo-Json -Depth 12 -Compress
		# Extract authentication context arrays
		$contextIds = @(); $contextClasses = @(); $rawContains = ($ruleJson -match 'authenticationContext')
		$idMatches = [regex]::Matches($ruleJson, '"authenticationContextIds"\s*:\s*\[(.*?)\]')
		foreach ($m in $idMatches) { $inner = $m.Groups[1].Value; $contextIds += ([regex]::Matches($inner, '"([0-9a-fA-F-]{36}|c\d+)"') | ForEach-Object { $_.Groups[1].Value }) }
		$classMatches = [regex]::Matches($ruleJson, '"authenticationContextClassReferences"\s*:\s*\[(.*?)\]')
		foreach ($m in $classMatches) { $inner = $m.Groups[1].Value; $contextClasses += ([regex]::Matches($inner, '"([^"\\]+)"') | ForEach-Object { $_.Groups[1].Value }) }
		if ($ruleJson -match '"authenticationContextId"\s*:\s*"([0-9a-fA-F-]{36}|c\d+)"') { $contextIds += $Matches[1] }
		if ($ruleJson -match '"authenticationContextClassReference"\s*:\s*"([^"\\]+)"') { $contextClasses += $Matches[1] }
		$includeClassMatches = [regex]::Matches($ruleJson, '"includeAuthenticationContextClassReferences"\s*:\s*\[(.*?)\]')
		foreach ($m in $includeClassMatches) { $contextClasses += ([regex]::Matches($m.Groups[1].Value, '"([^"\\]+)"') | ForEach-Object { $_.Groups[1].Value }) }
		$includeIdMatches = [regex]::Matches($ruleJson, '"includeAuthenticationContextIds"\s*:\s*\[(.*?)\]')
		foreach ($m in $includeIdMatches) { $contextIds += ([regex]::Matches($m.Groups[1].Value, '"([0-9a-fA-F-]{36}|c\d+)"') | ForEach-Object { $_.Groups[1].Value }) }
		if (($contextIds.Count -eq 0) -and ($contextClasses.Count -eq 0) -and $rawContains) {
			# Fallback to cN tokens
			$contextClasses += ([regex]::Matches($ruleJson, '"c\d+"') | ForEach-Object { $_.Value.Trim('"') })
		}
		if ($contextIds.Count -eq 0 -and $contextClasses.Count -eq 0) { continue }
		$roleDefId = $null; if ($assignmentMap.ContainsKey($pol.id)) { $roleDefId = $assignmentMap[$pol.id] }
		$out += [pscustomobject]@{
			PolicyId               = $pol.id
			ScopeId                = $pol.scopeId
			ScopeType              = $pol.scopeType
			RoleDefinitionId       = $roleDefId
			AuthContextIds         = ($contextIds | Sort-Object -Unique) -join ','
			AuthContextClassRefs   = ($contextClasses | Sort-Object -Unique) -join ','
			RawContainsAuthContext = $rawContains
			RulesJson              = $ruleJson.Substring(0, [math]::Min(900, $ruleJson.Length))
		}
	}
	return $out | Sort-Object PolicyId
}
