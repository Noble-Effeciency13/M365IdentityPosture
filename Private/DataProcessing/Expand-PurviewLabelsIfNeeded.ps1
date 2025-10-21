function Expand-PurviewLabelsIfNeeded {
	<#
	.SYNOPSIS
		Expands label details conditionally (performance aware) preserving output.

	.DESCRIPTION
		Mirrors expansion logic including environment variable limit and timeout job approach.

	.PARAMETER Labels
		Raw label array to potentially expand.

	.PARAMETER QuietMode
		Suppress verbose output.

	.PARAMETER NoProgress
		Disable progress bars.

	.OUTPUTS
		Array of (possibly) expanded labels.
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)]$Labels,
		[switch]$QuietMode,
		[switch]$NoProgress
	)
	$labelsRaw = $Labels
	if ($labelsRaw.Count -eq 0) { return $labelsRaw }
	$labelExpansionLimit = 50
	if ($env:AUTHContext_LABEL_EXPANSION_LIMIT) { try { $labelExpansionLimit = [int]$env:AUTHContext_LABEL_EXPANSION_LIMIT } catch {} }
	if ($labelsRaw.Count -gt $labelExpansionLimit) {
		if (-not $QuietMode) { Write-Host ('   → Skipping individual label expansion (too many labels: {0} > {1})' -f $labelsRaw.Count, $labelExpansionLimit) -ForegroundColor DarkYellow }
		if (-not $QuietMode) { Write-Host '   → Set AUTHContext_LABEL_EXPANSION_LIMIT environment variable to override' -ForegroundColor DarkGray }
		return $labelsRaw
	}
	$expandedLabels = [System.Collections.Generic.List[object]]::new()
	$labelIndex = 0
	$maxLabelExpansionTime = 30
	$skippedSlowLabels = 0
	foreach ($labelBrief in $labelsRaw) {
		$labelIndex++
		if (-not $NoProgress -and $labelsRaw.Count -gt 5) {
			Write-Progress -Id 99 -Activity 'Processing Sensitivity Labels' -Status "Label $labelIndex of $($labelsRaw.Count) ($skippedSlowLabels skipped)" -PercentComplete (($labelIndex / $labelsRaw.Count) * 100)
		}
		try {
			if (-not $labelBrief.LabelActions -and -not $labelBrief.SiteAndGroupSettings) {
				$labelJob = Start-Job -ScriptBlock {
					param($Guid)
					try { Get-Label -Identity $Guid -ErrorAction Stop } catch { $null }
				} -ArgumentList $labelBrief.Guid
				if (Wait-Job -Job $labelJob -Timeout $maxLabelExpansionTime) {
					$detailedLabel = Receive-Job -Job $labelJob
					if ($detailedLabel) { $expandedLabels.Add($detailedLabel) } else { $expandedLabels.Add($labelBrief) }
				}
				else {
					if (-not $QuietMode) { Write-Host ('      ⚠ Label {0} expansion timeout, using brief data' -f $labelBrief.DisplayName) -ForegroundColor DarkYellow }
					$expandedLabels.Add($labelBrief)
					$skippedSlowLabels++
				}
				Remove-Job -Job $labelJob -Force -ErrorAction SilentlyContinue
			}
			else { $expandedLabels.Add($labelBrief) }
		}
		catch { $expandedLabels.Add($labelBrief) }
	}
	if (-not $NoProgress -and $labelsRaw.Count -gt 5) { Write-Progress -Id 99 -Activity 'Processing Sensitivity Labels' -Completed }
	if ($skippedSlowLabels -gt 0 -and -not $QuietMode) { Write-Host ('   → Completed label processing ({0} labels processed, {1} timeouts)' -f $expandedLabels.Count, $skippedSlowLabels) -ForegroundColor DarkCyan }
	return $expandedLabels.ToArray()
}
