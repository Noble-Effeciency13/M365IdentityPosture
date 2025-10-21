function Get-AuthenticationContexts {
	<#
	.SYNOPSIS
		Retrieves authenticationContextClassReferences via beta Graph endpoint.

	.DESCRIPTION
		Mirrors original discovery logic including console messages and sorting.

	.PARAMETER QuietMode
		Suppress output.

	.OUTPUTS
		Array of objects (Id, DisplayName, Description, IsAvailable).

	.EXAMPLE
		$authContexts = Get-AuthenticationContexts

	.EXAMPLE
		$authContexts = Get-AuthenticationContexts -QuietMode
	#>
    [CmdletBinding()] param([switch]$QuietMode)
    $authContexts = @()
    try {
        if (-not $QuietMode) { Write-Host '   → Discovering Authentication Contexts...' -ForegroundColor DarkCyan }
        $ContextResp = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/authenticationContextClassReferences'
        $authContexts = @($ContextResp.value) | ForEach-Object {
            [pscustomobject]@{ Id = $_.id; DisplayName = $_.displayName; Description = $_.description; IsAvailable = $_.isAvailable }
        } | Sort-Object { [int]($_.Id -replace '[^0-9]', '') }
        if (-not $QuietMode) { Write-Host ("   ✓ Found {0} Authentication Context(s)" -f ($authContexts.Count)) -ForegroundColor DarkGreen }
    }
    catch {
        if (-not $QuietMode) { Write-Host '   ⚠ Authentication Context discovery failed' -ForegroundColor DarkYellow }
    }
    return $authContexts
}
