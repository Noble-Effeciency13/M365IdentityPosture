function Get-ConditionalAccessPoliciesWithAuthContext {
	<#
	.SYNOPSIS
		Retrieves all Conditional Access policies and extracts any Authentication Context references.

	.DESCRIPTION
		Enumerates Conditional Access policies via Microsoft Graph (beta) handling pagination. For each policy
		it parses both structured properties (conditions.applications.* / conditions.authenticationContext.* / grantControls)
		and, as a fallback, performs targeted JSON regex extraction to capture legacy / nested representations of
		authenticationContextIds or authenticationContextClassReferences (including include* variants). Returns only
		policies containing at least one reference, with summarized grant & session control indicators.

	.PARAMETER AuthContexts
		Collection of authentication context objects (Id, DisplayName) used to map IDs / class references to names.

	.OUTPUTS
		PSCustomObject with: PolicyName, PolicyId, State, AuthContextIds, AuthContextClassRefs, AuthContextNames,
		GrantControls, SessionControls.

	.NOTES
		Uses Graph beta endpoint (identity/conditionalAccess/policies). Progress appears under Id 4 unless -NoProgress.
		Falls back to regex parsing to accommodate tenants exposing legacy schema shapes.
		
  	.EXAMPLE
    	$ca = Get-ConditionalAccessPoliciesWithAuthContext -AuthContexts $authContexts
    	Retrieves all CA policies that reference any authentication context.
  	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][object[]]$AuthContexts
	)
	$conditionalAccessPolicies = @()
	try {
		$conditionalAccessApiUri = 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies'
		$policyPageIndex = 0
		while ($conditionalAccessApiUri) {
			$conditionalAccessResponse = Invoke-MgGraphRequest -Method GET -Uri $conditionalAccessApiUri -ErrorAction Stop
			if ($conditionalAccessResponse.value) {
				foreach ($policyObject in $conditionalAccessResponse.value) {
					$conditionalAccessPolicies += $policyObject
					$policyPageIndex++
					$processingPercent = if ($policyPageIndex -lt 1000) { [math]::Min(100, [int](($policyPageIndex / 10) * 10)) } else { 100 }
					$currentPolicyName = $policyObject.displayName
					if (-not $NoProgress) { Write-Progress -Id 4 -Activity 'Conditional Access Policies' -Status "Retrieved: $currentPolicyName (count=$policyPageIndex)" -PercentComplete $processingPercent }
				}
			}
			$conditionalAccessApiUri = $conditionalAccessResponse.'@odata.nextLink'
		}
		if (-not $NoProgress) { Write-Progress -Id 4 -Activity 'Conditional Access Policies' -Completed -Status 'Done' }
	}
	catch { Write-Warning "Failed to retrieve conditional access policies: $($_.Exception.Message)" }
	if (-not $conditionalAccessPolicies) { return @() }
	$authenticationContextById = @{}
	foreach ($authenticationContext in $AuthContexts) { $authenticationContextById[$authenticationContext.Id] = $authenticationContext.DisplayName }
	$conditionalAccessPoliciesWithAuthContext = foreach ($currentPolicy in $conditionalAccessPolicies) {
		$authenticationContextIds = @(); $authenticationContextClassReferences = @()
		if ($currentPolicy.conditions -and $currentPolicy.conditions.applications -and $currentPolicy.conditions.applications.authenticationContextClassReferences) {
			$authenticationContextClassReferences += $currentPolicy.conditions.applications.authenticationContextClassReferences
		}
		if ($currentPolicy.conditions -and $currentPolicy.conditions.authenticationContext -and $currentPolicy.conditions.authenticationContext.authenticationContextIds) {
			$authenticationContextIds += $currentPolicy.conditions.authenticationContext.authenticationContextIds
		}
		# Some tenants expose Authentication Context arrays within grant controls instead of conditions
		if ($currentPolicy.grantControls) {
			$policyGrantControls = $currentPolicy.grantControls
			foreach ($authContextProperty in 'authenticationContextClassReferences', 'authenticationContextIds') {
				if ($policyGrantControls.PSObject.Properties.Name -contains $authContextProperty -and $policyGrantControls.$authContextProperty) {
					if ($authContextProperty -eq 'authenticationContextClassReferences') { $authenticationContextClassReferences += $policyGrantControls.$authContextProperty }
					else { $authenticationContextIds += $policyGrantControls.$authContextProperty }
				}
			}
		}
		if ($authenticationContextIds.Count -eq 0 -and $authenticationContextClassReferences.Count -eq 0) {
			try {
				$policyRawJson = $currentPolicy | ConvertTo-Json -Depth 20 -Compress
				if ($policyRawJson -match 'authenticationContext') {
					# Extract Authentication Context IDs and Class References from JSON even when deeply nested
					$contextIdMatches = [regex]::Matches($policyRawJson, '"authenticationContextIds"\s*:\s*\[(.*?)\]')
					foreach ($contextIdMatchItem in $contextIdMatches) { $authenticationContextIds += ([regex]::Matches($contextIdMatchItem.Groups[1].Value, '"([0-9a-fA-F-]{32,36})"') | ForEach-Object { $_.Groups[1].Value }) }
					$contextClassRefMatches = [regex]::Matches($policyRawJson, '"authenticationContextClassReferences"\s*:\s*\[(.*?)\]')
					foreach ($contextClassRefMatchItem in $contextClassRefMatches) { $authenticationContextClassReferences += ([regex]::Matches($contextClassRefMatchItem.Groups[1].Value, '"([^"\\]+)"') | ForEach-Object { $_.Groups[1].Value }) }
					# Handle singular variants
					if ($policyRawJson -match '"authenticationContextIds"\s*:\s*"([0-9a-fA-F-]{32,36})"') { $authenticationContextIds += $Matches[1] }
					if ($policyRawJson -match '"authenticationContextClassReferences"\s*:\s*"([^"]+)"') { $authenticationContextClassReferences += $Matches[1] }
					# Legacy include* property variants  
					$includeClassReferencesMatches = [regex]::Matches($policyRawJson, '"includeAuthenticationContextClassReferences"\s*:\s*\[(.*?)\]')
					foreach ($includeClassRefMatchItem in $includeClassReferencesMatches) { $authenticationContextClassReferences += ([regex]::Matches($includeClassRefMatchItem.Groups[1].Value, '"([^"\\]+)"') | ForEach-Object { $_.Groups[1].Value }) }
					if ($policyRawJson -match '"includeAuthenticationContextClassReferences"\s*:\s*"([^"]+)"') { $authenticationContextClassReferences += $Matches[1] }
					$includeIdMatches = [regex]::Matches($policyRawJson, '"includeAuthenticationContextIds"\s*:\s*\[(.*?)\]')
					foreach ($includeIdMatchItem in $includeIdMatches) { $authenticationContextIds += ([regex]::Matches($includeIdMatchItem.Groups[1].Value, '"([0-9a-fA-F-]{32,36})"') | ForEach-Object { $_.Groups[1].Value }) }
					if ($policyRawJson -match '"includeAuthenticationContextIds"\s*:\s*"([0-9a-fA-F-]{32,36})"') { $authenticationContextIds += $Matches[1] }
					# Generic pattern matching for class references like "c1", "c2" etc.
					if ($authenticationContextClassReferences.Count -eq 0) {
						$genericClassReferencesMatches = [regex]::Matches($policyRawJson, '"c[0-9]+"') | ForEach-Object { $_.Value.Trim('"') }
						if ($genericClassReferencesMatches) { $authenticationContextClassReferences += $genericClassReferencesMatches }
					}
				}
			}
			catch { }
		}
		$authenticationContextIds = $authenticationContextIds | Sort-Object -Unique
		$authenticationContextClassReferences = $authenticationContextClassReferences | Sort-Object -Unique
    
		if ($authenticationContextIds.Count -gt 0 -or $authenticationContextClassReferences.Count -gt 0) {
			$mappedAuthenticationContextNames = @()
			foreach ($authenticationContextId in $authenticationContextIds) { if ($authenticationContextById.ContainsKey($authenticationContextId)) { $mappedAuthenticationContextNames += $authenticationContextById[$authenticationContextId] } }
			foreach ($authenticationContextClassReference in $authenticationContextClassReferences) { if ($authenticationContextById.ContainsKey($authenticationContextClassReference)) { $mappedAuthenticationContextNames += $authenticationContextById[$authenticationContextClassReference] } }
			$mappedAuthenticationContextNames = $mappedAuthenticationContextNames | Sort-Object -Unique
			$grantControlsSummary = $null
			if ($currentPolicy.grantControls) {
				$currentPolicyGrantControls = $currentPolicy.grantControls
				if ($currentPolicyGrantControls.builtInControls) { $grantControlsSummary = ($currentPolicyGrantControls.builtInControls -join '+') }
				elseif ($currentPolicyGrantControls.customAuthenticationFactors) { $grantControlsSummary = 'CustomAuthFactors' }
				elseif ($currentPolicyGrantControls.termsOfUse) { $grantControlsSummary = 'TOU' }
			}
			$sessionControlsSummary = $null
			if ($currentPolicy.sessionControls) {
				$sessionControlsParts = @(); $currentPolicySessionControls = $currentPolicy.sessionControls
				if ($currentPolicySessionControls.applicationEnforcedRestrictions) { $sessionControlsParts += 'AER' }
				if ($currentPolicySessionControls.persistentBrowser) { $sessionControlsParts += 'PersistentBrowser' }
				if ($sessionControlsParts) { $sessionControlsSummary = ($sessionControlsParts -join '+') }
			}
			[pscustomobject]@{
				PolicyName           = $currentPolicy.displayName
				PolicyId             = $currentPolicy.id
				State                = $currentPolicy.state
				AuthContextIds       = ($authenticationContextIds -join ',')
				AuthContextClassRefs = ($authenticationContextClassReferences -join ',')
				AuthContextNames     = ($mappedAuthenticationContextNames -join ',')
				GrantControls        = $grantControlsSummary
				SessionControls      = $sessionControlsSummary
			}
		}
	}
	return $conditionalAccessPoliciesWithAuthContext | Sort-Object PolicyName
}
