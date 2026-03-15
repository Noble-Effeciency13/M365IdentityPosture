function Import-GraphEntitlementModules {
	<#!
	.SYNOPSIS
		Imports Microsoft Graph modules required for Entitlement Management (Access Packages).

	.DESCRIPTION
		Loads Microsoft.Graph.Authentication and Microsoft.Graph.Identity.Governance (plus Groups for resource resolution)
		using the module loader helper. Throws if modules are not available so the caller can present a clear error.

	.PARAMETER QuietMode
		Suppress informational output.

	.OUTPUTS
		Boolean indicating success.
	#>
	[CmdletBinding()] param([switch]$QuietMode)

	$modules = @(
		'Microsoft.Graph.Authentication'
	)

	foreach ($mod in $modules) {
		if (-not (Invoke-ModuleOperation -Name $mod -Operation Validate -QuietMode:$QuietMode)) {
			throw "Required module '$mod' is not installed. Please install it: Install-Module $mod -Scope CurrentUser"
		}
	}

	foreach ($mod in $modules) {
		$importResult = Invoke-ModuleOperation -Name $mod -Operation Import -QuietMode:$QuietMode
		if (-not $importResult) {
			throw "Failed to import required module '$mod'."
		}
	}

	# Microsoft.Graph.Groups is helpful for potential resource resolution; load if available but do not require.
	if (Invoke-ModuleOperation -Name 'Microsoft.Graph.Groups' -Operation Validate -QuietMode:$QuietMode) {
		[void](Invoke-ModuleOperation -Name 'Microsoft.Graph.Groups' -Operation Import -QuietMode:$QuietMode)
	}

	return $true
}
