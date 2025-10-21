function Invoke-GracefulCleanup {
	<#
	.SYNOPSIS
		Performs cleanup of all service connections and restores preference variables.

	.DESCRIPTION
		Disconnects from Exchange Online, SharePoint Online, Azure, and Microsoft Graph services
		while suppressing output and restoring PowerShell preference variables to their original state.

	.PARAMETER QuietMode
		Suppresses status output during cleanup operations.

	.OUTPUTS
		None. Performs side effects of disconnecting services.

	.EXAMPLE
		Invoke-GracefulCleanup -QuietMode:$false
	#>
	param([switch]$QuietMode)
	
	# Store original preference variables
	$prevWarn = $WarningPreference
	$prevInfo = $InformationPreference
	$prevProg = $ProgressPreference
	$prevVerb = $VerbosePreference
	$prevDbg = $DebugPreference
	
	# Suppress all output during cleanup
	$WarningPreference = 'SilentlyContinue'
	$InformationPreference = 'SilentlyContinue'
	$ProgressPreference = 'SilentlyContinue'
	$VerbosePreference = 'SilentlyContinue'
	$DebugPreference = 'SilentlyContinue'
	
	try {
		# Disconnect Exchange Online
		try { 
			if (Get-Module ExchangeOnlineManagement -ListAvailable) { 
				Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null 
			} 
		} 
		catch { 
			# Silent failure
		}
		
		# Disconnect SharePoint Online
		try { 
			if (Get-Command Disconnect-SPOService -ErrorAction SilentlyContinue) { 
				Disconnect-SPOService -ErrorAction SilentlyContinue | Out-Null 
			} 
		} 
		catch { 
			# Silent failure
		}
		
		# Disconnect Azure
		try { 
			if (Get-Module Az.Accounts -ErrorAction SilentlyContinue) { 
				Disconnect-AzAccount -Scope Process -ErrorAction SilentlyContinue | Out-Null 
			} 
		} 
		catch { 
			# Silent failure
		}
		
		# Disconnect Microsoft Graph
		try { 
			if ($graphConnected) { 
				Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null 
			} 
		} 
		catch { 
			# Silent failure
		}
	}
	finally {
		# Restore original preference variables
		$WarningPreference = $prevWarn
		$InformationPreference = $prevInfo
		$ProgressPreference = $prevProg
		$VerbosePreference = $prevVerb
		$DebugPreference = $prevDbg
	}
	
	if (-not $QuietMode) { 
		Write-Host '[Cleanup] All service connections closed' -ForegroundColor DarkGray 
	}
}
