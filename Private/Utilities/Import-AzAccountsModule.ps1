function Import-AzAccountsModule {
	<#
	.SYNOPSIS
		Imports the Az.Accounts PowerShell module if available.

	.DESCRIPTION
		Checks for the availability of the Az.Accounts module and imports it if present.
		Returns a boolean indicating success or failure of the import operation.

	.PARAMETER QuietMode
		Suppresses error output when the import fails.

	.OUTPUTS
		Boolean indicating whether the module was successfully imported.

	.EXAMPLE
		if (Import-AzAccountsModule) { Write-Host "Az.Accounts module loaded" }
	#>
	[CmdletBinding()] param([switch]$QuietMode)
	if (-not (Get-Module -ListAvailable -Name Az.Accounts)) { return $false }
	try { if (-not (Get-Module Az.Accounts)) { Import-Module Az.Accounts -ErrorAction Stop | Out-Null } } catch { if (-not $QuietMode) { Write-Host '[Azure] Import failed' -ForegroundColor Red }; return $false }
	return $true
}
