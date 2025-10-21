function Invoke-Preflight {
	<#
	.SYNOPSIS
		Validates the availability of required PowerShell modules for the script execution.

	.DESCRIPTION
		Checks for both core required modules (Graph, Exchange, SharePoint) and optional modules (Azure)
		based on script parameters. Reports missing modules and optionally attempts installation.

	.PARAMETER QuietMode
		Suppresses console output for module status checks.

	.OUTPUTS
		Boolean result indicating readiness status.

	.EXAMPLE
		Invoke-Preflight -QuietMode:$false
	#>
	[CmdletBinding()] param([switch]$QuietMode)
	# Core required modules (always needed)
	$coreRequired = 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Groups', 'ExchangeOnlineManagement', 'Microsoft.Online.SharePoint.PowerShell'
  
	# Optional modules (conditionally required)
	$optional = @()
	if (-not $ExcludeAzure) { $optional += 'Az.Accounts' }
  
	$missing = @()
	$present = @()
	$optionalPresent = @()
  
	foreach ($name in $coreRequired) {
		if (Get-Module -ListAvailable -Name $name) { $present += $name } else { $missing += $name }
	}
  
	foreach ($name in $optional) {
		if (Get-Module -ListAvailable -Name $name) { $optionalPresent += $name }
		elseif ($name -eq 'Az.Accounts' -and -not $ExcludeAzure) { $missing += $name }
	}
  
	if (-not $QuietMode) {
		Write-Host '[Preflight] Module availability:' -ForegroundColor DarkCyan
		Write-Host ' Core Modules:' -ForegroundColor DarkGray  
		foreach ($presentModule in $present) { Write-Host (' - {0}' -f $presentModule) }
		if ($optionalPresent.Count -gt 0) {
			Write-Host ' Optional Modules:' -ForegroundColor DarkGray  
			foreach ($presentOptionalModule in $optionalPresent) { Write-Host (' - {0}' -f $presentOptionalModule) }
		}
		if ($missing) { 
			Write-Host 'Missing Required:' -ForegroundColor Yellow
			foreach ($missingModule in $missing) { Write-Host (' - {0}' -f $missingModule) -ForegroundColor Yellow } 
		}
	}
	if ($missing) { throw ('Missing required modules: {0}' -f ($missing -join ', ')) }
	return , @($present + $optionalPresent)
}
