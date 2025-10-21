function Import-SharePointModule {
	<#
	.SYNOPSIS
		Imports the Microsoft.Online.SharePoint.PowerShell module if available.

	.DESCRIPTION
		Checks for the availability of the SharePoint Online PowerShell module and imports it
		if present. Uses Windows PowerShell compatibility mode for the module import.

	.PARAMETER QuietMode
		Suppresses error output when the import fails.

	.OUTPUTS
		Boolean indicating whether the module was successfully imported.

	.EXAMPLE
		if (Import-SharePointModule) { Write-Host "SharePoint module loaded" }
	#>
	[CmdletBinding()] param([switch]$QuietMode)
	$spoModuleAvailable = (Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell)
	if (-not $spoModuleAvailable) { return $false }
	try {
		Invoke-ModuleOperation -Name Microsoft.Online.SharePoint.PowerShell -Operation Import -WinPSCompat | Out-Null
		return $true
	}
	catch {
		if (-not $QuietMode) { Write-Host ('   ✗ SPO module import failed: {0}' -f $_.Exception.Message) -ForegroundColor Red }
		return $false
	}
}
