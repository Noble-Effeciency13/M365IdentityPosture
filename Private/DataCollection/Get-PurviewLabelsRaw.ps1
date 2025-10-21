function Get-PurviewLabelsRaw {
	<#
	.SYNOPSIS
		Retrieves raw Purview sensitivity labels using existing logic.

	.DESCRIPTION
		Performs Get-Label calls with fallback policy retrieval; preserves console output and error handling.

	.PARAMETER QuietMode
		Suppress progress output.

	.OUTPUTS
		Array of raw label objects.

	.EXAMPLE
		$purviewLabels = Get-PurviewLabelsRaw

	.EXAMPLE
		$purviewLabels = Get-PurviewLabelsRaw -QuietMode
	#>
	[CmdletBinding()] param([switch]$QuietMode)
	if (-not $QuietMode) { Write-Host '   → Discovering sensitivity labels...' -ForegroundColor DarkCyan }
	$labelsRaw = @()
	$labelRetrievalSuccess = $false
	try {
		$labelsRaw = Get-Label -ErrorAction Stop
		if ($labelsRaw.Count -gt 0) { $labelRetrievalSuccess = $true }
	}
	catch {
		if (-not $QuietMode) { Write-Host "   → Default Get-Label failed: $($_.Exception.Message)" -ForegroundColor DarkYellow }
	}
	if (-not $labelRetrievalSuccess -and (Get-Command Get-Label -ErrorAction SilentlyContinue).Parameters.ContainsKey('Policy')) {
		try {
			$labelsRaw = Get-Label -Policy All -ErrorAction Stop
			if ($labelsRaw.Count -gt 0) { $labelRetrievalSuccess = $true }
		}
		catch {
			if (-not $QuietMode) { Write-Host "   → Policy All failed: $($_.Exception.Message)" -ForegroundColor DarkYellow }
		}
	}
	if (-not $labelRetrievalSuccess) {
		if (-not $QuietMode) { Write-Host '   → No labels retrieved through any method' -ForegroundColor DarkYellow }
		$labelsRaw = @()
	}
	return $labelsRaw
}
