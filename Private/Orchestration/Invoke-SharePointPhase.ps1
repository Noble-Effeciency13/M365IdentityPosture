function Invoke-SharePointPhase {
	<#
	.SYNOPSIS
		Enumerates SharePoint Online sites and identifies those enforcing an Authentication Context.

	.DESCRIPTION
		Connects using SPO admin module, enumerates tenant sites, filters sites with ConditionalAccessPolicy 'AuthenticationContext' or AuthenticationContextName property.

	.PARAMETER TenantName
		Tenant short name used to build SPO admin URL.

	.PARAMETER QuietMode
		Suppress verbose progress output.

	.PARAMETER Credential
		Optional credential (legacy / break-glass scenarios).

	.OUTPUTS
		PSCustomObject with SitesRaw, SitesWithAuthContext, connection state, and errors.
	#>
	[CmdletBinding()] param(
		[string]$TenantName,
		[switch]$QuietMode,
		[System.Management.Automation.PSCredential]$Credential
	)
	$data = $script:SharePointAuthenticationData
	
	if ([string]::IsNullOrWhiteSpace($TenantName)) { 
		return $data 
	}
	
	$adminUrl = "https://$TenantName-admin.sharepoint.com"
	
	if (-not $QuietMode) { 
		Write-Host ('[SPO] Connecting (SPO): {0}' -f $adminUrl) -ForegroundColor Green 
	}
	
	$importSucceeded = $false
	
	# Try to import SharePoint module
	if (Import-SharePointModule -QuietMode:$QuietMode) { 
		$importSucceeded = $true 
	} 
	else { 
		$data.ProcessingErrors.Add('SPO module not installed.') 
	}
	
	try {
		if ($importSucceeded) {
			# Connect to SharePoint Admin
			$data = Connect-SharePointAdmin -AdminUrl $adminUrl -Credential $Credential -DataObject $data -QuietMode:$QuietMode
			
			if ($data.IsSharePointConnected) {
				try {
					# Get all sites
					$sites = Get-SPOSitesRaw -QuietMode:$QuietMode
					
					# Store all sites
					$data.AllSiteCollection = [System.Collections.Generic.List[object]]::new()
					$sites | ForEach-Object { 
						$data.AllSiteCollection.Add($_) 
					}
					
					# Filter sites with authentication context
					$withContext = Filter-SitesForAuthContext -Sites $sites
					$withContext | ForEach-Object { 
						$data.SitesWithAuthenticationContext.Add($_) 
					}
					
					# Report results
					if (-not $QuietMode) { 
						Write-Host ('   ✓ Sites scanned (total={0}, withContext={1})' -f ($sites.Count), ($data.SitesWithAuthenticationContext.Count)) -ForegroundColor DarkGreen 
					}
				}
				catch { 
					$data.ProcessingErrors.Add($_.Exception.Message)
					if (-not $QuietMode) { 
						Write-Host '   ⚠ Site enumeration failed' -ForegroundColor DarkYellow 
					} 
				}
			}
			else { 
				if (-not $QuietMode) { 
					Write-Host '   ⚠ SharePoint phase not connected - skipping site enumeration' -ForegroundColor DarkYellow 
				} 
			}
		}
	}
	finally {
		# Cleanup SharePoint connection and module
		try { 
			if (Get-Command Disconnect-SPOService -ErrorAction SilentlyContinue) { 
				Disconnect-SPOService -ErrorAction SilentlyContinue | Out-Null 
			} 
		} 
		catch { 
			# Silent failure
		}
		
		try { 
			Remove-Module Microsoft.Online.SharePoint.PowerShell -Force -ErrorAction SilentlyContinue 
		} 
		catch { 
			# Silent failure
		}
		
		if (-not $QuietMode) { 
			Write-Host '[SPO] Phase complete (module unloaded)' -ForegroundColor DarkGray 
		}
	}
	
	return $data
}
