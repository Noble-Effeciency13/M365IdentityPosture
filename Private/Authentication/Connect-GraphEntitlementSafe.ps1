function Connect-GraphEntitlementSafe {
	<#!
	.SYNOPSIS
		Connects to Microsoft Graph with read-only Entitlement Management scopes for Access Package reporting.

	.DESCRIPTION
		Ensures the Graph context includes the minimum read permissions needed to enumerate access packages,
		assignment policies, resources, approvals, and custom extensions. Reuses an existing context when the
		required scopes are already granted to avoid extra prompts.

	.PARAMETER QuietMode
		Suppress console output.

	.OUTPUTS
		Boolean indicating success.
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
		'EntitlementManagement.Read.All',
		'Directory.Read.All',
		'Group.Read.All',
		'User.Read.All',
		'Policy.Read.All',
		'Application.Read.All'  # for app role/resource enrichment (service principals/apps)
	)
	$neededScopes = ($baseScopes + ($AdditionalScopes | Where-Object { $_ })) | Select-Object -Unique

	try {
		$context = Get-MgContext -ErrorAction SilentlyContinue
		if ($context -and $context.Account -and (-not $TenantId -or $context.TenantId -eq $TenantId)) {
			$currentScopes = @()
			try { if ($context.Scopes) { $currentScopes = $context.Scopes } } catch { Write-Verbose 'Unable to read scopes from existing Graph context.' }
			$missingScopes = @(); foreach ($scope in $neededScopes) { if ($currentScopes -notcontains $scope) { $missingScopes += $scope } }
			if ($missingScopes.Count -gt 0) {
				if (-not $QuietMode) { Write-Host ('[Graph] Re-auth required to add missing scopes: {0}' -f ($missingScopes -join ',')) -ForegroundColor Yellow }
				Connect-MgGraph -Scopes ($currentScopes + $missingScopes | Select-Object -Unique) -ErrorAction Stop | Out-Null
				$script:graphDisconnectOnExit = $true
				$context = Get-MgContext -ErrorAction SilentlyContinue
				$currentScopes = @(); try { if ($context.Scopes) { $currentScopes = $context.Scopes } } catch { Write-Verbose 'Unable to read scopes after re-auth.' }
				$missingScopes = @(); foreach ($scope in $neededScopes) { if ($currentScopes -notcontains $scope) { $missingScopes += $scope } }
				if ($missingScopes.Count -gt 0) {
					Write-ModuleLog -Message ('Microsoft Graph still missing scopes after re-auth: {0}' -f ($missingScopes -join ',')) -Level Error
					throw "Graph connection missing required scopes: $($missingScopes -join ', ')"
				}
			}
			else {
				if (-not $QuietMode) { Write-Host "   ✓ Using existing Microsoft Graph connection (Account: $($context.Account))" -ForegroundColor DarkGreen }
			}
			$script:graphConnected = $true
			$script:graphDisconnectOnExit = $true
			return $true
		}

		if (-not $QuietMode) { Write-Host '   → Connecting to Microsoft Graph (Entitlement Mgmt scopes)...' -ForegroundColor DarkCyan }
		$connectParams = @{ Scopes = $neededScopes; NoWelcome = $true; ErrorAction = 'Stop' }
		if ($TenantId) { $connectParams['TenantId'] = $TenantId }
		if ($ClientId) { $connectParams['ClientId'] = $ClientId }
		Connect-MgGraph @connectParams | Out-Null
		$script:graphDisconnectOnExit = $true
		# Validate scopes
		$context = Get-MgContext -ErrorAction SilentlyContinue
		$currentScopes = @(); try { if ($context.Scopes) { $currentScopes = $context.Scopes } } catch { Write-Verbose 'Unable to read scopes after initial connect.' }
		$missingScopes = @(); foreach ($scope in $neededScopes) { if ($currentScopes -notcontains $scope) { $missingScopes += $scope } }
		if ($missingScopes.Count -gt 0) {
			Write-ModuleLog -Message ('Microsoft Graph connection established but missing scopes: {0}' -f ($missingScopes -join ',')) -Level Error
			throw "Graph connection missing required scopes: $($missingScopes -join ', ')"
		}
		$script:graphConnected = $true
		if (-not $QuietMode) { Write-Host '   ✓ Microsoft Graph connection established' -ForegroundColor DarkGreen }
		return $true
	}
	catch {
		# One retry with force refresh to trigger an auth prompt if cache/session is bad
		if (-not $QuietMode) { Write-Host '   ✗ Microsoft Graph connection failed, retrying with ForceRefresh...' -ForegroundColor Yellow }
		try {
			$connectParams = @{ Scopes = $neededScopes; NoWelcome = $true; ForceRefresh = $true; ErrorAction = 'Stop' }
			if ($TenantId) { $connectParams['TenantId'] = $TenantId }
			if ($ClientId) { $connectParams['ClientId'] = $ClientId }
			Connect-MgGraph @connectParams | Out-Null
			$script:graphDisconnectOnExit = $true
			$script:graphConnected = $true
			if (-not $QuietMode) { Write-Host '   ✓ Microsoft Graph connection established (after refresh)' -ForegroundColor DarkGreen }
			return $true
		}
		catch {
			if (-not $QuietMode) { Write-Host '   ✗ Microsoft Graph connection failed' -ForegroundColor Red }
			Write-Warning "Graph connection failed: $($_.Exception.Message)"
			$script:graphConnected = $false
			return $false
		}
	}
}
