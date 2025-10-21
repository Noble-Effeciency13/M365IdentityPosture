function Connect-SPOServiceSafe {
	<#
	.SYNOPSIS
		Attempts resilient connection to SharePoint Online admin service with optional WinPS compatibility fallback.

	.DESCRIPTION
		First tries native Connect-SPOService; if it fails, re-imports module with -UseWindowsPowerShell (for PS7 compatibility)
		and retries. Returns $true on success, $false otherwise. Writes verbose/warning messages on failures.

	.PARAMETER AdminUrl
		SharePoint Online admin URL (https://tenant-admin.sharepoint.com).

	.PARAMETER Credential
		Optional credential for non-interactive / break-glass usage.

	.OUTPUTS
		Boolean.

	.EXAMPLE
		Connect-SPOServiceSafe -AdminUrl https://contoso-admin.sharepoint.com
	#>
	[CmdletBinding()] param([Parameter(Mandatory = $true)][string]$AdminUrl, [System.Management.Automation.PSCredential]$Credential)
	$connParams = @{ Url = $AdminUrl; ErrorAction = 'Stop' }
	if ($Credential) { $connParams['Credential'] = $Credential }
	try { Connect-SPOService @connParams; return $true } catch { Write-Verbose "Warning: Connect-SPOService (normal) failed: $($_.Exception.Message)" }
	try {
		Invoke-ModuleOperation -Name Microsoft.Online.SharePoint.PowerShell -Operation Import -WinPSCompat | Out-Null
		Connect-SPOService @connParams; return $true
	}
	catch { Write-Warning "Connect-SPOService (WinPSCompat) failed: $($_.Exception.Message)" }
	return $false
}
