function Filter-SitesForAuthContext {
	<#
	.SYNOPSIS
		Filters SharePoint sites that have authentication context requirements.

	.DESCRIPTION
		Returns only sites that have conditional access policies set to 'AuthenticationContext'
		or have an authentication context name assigned.

	.PARAMETER Sites
		Collection of SharePoint sites to filter.

	.OUTPUTS
		Filtered collection of sites with authentication context requirements.

	.EXAMPLE
		$authContextSites = Filter-SitesForAuthContext -Sites $allSites
	#>
	[CmdletBinding()] param([Parameter(Mandatory)]$Sites)
	return $Sites | Where-Object { $_.ConditionalAccessPolicy -eq 'AuthenticationContext' -or $_.AuthenticationContextName }
}
