function Get-SPOSitesRaw {
	<#
	.SYNOPSIS
		Retrieves all SharePoint Online sites from the tenant.

	.DESCRIPTION
		Uses Get-SPOSite to enumerate all SharePoint Online sites excluding personal sites.
		Provides console feedback unless quiet mode is enabled.

	.PARAMETER QuietMode
		Suppresses console output when specified.

	.OUTPUTS
		Array of SharePoint Online site objects.

	.EXAMPLE
		$sites = Get-SPOSitesRaw
	#>
	[CmdletBinding()] param([switch]$QuietMode)
	if (-not $QuietMode) { Write-Host '   → Enumerating SharePoint sites...' -ForegroundColor DarkCyan }
	$sites = @()
	try { $sites = Get-SPOSite -Limit All -IncludePersonalSite:$false -ErrorAction Stop }
	catch { throw }
	return $sites
}