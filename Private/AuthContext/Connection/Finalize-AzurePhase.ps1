function Finalize-AzurePhase {
	<#
	.SYNOPSIS
		Performs cleanup operations for the Azure resource collection phase.

	.DESCRIPTION
		Handles disconnection from Azure if configured via environment variable.
		Updates the data object with final Azure phase status.

	.PARAMETER DataObject
		The data object to update with finalization status.

	.PARAMETER QuietMode
		Suppresses console output when specified.

	.OUTPUTS
		Updated data object with Azure phase completion status.

	.EXAMPLE
		Finalize-AzurePhase -DataObject $data
    #>
	[CmdletBinding()] param(
		[Parameter(Mandatory)]$DataObject,
		[switch]$QuietMode
	)
	$forceDisc = $env:AUTHContext_AZURE_DISCONNECT
	if ($forceDisc -and $forceDisc -in @('1', 'true', 'yes')) {
		try { if ($DataObject.IsAzureConnected) { Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null } } catch {}
		try { Remove-Module Az.Accounts -Force -ErrorAction SilentlyContinue } catch {}
		if (-not $QuietMode) { Write-Host '[Azure] Phase complete (disconnected by policy)' -ForegroundColor DarkGray }
	}
	else {
		if (-not $QuietMode) { Write-Host '[Azure] Phase complete (context retained)' -ForegroundColor DarkGray }
	}
	return $DataObject
}
