function Invoke-GraphPhase {
	<#
	.SYNOPSIS
		Connects to Microsoft Graph and discovers Authentication Context class references.

	.DESCRIPTION
		Ensures required Microsoft.Graph modules are imported, establishes delegated Graph connection with needed scopes, queries beta endpoint for authenticationContextClassReferences.

	.PARAMETER QuietMode
		Reduce console output.

	.OUTPUTS
		Array of objects (Id, DisplayName, Description, IsAvailable).

	.EXAMPLE
		$authContexts = Invoke-GraphPhase

	.EXAMPLE
		$authContexts = Invoke-GraphPhase -QuietMode
	#>
	[CmdletBinding()] param([switch]$QuietMode)
	Import-GraphModules -QuietMode:$QuietMode | Out-Null
	if (-not $QuietMode) { Write-Host '[Graph] Connecting...' -ForegroundColor Green }
	if (-not (Connect-GraphSafe -QuietMode:$QuietMode)) { throw 'Graph connection failed.' }
	$authContexts = Get-AuthenticationContexts -QuietMode:$QuietMode
	return $authContexts
}
