function Get-GraphTenantMetadata {
	<#
	.SYNOPSIS
		Retrieves basic tenant metadata (tenant id and default onmicrosoft domain).

	.DESCRIPTION
		Calls /organization selecting id, tenantId, verifiedDomains. Determines the managed *.onmicrosoft.com domain
		and computes a short name (prefix) for use in SPO admin URL construction.

	.OUTPUTS
		PSCustomObject: TenantId, OnmicrosoftDomain, TenantShortName (or $null on failure).

	.EXAMPLE
		$tenantMetadata = Get-GraphTenantMetadata
	#>
	[CmdletBinding()] param()
	try {
		$organizationGraphRequest = @{
			Method      = 'GET'
			Uri         = 'https://graph.microsoft.com/v1.0/organization?$select=id,tenantId,verifiedDomains'
			ErrorAction = 'Stop'
		}
		$organizationResponse = Invoke-MgGraphRequest @organizationGraphRequest
    
		if (-not $organizationResponse.value) { return $null }
    
		$organizationData = $organizationResponse.value[0]
		$tenantId = $organizationData.tenantId
		$onMicrosoftDomain = ($organizationData.verifiedDomains | 
				Where-Object { $_.name -like '*.onmicrosoft.com' -and $_.type -eq 'Managed' } |
				Sort-Object { -not $_.isDefault }, { -not $_.isInitial } | 
				Select-Object -First 1).name
		$tenantShortName = $null
		if ($onMicrosoftDomain -and $onMicrosoftDomain -match '^([a-z0-9-]+)\.onmicrosoft\.com$') { 
			$tenantShortName = $Matches[1] 
		}
    
		return [pscustomobject]@{ 
			TenantId          = $tenantId
			OnmicrosoftDomain = $onMicrosoftDomain
			TenantShortName   = $tenantShortName 
		}
	}
	catch { 
		return $null 
	}
}
