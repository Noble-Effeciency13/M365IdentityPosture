function Connect-AzContextSafe {
	<#
	.SYNOPSIS
		Establishes or reuses an Azure PowerShell context for Azure resource access.

	.DESCRIPTION
		Attempts to establish a connection to Azure using the Az PowerShell module. If an existing 
		context is found, it will reuse it. Updates the provided data object with connection status.

	.PARAMETER DataObject
		The data object to update with Azure connection status.

	.PARAMETER TenantId
		Optional Azure AD tenant ID to connect to.

	.PARAMETER AccountUpn
		Optional user principal name for authentication.

	.PARAMETER QuietMode
		Suppresses console output when specified.

	.OUTPUTS
		Updated data object with Azure connection status.

	.EXAMPLE
		Connect-AzContextSafe -DataObject $data -TenantId "contoso.onmicrosoft.com"
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)]$DataObject,
		[string]$TenantId,
		[string]$AccountUpn,
		[switch]$QuietMode
	)
	$reused = $false
	$existingContext = $null; try { $existingContext = Get-AzContext -ErrorAction Stop } catch {}
	if ($existingContext) {
		$DataObject.IsAzureConnected = $true
		$reused = $true
		if (-not $QuietMode) { Write-Host '[Azure] Reusing existing Az context' -ForegroundColor DarkGreen }
		return $DataObject
	}
	if (-not $QuietMode) { Write-Host '[Azure] Connecting...' -ForegroundColor Green }
	$acct = $AccountUpn
	if (-not $acct) { try { $acct = (Get-AzContext -ErrorAction SilentlyContinue).Account } catch {} }
	$retries = 0; $max = 3; $delay = 2
	while (-not $DataObject.IsAzureConnected -and $retries -lt $max) {
		try {
			if ($TenantId) {
				if ($acct) { Connect-AzAccount -Account $acct -Tenant $TenantId -ErrorAction Stop | Out-Null }
				else { Connect-AzAccount -Tenant $TenantId -ErrorAction Stop | Out-Null }
			}
			else {
				if ($acct) { Connect-AzAccount -Account $acct -ErrorAction Stop | Out-Null } else { Connect-AzAccount -ErrorAction Stop | Out-Null }
			}
			$DataObject.IsAzureConnected = $true
		}
		catch {
			$retries++
			if ($retries -lt $max) { Start-Sleep -Seconds $delay; $delay = [Math]::Min($delay * 2, 10) } else { $DataObject.ProcessingErrors.Add($_.Exception.Message) }
		}
	}
	if ($DataObject.IsAzureConnected -and -not $QuietMode) { Write-Host '[Azure] Connected' -ForegroundColor DarkGreen }
	if (-not $DataObject.IsAzureConnected -and -not $QuietMode) { Write-Host '[Azure] Connection failed after retries' -ForegroundColor Red }
	return $DataObject
}
