function Invoke-AzureResourcePIMCollection {
	<#
	.SYNOPSIS
		Safely collects Azure Resource PIM policies with temporary preference suppression mirroring inline original logic.

	.DESCRIPTION
		Wraps environment variable setting, preference suppression, and call to Get-AzureResourcePIMPolicies. Returns the raw array.
		Preserves identical behavior, including silent failure paths; host output remains under control of caller.

	.PARAMETER AuthContexts
		Authentication contexts for mapping.

	.PARAMETER AccountUpn
		Preferred UPN for Azure connection logic.

	.PARAMETER TenantId
		Tenant ID used to scope Azure subscription enumeration and REST calls.

	.PARAMETER AzureSubscriptionIds
		Optional specific subscription IDs to process.

    .PARAMETER Quiet
    	Suppresses non-essential host output (passed through to underlying cmdlet indirectly via global variables).

    .OUTPUTS
    	Array of PIM policy objects (same shape as Get-AzureResourcePIMPolicies output).
    #>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)] [object[]] $AuthContexts,
		[string] $AccountUpn,
		[string] $TenantId,
		[string[]] $AzureSubscriptionIds,
		[switch] $Quiet
	)

	if ($TenantId) { [Environment]::SetEnvironmentVariable('AZURE_TENANT_ID', $TenantId, 'Process') }

	$prevWarn = $WarningPreference; $prevInfo = $InformationPreference; $prevVerb = $VerbosePreference; $prevDbg = $DebugPreference
	$WarningPreference = 'SilentlyContinue'; $InformationPreference = 'SilentlyContinue'; $VerbosePreference = 'SilentlyContinue'; $DebugPreference = 'SilentlyContinue'
	try {
		return (Get-AzureResourcePIMPolicies -AuthContexts $AuthContexts -AccountUpn $AccountUpn -TenantId $TenantId -AzureSubscriptionIds $AzureSubscriptionIds)
	}
	catch {
		# Return empty on error per original inline logic's silent catch pattern
		return @()
	}
	finally {
		$WarningPreference = $prevWarn; $InformationPreference = $prevInfo; $VerbosePreference = $prevVerb; $DebugPreference = $prevDbg
	}
}
