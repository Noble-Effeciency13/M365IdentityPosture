function Get-PIMPoliciesWithAuthContext {
	<#
	.SYNOPSIS
		Retrieves all Entra ID (Directory) PIM role management policies and detects Authentication Context usage.

	.DESCRIPTION
		Calls v1.0 policies/roleManagementPolicies with rules expansion, then scans rule JSON for explicit references
		to authenticationContext (Ids or class references). Provides a summarized object including matched context names
		and whether raw JSON contained any auth context tokens (for defensive detection).

	.PARAMETER AuthContexts
		Collection of authentication context objects used to map IDs / class references to names.

	.OUTPUTS
		PSCustomObject: PolicyId, ScopeId, ScopeType, MatchedContexts, RawContainsAuthContext, RulesJson.

	.NOTES
		Returns only policies with evidence of Authentication Context data. Truncates RulesJson to 900 chars for brevity.

	.EXAMPLE
    $pim = Get-PIMPoliciesWithAuthContext -AuthContexts $authContexts
  	#>
	[CmdletBinding()] param([object[]]$AuthContexts)
	$policies = @()
	$endpoint = 'https://graph.microsoft.com/v1.0/policies/roleManagementPolicies?$expand=rules'
	try {
		while ($endpoint) {
			$resp = Invoke-MgGraphRequest -Method GET -Uri $endpoint -ErrorAction Stop
			if ($resp.value) { $policies += $resp.value }
			$endpoint = $resp.'@odata.nextLink'
		}
	}
	catch { Write-Warning "PIM policy retrieval failed: $($_.Exception.Message)" }
	if (-not $policies) { return @() }
	$ContextNames = @(); if ($AuthContexts) { $ContextNames = $AuthContexts.DisplayName }
	$out = foreach ($pol in $policies) {
		$rules = $pol.rules
		if (-not $rules) { continue }
		$ruleJson = $rules | ConvertTo-Json -Depth 15 -Compress
		$matched = @($ContextNames | Where-Object { $ruleJson -match [regex]::Escape($_) })
		if ($matched.Count -gt 0 -or $ruleJson -match 'authenticationContext') {
			[pscustomobject]@{
				PolicyId               = $pol.id
				ScopeId                = $pol.scopeId
				ScopeType              = $pol.scopeType
				MatchedContexts        = ($matched -join ',')
				RawContainsAuthContext = ($ruleJson -match 'authenticationContext')
				RulesJson              = $ruleJson.Substring(0, [Math]::Min(900, $ruleJson.Length))
			}
		}
	}
	return $out | Sort-Object PolicyId
}
