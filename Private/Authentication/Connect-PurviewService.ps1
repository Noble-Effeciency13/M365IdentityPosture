function Connect-PurviewService {
	<#
	.SYNOPSIS
		Establishes Purview (Compliance) connectivity using IPPSSession or ExchangeOnline fallback.

	.DESCRIPTION
		Mirrors connection logic from original Invoke-PurviewPhase without altering output.

	.PARAMETER QuietMode
		Suppress progress output.

	.PARAMETER PurviewUpn
		Optional user principal name for connection targeting.

	.PARAMETER DataObject
		Purview data object to update (passed by reference).

	.OUTPUTS
		Returns the updated data object.

	.EXAMPLE
		$data = Connect-PurviewService -DataObject $purviewData

	.EXAMPLE
		$data = Connect-PurviewService -DataObject $purviewData -PurviewUpn "admin@contoso.com" -QuietMode
	#>
	[CmdletBinding()] param(
		[switch]$QuietMode,
		[string]$PurviewUpn,
		[Parameter(Mandatory)]
		$DataObject
	)

	if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) { $DataObject.ProcessingErrors += 'ExchangeOnlineManagement not installed.'; return $DataObject }
	try {
		Invoke-ModuleOperation -Name ExchangeOnlineManagement -Operation Import | Out-Null
		$DataObject.IsExchangeOnlineConnected = $true
		if (-not $QuietMode) { Write-Host '[EXO] Module imported' -ForegroundColor DarkGray }
	}
	catch { $DataObject.ProcessingErrors += $_.Exception.Message; return $DataObject }

	if (-not $QuietMode) { Write-Host '[Purview] Connecting IPPSSession...' -ForegroundColor Green }
	$prevWarn = $WarningPreference; $prevInfo = $InformationPreference
	$WarningPreference = 'SilentlyContinue'; $InformationPreference = 'SilentlyContinue'
	try {
		$connectParams = @{ ShowBanner = $false }
		if ($PurviewUpn) { $connectParams['UserPrincipalName'] = $PurviewUpn }
		if (Get-Command Connect-IPPSSession -ErrorAction SilentlyContinue) {
			if (-not $QuietMode) { Write-Host '   → Using Connect-IPPSSession...' -ForegroundColor DarkCyan }
			Connect-IPPSSession @connectParams | Out-Null
		}
		else {
			if (-not $QuietMode) { Write-Host '   → Fallback to Connect-ExchangeOnline...' -ForegroundColor DarkCyan }
			Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop | Out-Null
		}
		$DataObject.IsPurviewConnected = $true
		if (-not $QuietMode) { Write-Host '   ✓ Purview connected' -ForegroundColor DarkGreen }
	}
	catch {
		$DataObject.ProcessingErrors += 'Purview connect failed: ' + $_.Exception.Message
		if (-not $QuietMode) { Write-Host '   ✗ Purview connection failed' -ForegroundColor Red }
	}
	finally {
		$WarningPreference = $prevWarn; $InformationPreference = $prevInfo
	}
	return $DataObject
}
