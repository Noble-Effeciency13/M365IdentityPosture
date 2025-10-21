function Connect-SharePointAdmin {
	<#
	.SYNOPSIS
		Establishes a connection to SharePoint Online Administration.

	.DESCRIPTION
		Connects to SharePoint Online using the admin URL and updates the data object 
		with connection status. Optionally uses provided credentials for authentication.

	.PARAMETER AdminUrl
		The SharePoint Online admin center URL (e.g., https://contoso-admin.sharepoint.com).

	.PARAMETER Credential
		Optional credentials for authentication.

	.PARAMETER DataObject
		The data object to update with SharePoint connection status.

	.PARAMETER QuietMode
		Suppresses console output when specified.

	.OUTPUTS
		Updated data object with SharePoint connection status.

	.EXAMPLE
		Connect-SharePointAdmin -AdminUrl "https://contoso-admin.sharepoint.com" -DataObject $data
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][string]$AdminUrl,
		[System.Management.Automation.PSCredential]$Credential,
		[Parameter(Mandatory)]$DataObject,
		[switch]$QuietMode
	)
	$connected = $false
	try {
		$connected = Connect-SPOServiceSafe -AdminUrl $AdminUrl -Credential $Credential
		if ($connected) { $DataObject.IsSharePointConnected = $true; if (-not $QuietMode) { Write-Host '   ✓ SPO connected' -ForegroundColor DarkGreen } } else { if (-not $QuietMode) { Write-Host '   ✗ SPO connect failed (primary)' -ForegroundColor Red } }
	}
	catch { $DataObject.ProcessingErrors.Add($_.Exception.Message); if (-not $QuietMode) { Write-Host ('   ✗ SPO connect exception: {0}' -f $_.Exception.Message) -ForegroundColor Red } }
	if (-not $connected -and -not $Credential) {
		try {
			if (-not $QuietMode) { Write-Host '   → Forcing interactive SPO prompt...' -ForegroundColor DarkCyan }
			Connect-SPOService -Url $AdminUrl -ErrorAction Stop
			$connected = $true; $DataObject.IsSharePointConnected = $true
			if (-not $QuietMode) { Write-Host '   ✓ SPO connected (interactive retry)' -ForegroundColor DarkGreen }
		}
		catch { $DataObject.ProcessingErrors.Add('Interactive retry failed: ' + $_.Exception.Message) }
	}
	return $DataObject
}
