function Convert-PIMPoliciesToAuthContext {
	<#
	.SYNOPSIS
		Converts raw PIM policy objects (directory / group / managed group / Azure) into normalized auth context records.

	.DESCRIPTION
		Parses policy rule JSON to extract authenticationContextIds and authenticationContextClassReferences (including
		singular and include* variants) plus fallback token capture. Adds resolved context names, role definition id,
		scope metadata and optional original group name. Displays progress (Id 6) unless -NoProgress.

	.PARAMETER Policies
		Collection of raw roleManagementPolicy objects (with .rules) potentially annotated with RoleDefinitionId / GroupName.

	.PARAMETER AuthContexts
		Collection of authentication contexts used for name resolution (optional but improves output readability).

	.OUTPUTS
		PSCustomObject: PolicyId, ScopeId, ScopeType, AuthContextIds, AuthContextClassRefs, AuthContextNames,
		MatchedContextNamesText, RawContainsAuthContext, RoleDefinitionId, GroupName.
	.NOTES
		Intentionally skips policies with no detected auth context tokens to reduce noise.
	.EXAMPLE
		$normalized = Convert-PIMPoliciesToAuthContext -Policies $raw -AuthContexts $authContexts
  	#>
	param([Parameter(Mandatory)][object[]]$Policies, [object[]]$AuthContexts)
	$contextNames = @(); if ($AuthContexts) { $contextNames = $AuthContexts.DisplayName }
	$output = @()
	$totalPolicies = ($Policies | Measure-Object).Count
	$policyIndex = 0
	foreach ($policy in $Policies) {
		$policyIndex++
		$policyPercent = if ($totalPolicies -gt 0) { [int](($policyIndex / $totalPolicies) * 100) } else { 100 }
		if (-not $NoProgress) {
			$scopeText = if ($policy.scopeType) { $policy.scopeType } else { 'UnknownScope' }
			$roleHint = $null
			if ($policy.PSObject.Properties.Name -contains 'RoleDefinitionId' -and $policy.RoleDefinitionId) { $roleHint = $policy.RoleDefinitionId }
			$statusLine = "Policy $policyIndex/$totalPolicies ($scopeText)" + $(if ($roleHint) { " :: RoleDef=$roleHint" } else { '' })
			Write-Progress -Id 6 -Activity 'PIM Policies' -Status $statusLine -PercentComplete $policyPercent
		}
		$rules = $policy.rules; if (-not $rules) { continue }
		$ruleJson = $rules | ConvertTo-Json -Depth 15 -Compress
		# Extract Authentication Context IDs and Class References from JSON arrays
		$contextIds = @()
		$contextClasses = @()
		$authContextIdMatches = [regex]::Matches($ruleJson, '"authenticationContextIds"\s*:\s*\[(.*?)\]')
		foreach ($matchItem in $authContextIdMatches) {
			$inner = $matchItem.Groups[1].Value
			$innerIds = [regex]::Matches($inner, '"([0-9a-fA-F-]{36}|c\d+)"') | ForEach-Object { $_.Groups[1].Value }
			if ($innerIds) { $contextIds += $innerIds }
		}
		$authContextClassMatches = [regex]::Matches($ruleJson, '"authenticationContextClassReferences"\s*:\s*\[(.*?)\]')
		foreach ($matchItem in $authContextClassMatches) {
			$inner = $matchItem.Groups[1].Value
			$innerClasses = [regex]::Matches($inner, '"([^"\\]+)"') | ForEach-Object { $_.Groups[1].Value }
			if ($innerClasses) { $contextClasses += $innerClasses }
		}
		# Handle singular variants that sometimes appear in rules
		if ($ruleJson -match '"authenticationContextId"\s*:\s*"([0-9a-fA-F-]{36}|c\d+)"') { $contextIds += $Matches[1] }
		if ($ruleJson -match '"authenticationContextClassReference"\s*:\s*"([^"\\]+)"') { $contextClasses += $Matches[1] }
		# Handle legacy include* property variants
		$includeClassReferences = [regex]::Matches($ruleJson, '"includeAuthenticationContextClassReferences"\s*:\s*\[(.*?)\]')
		foreach ($matchItem in $includeClassReferences) { $contextClasses += ([regex]::Matches($matchItem.Groups[1].Value, '"([^"\\]+)"') | ForEach-Object { $_.Groups[1].Value }) }
		$includeIds = [regex]::Matches($ruleJson, '"includeAuthenticationContextIds"\s*:\s*\[(.*?)\]')
		foreach ($matchItem in $includeIds) { $contextIds += ([regex]::Matches($matchItem.Groups[1].Value, '"([0-9a-fA-F-]{36}|c\d+)"') | ForEach-Object { $_.Groups[1].Value }) }
		# Fallback: if rule mentions authenticationContextRule or claimValue, collect cN tokens as class refs
		if (($contextIds.Count -eq 0 -and $contextClasses.Count -eq 0) -and ($ruleJson -match 'authenticationContextRule' -or $ruleJson -match 'claimValue')) {
			$classTokens = [regex]::Matches($ruleJson, '"c\d+"') | ForEach-Object { $_.Value.Trim('"') }
			if ($classTokens) { $contextClasses += $classTokens }
		}
		# Only include policies when we have explicit Authentication Context arrays to avoid false positives
		if ($contextIds.Count -eq 0 -and $contextClasses.Count -eq 0) { continue }
		$matchedNames = @()
		if ($contextNames) { $matchedNames = @($contextNames | Where-Object { $_ -and ($contextIds -contains $_ -or $ruleJson -match [regex]::Escape($_)) }) }
		$roleDefinitionId = $null
		if ($ruleJson -match '"roleDefinitionId"\s*:\s*"([0-9a-zA-Z-]+)"') { $roleDefinitionId = $Matches[1] }
		if (-not $roleDefinitionId -and $policy.PSObject.Properties.Name -contains 'RoleDefinitionId' -and $policy.RoleDefinitionId) { $roleDefinitionId = $policy.RoleDefinitionId }
		# Map Authentication Context names from both IDs and class references (cN patterns)
		$contextIdToName = @()
		if ($AuthContexts) {
			$allReferences = @(); if ($contextIds) { $allReferences += $contextIds }; if ($contextClasses) { $allReferences += $contextClasses }
			foreach ($reference in ($allReferences | Sort-Object -Unique)) {
				$foundContext = $AuthContexts | Where-Object { $_.Id -eq $reference }
				if ($foundContext) { $contextIdToName += $foundContext.DisplayName } else { $contextIdToName += $reference }
			}
		}
		# Preserve original GroupName if present on raw policy object (needed for PIM for Groups HTML output)
		$groupNameOriginal = $null
		if ($policy.PSObject.Properties.Name -contains 'GroupName') { $groupNameOriginal = $policy.GroupName }
		$output += [pscustomobject]@{
			PolicyId                = $policy.id
			ScopeId                 = $policy.scopeId
			ScopeType               = $policy.scopeType
			AuthContextIds          = ($contextIds | Sort-Object -Unique) -join ','
			AuthContextClassRefs    = ($contextClasses | Sort-Object -Unique) -join ','
			AuthContextNames        = ($contextIdToName | Sort-Object -Unique) -join ','
			MatchedContextNamesText = ($matchedNames -join ',')
			RawContainsAuthContext  = $true
			RoleDefinitionId        = $roleDefinitionId
			GroupName               = $groupNameOriginal
		}
	}
	if (-not $NoProgress) { Write-Progress -Id 6 -Activity 'PIM Policies' -Completed -Status "Processed $totalPolicies policy object(s)" }
	return $output
}
