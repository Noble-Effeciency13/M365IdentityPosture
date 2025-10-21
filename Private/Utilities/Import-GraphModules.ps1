function Import-GraphModules {
	<#
	.SYNOPSIS
		Imports required Microsoft Graph modules for Auth Context discovery.

	.DESCRIPTION
		Preserves original module import logic from Invoke-GraphPhase.

	.PARAMETER QuietMode
		Suppress output.

	.OUTPUTS
		Boolean indicating success.

	.EXAMPLE
		if (Import-GraphModules) { Write-Host 'Graph modules loaded' }

	.EXAMPLE
		Import-GraphModules -QuietMode
	#>
	[CmdletBinding()] param([switch]$QuietMode)
	if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) { throw 'Microsoft.Graph modules not installed.' }
	Invoke-ModuleOperation -Name Microsoft.Graph.Authentication -Operation Import | Out-Null
	Invoke-ModuleOperation -Name Microsoft.Graph.Groups -Operation Import | Out-Null
	return $true
}
