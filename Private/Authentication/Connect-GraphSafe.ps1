function Connect-GraphSafe {
	<#
	.SYNOPSIS
		Establishes or reuses a Microsoft Graph delegated session with required scopes.

	.DESCRIPTION
		Validates existing context scopes; if any required scopes missing re-authenticates with union. Avoids redundant
		auth prompts. Sets $script:graphConnected when successful.

	.PARAMETER QuietMode
		Reduce console messaging.

	.OUTPUTS
		Boolean indicating success.

	.EXAMPLE
		Connect-GraphSafe -QuietMode
	#>
	[CmdletBinding()] param(
		[switch]$QuietMode,
		[string]$TenantId,
		[string]$ClientId,
		[string[]]$AdditionalScopes
	)
	$script:graphConnected = $false
	$script:graphDisconnectOnExit = $false
	$baseScopes = @(
		'Directory.Read.All', 'Group.Read.All', 'Policy.Read.All', 'Policy.Read.ConditionalAccess',
		'AuthenticationContext.Read.All', 'RoleManagement.Read.Directory', 'RoleManagementPolicy.Read.Directory',
		'RoleManagementPolicy.Read.AzureADGroup', 'PrivilegedAccess.Read.AzureADGroup'
	)
	$neededScopes = ($baseScopes + ($AdditionalScopes | Where-Object { $_ })) | Select-Object -Unique
	try {
		$context = Get-MgContext -ErrorAction SilentlyContinue
		if ($context -and $context.Account -and (-not $TenantId -or $context.TenantId -eq $TenantId)) {
			# Validate that all needed scopes are present; if not, force re-auth with the union
			$currentScopes = @()
			try { if ($context.Scopes) { $currentScopes = $context.Scopes } } catch { Write-Verbose 'Unable to read scopes from existing Graph context.' }
			$missingScopes = @(); foreach ($scope in $neededScopes) { if ($currentScopes -notcontains $scope) { $missingScopes += $scope } }
			if ($missingScopes.Count -gt 0) {
				if (-not $QuietMode) { Write-Host ('[Graph] Re-auth required to add missing scopes: {0}' -f ($missingScopes -join ',')) -ForegroundColor Yellow }
				Connect-MgGraph -Scopes ($currentScopes + $missingScopes | Select-Object -Unique) -ErrorAction Stop | Out-Null
				$script:graphDisconnectOnExit = $true
				$context = Get-MgContext -ErrorAction SilentlyContinue
				$currentScopes = $context.Scopes
				$missingScopes = @(); foreach ($scope in $neededScopes) { if ($currentScopes -notcontains $scope) { $missingScopes += $scope } }
				if ($missingScopes.Count -gt 0 -and -not $QuietMode) { Write-Warning ('Still missing scopes after re-auth: {0}' -f ($missingScopes -join ',')) }
			}
			else {
				if (-not $QuietMode) { Write-Host "   ✓ Using existing Microsoft Graph connection (Account: $($context.Account))" -ForegroundColor DarkGreen }
			}
			# Assume existing context sufficient; do not force re-auth here
			$script:graphConnected = $true
			$script:graphDisconnectOnExit = $true
			return $true
		}
		if (-not $QuietMode) { Write-Host '   → Connecting to Microsoft Graph...' -ForegroundColor DarkCyan }
		$connectParams = @{ Scopes = $neededScopes; ErrorAction = 'Stop' }
		if ($TenantId) { $connectParams['TenantId'] = $TenantId }
		if ($ClientId) { $connectParams['ClientId'] = $ClientId }
		Connect-MgGraph @connectParams | Out-Null
		$script:graphDisconnectOnExit = $true
		$script:graphConnected = $true
		if (-not $QuietMode) { Write-Host '   ✓ Microsoft Graph connection established' -ForegroundColor DarkGreen }
		return $true
	}
	catch {
		if (-not $QuietMode) { Write-Host '   ✗ Microsoft Graph connection failed' -ForegroundColor Red }
		Write-Warning "Graph connection failed: $($_.Exception.Message)"
		$script:graphConnected = $false
		return $false
	}
}
