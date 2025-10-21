function Get-ProtectedActionsWithAuthContext {
	<#
	.SYNOPSIS
		Retrieves directory (RBAC) resource actions that have an Authentication Context enforced.

	.DESCRIPTION
		Queries the beta roleManagement/directory resourceNamespaces/microsoft.directory/resourceActions endpoint
		selecting only actions where isAuthenticationContextSettable is true AND an authenticationContextId is present.
		Maps context IDs to display names when supplied and reports progress (Id 5) unless -NoProgress.

	.PARAMETER AuthContexts
		Collection of authentication context objects (Id, DisplayName) for name resolution.

	.OUTPUTS
		PSCustomObject: ActionId, ActionVerb, AuthContextId, AuthContextName.

	.NOTES
		Beta endpoint; subject to schema changes. Requires Directory.Read.All + RoleManagement.Read.All (or equivalent) scopes.

	.EXAMPLE
    $protected = Get-ProtectedActionsWithAuthContext -AuthContexts $authContexts
  	#>
	[CmdletBinding()] 
	param(
		[object[]]$AuthContexts
	)
	$endpoint = 'https://graph.microsoft.com/beta/roleManagement/directory/resourceNamespaces/microsoft.directory/resourceActions?$select=id,actionVerb,resourceScope,isAuthenticationContextSettable,authenticationContextId&$top=999'
	$actions = @()
	try {
		$resp = Invoke-MgGraphRequest -Method GET -Uri $endpoint -ErrorAction Stop
		if ($resp.value) { $actions = $resp.value }
	}
	catch { Write-Warning "Protected actions (RBAC resourceActions) retrieval failed: $($_.Exception.Message)" }
	if (-not $actions) { return @() }
	$ContextById = @{}
	foreach ($authContext in $AuthContexts) { $ContextById[$authContext.Id] = $authContext.DisplayName }
	$filtered = $actions | Where-Object { $_.isAuthenticationContextSettable -and $_.authenticationContextId }
	$total = ($filtered | Measure-Object).Count
	$idx = 0
	$out = foreach ($action in $filtered) {
		$idx++
		$pct = if ($total -gt 0) { [int](($idx / $total) * 100) } else { 100 }
		if (-not $NoProgress) { Write-Progress -Id 5 -Activity 'Protected Actions' -Status "Processing: $($action.actionVerb) ($idx/$total)" -PercentComplete $pct }
		$ContextId = $action.authenticationContextId
		[pscustomobject]@{
			ActionId        = $action.id
			ActionVerb      = $action.actionVerb
			AuthContextId   = $ContextId
			AuthContextName = $ContextById[$ContextId]
		}
	}
	if (-not $NoProgress) { Write-Progress -Id 5 -Activity 'Protected Actions' -Completed -Status 'Done' }
	return $out | Sort-Object ActionId
}
