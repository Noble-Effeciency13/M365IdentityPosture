function Invoke-AzurePhase {
	<#
	.SYNOPSIS
		Establishes (or reuses) Az context for optional Azure Resource PIM enumeration.

	.DESCRIPTION
		Imports Az.Accounts (and leaves context loaded unless environment variable forces disconnect). Handles retry logic, tenant scoping, and silent preference adjustments.

	.PARAMETER QuietMode
		Reduce console messages.

	.PARAMETER AzureSubscriptionIds
		Specific Azure subscription IDs to process. If not specified, all accessible subscriptions are processed.

	.OUTPUTS
		PSCustomObject capturing connection state and errors.
	#>
	[CmdletBinding()] 
	param(
		[switch]$QuietMode, 
		[string[]]$AzureSubscriptionIds
	)
	
	$data = $script:AzureAuthenticationData
	$UPN = $null
	$tenantId = $null
	
	# Try to get UPN from Graph context
	try { 
		$UPN = (Get-MgContext -ErrorAction SilentlyContinue).Account 
	} 
	catch { 
		# Silent failure - continue without UPN
	}
	
	# Try to get tenant ID from Graph context first, then Az context
	try { 
		$tenantId = (Get-MgContext -ErrorAction SilentlyContinue).TenantId 
	} 
	catch { 
		# Silent failure - try Az context
	}
	
	if (-not $tenantId) { 
		try { 
			$tenantId = (Get-AzContext -ErrorAction SilentlyContinue).Tenant.Id 
		} 
		catch { 
			# Silent failure - continue without tenant ID
		} 
	}
	
	# Check if Az.Accounts module is available
	if (-not (Import-AzAccountsModule -QuietMode:$QuietMode)) {
		$data.ProcessingErrors.Add('Az.Accounts module not installed.')
		if (-not $QuietMode) { 
			Write-Host '[Azure] Skipped (module missing)' -ForegroundColor DarkYellow 
		}
		return $data
	}
	
	# Store original preference variables
	$prevWarn = $WarningPreference
	$prevInfo = $InformationPreference
	$prevProg = $ProgressPreference
	$prevVerb = $VerbosePreference
	$prevDbg = $DebugPreference
	
	# Suppress all output during Azure operations
	$WarningPreference = 'SilentlyContinue'
	$InformationPreference = 'SilentlyContinue'
	$ProgressPreference = 'SilentlyContinue'
	$VerbosePreference = 'SilentlyContinue'
	$DebugPreference = 'SilentlyContinue'
	
	try { 
		$data = Connect-AzContextSafe -DataObject $data -TenantId $tenantId -AccountUpn $UPN -QuietMode:$QuietMode 
	}
	finally { 
		# Restore original preference variables
		$WarningPreference = $prevWarn
		$InformationPreference = $prevInfo
		$ProgressPreference = $prevProg
		$VerbosePreference = $prevVerb
		$DebugPreference = $prevDbg
	}
	
	# (future enumeration placeholder retained)
	$data = Finalize-AzurePhase -DataObject $data -QuietMode:$QuietMode
	return $data
}
