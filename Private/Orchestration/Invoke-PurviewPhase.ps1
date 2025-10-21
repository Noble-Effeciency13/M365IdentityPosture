function Invoke-PurviewPhase {
	<#
	.SYNOPSIS
		Collects sensitivity labels (Purview) and parses for Authentication Context references.

	.DESCRIPTION
		Imports ExchangeOnlineManagement, connects to Purview (IPPSSession or REST fallback), retrieves and expands sensitivity labels, extracts Authentication Context (Id/Name) from label actions / site & group settings, then unloads the module.

	.PARAMETER QuietMode
		Suppress detailed progress output.

	.PARAMETER PurviewUpn
		Optional UPN hint for Purview connection.

	.PARAMETER NoProgress
		Suppress progress updates during label expansion.

	.OUTPUTS
		PSCustomObject with LabelRaw, Labels, connection flags, and errors.

	.NOTES
	Module is always disconnected & removed at the end to avoid assembly conflicts.
	#>
	[CmdletBinding()] param(
		[switch]$QuietMode,
		[string]$PurviewUpn,
		[switch]$NoProgress
	)

	$purviewSensitivityData = $script:PurviewAuthenticationData
	
	# Check if ExchangeOnlineManagement module is available
	if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) { 
		$purviewSensitivityData.ProcessingErrors += 'ExchangeOnlineManagement not installed.' 
		return $purviewSensitivityData 
	}

	# Connection (delegated helper preserves behavior)
	$purviewSensitivityData = Connect-PurviewService -QuietMode:$QuietMode -PurviewUpn $PurviewUpn -DataObject $purviewSensitivityData
	
	if ($purviewSensitivityData.IsPurviewConnected) {
		try {
			# Get raw labels
			$labelsRaw = Get-PurviewLabelsRaw -QuietMode:$QuietMode
			
			# Expand labels if any found
			if ($labelsRaw.Count -gt 0) { 
				$labelsRaw = Expand-PurviewLabelsIfNeeded -Labels $labelsRaw -QuietMode:$QuietMode -NoProgress:$NoProgress 
			}
			
			# Parse labels for authentication context
			$parsedLabelsWithContext = Parse-PurviewLabelsForAuthContext -Labels $labelsRaw
			
			# Store results
			$purviewSensitivityData.RawLabelData.AddRange($labelsRaw)
			foreach ($label in $parsedLabelsWithContext) { 
				$purviewSensitivityData.SensitivityLabels.Add($label) 
			}
			
			# Update global variable
			$script:AllSensitivityLabels = $purviewSensitivityData.SensitivityLabels
			
			# Calculate statistics
			$totalLabelsFound = $labelsRaw.Count
			$labelsWithAuthenticationContext = ($purviewSensitivityData.SensitivityLabels | Where-Object { $_.AuthContextName }).Count
			
			# Report results
			if (-not $QuietMode) {
				if ($totalLabelsFound -gt 0) { 
					Write-Host ('   ✓ Collected {0} sensitivity label(s) ({1} with Authentication Context)' -f $totalLabelsFound, $labelsWithAuthenticationContext) -ForegroundColor DarkGreen 
				}
				else { 
					Write-Host '   ⚠ Collected 0 sensitivity labels' -ForegroundColor DarkYellow 
				}
			}
		}
		catch {
			$purviewSensitivityData.ProcessingErrors.Add($_.Exception.Message)
			if (-not $QuietMode) { 
				Write-Host '   ⚠ Label collection failed' -ForegroundColor DarkYellow 
			}
		}
	}

	# Cleanup always attempted regardless of success; silent on errors
	try { 
		Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null 
	} 
	catch { 
		# Silent failure
	}
	
	try { 
		Remove-Module ExchangeOnlineManagement -Force -ErrorAction SilentlyContinue 
	} 
	catch { 
		# Silent failure
	}
	
	if (-not $QuietMode) { 
		Write-Host '[EXO] Phase complete (module unloaded)' -ForegroundColor DarkGray 
	}
	
	return $purviewSensitivityData
}
