function Get-AzureResourcePIMPolicies {
	<#
	.SYNOPSIS
		Enumerates Azure Resource (subscription / resource group) PIM policies and extracts Authentication Context usage.

	.DESCRIPTION
		Connects (or reuses existing context) to Az modules, iterates enabled subscriptions, gathers roleManagementPolicies &
		assignments via ARM REST (2020-10-01), and parses rules/effectiveRules for RoleManagementPolicyAuthenticationContextRule
		and related arrays. Performs a distinct role definition name resolution pass, emitting progress (Ids 7,8,9).

	.PARAMETER AuthContexts
		Authentication contexts used to map IDs / class references to display names.

	.PARAMETER AccountUpn
		Optional UPN to prefer when establishing Az context (otherwise inferred from Graph context).

	.PARAMETER TenantId
		Optional tenant ID override (GUID); inferred if omitted.

	.PARAMETER AzureSubscriptionIds
    	Optional array of specific subscription IDs to process. If not specified, all accessible subscriptions are processed.

	.OUTPUTS
		PSCustomObject: PolicyId, Scope, ScopeType, AuthContextIds, AuthContextClassRefs, AuthContextNames,
		RoleDefinitionId, RoleDisplayName (when resolved), Source.

	.NOTES
		Requires Az.Accounts & Az.Resources. Uses REST for efficiency; suppresses noisy progress/host output.
		
	.EXAMPLE
		$azPim = Get-AzureResourcePIMPolicies -AuthContexts $authContexts -AzureSubscriptionIds @('sub1-guid','sub2-guid')
  	#>
	[CmdletBinding()] param(
		[object[]]$AuthContexts,
		[string]$AccountUpn,
		[string]$TenantId,
		[string[]]$AzureSubscriptionIds
	)
  
	# Fast early exit checks
	if (-not (Get-Module -ListAvailable -Name Az.Accounts)) { 
		if (-not $Quiet) { Write-Host '     ✗ Az.Accounts module not available - skipping Azure resource PIM' -ForegroundColor Yellow }
		return @() 
	}
  
	# Import required Azure module
	try { Invoke-ModuleOperation -Name Az.Accounts -Operation Import | Out-Null } catch { 
		if (-not $Quiet) { Write-Host "     ✗ Failed to import Az.Accounts: $($_.Exception.Message)" -ForegroundColor Red }
		return @() 
	}
	try { Invoke-ModuleOperation -Name Az.Resources -Operation Import -QuietMode | Out-Null } catch { 
		if (-not $Quiet) { Write-Host '     ⚠ Az.Resources import failed (continuing)' -ForegroundColor DarkYellow } 
	}

	# Derive missing AccountUpn from current Graph context if possible
	if (-not $AccountUpn) {
		try {
			$currentMgContext = Get-MgContext -ErrorAction SilentlyContinue
			if ($currentMgContext -and $currentMgContext.Account) { $AccountUpn = $currentMgContext.Account }
		}
		catch {}
	}

	# Ensure Az is connected once (reuse Graph identity) without prompting
	$isAzureConnected = $false
	try { if (Get-AzContext -ErrorAction Stop) { $isAzureConnected = $true } } catch { $isAzureConnected = $false }
	if (-not $isAzureConnected) {
		if (-not $Quiet) { Write-Host '     → Azure authentication...' -ForegroundColor DarkCyan }
		$azureAccountUpn = $AccountUpn
		if (-not $azureAccountUpn) { try { $azureAccountUpn = (Get-MgContext -ErrorAction SilentlyContinue).Account } catch {} }
		$azureTenantId = $TenantId
		if (-not $azureTenantId) { $azureTenantId = $script:CurrentTenantId }
		if (-not $azureTenantId) { try { $azureTenantId = (Get-MgContext -ErrorAction SilentlyContinue).TenantId } catch {} }
		if (-not $azureTenantId) { try { $azureTenantId = (Get-AzContext -ErrorAction SilentlyContinue).Tenant.Id } catch {} }
		if (-not $azureTenantId) { return @() }
		$previousWarningPreference = $WarningPreference; $previousInformationPreference = $InformationPreference; $previousProgressPreference = $ProgressPreference; $previousVerbosePreference = $VerbosePreference; $previousDebugPreference = $DebugPreference
		$WarningPreference = 'SilentlyContinue'; $InformationPreference = 'SilentlyContinue'; $ProgressPreference = 'SilentlyContinue'; $VerbosePreference = 'SilentlyContinue'; $DebugPreference = 'SilentlyContinue'
		try {
			$connectionRetries = 0; $maxConnectionRetries = 3; $retryDelaySeconds = 2
			while (-not $isAzureConnected -and $connectionRetries -lt $maxConnectionRetries) {
				try {
					$null = & { Connect-AzAccount -Account $azureAccountUpn -Tenant $azureTenantId -Force -SkipContextPopulation -ErrorAction Stop } 2>$null 3>$null 4>$null 5>$null 6>$null
					$isAzureConnected = $true
				}
				catch {
					$connectionRetries++
					if ($connectionRetries -lt $maxConnectionRetries) { Start-Sleep -Seconds $retryDelaySeconds; $retryDelaySeconds = [Math]::Min($retryDelaySeconds * 2, 10) }
				}
			}
		}
		finally { 
			$WarningPreference = $previousWarningPreference; $InformationPreference = $previousInformationPreference; $ProgressPreference = $previousProgressPreference; $VerbosePreference = $previousVerbosePreference; $DebugPreference = $previousDebugPreference 
		}
		if (-not $isAzureConnected -and -not $Quiet) { Write-Host '     ✗ Azure authentication failed' -ForegroundColor Red }
		if ($isAzureConnected -and -not $Quiet) { Write-Host '     ✓ Azure connected' -ForegroundColor DarkGreen }
	}

	$availableSubscriptions = @()
	try {
		$env:AZURE_PS_LOAD_ADDITIONAL_MODULES = 'true'
		$tenantIdForContext = $TenantId; if (-not $tenantIdForContext) { $tenantIdForContext = $script:CurrentTenantId }
		if (-not $tenantIdForContext) { try { $tenantIdForContext = (Get-AzContext -ErrorAction SilentlyContinue).Tenant.Id } catch {} }
		if ($tenantIdForContext) { 
			try { Set-AzContext -Tenant $tenantIdForContext -ErrorAction SilentlyContinue | Out-Null } catch {} 
		}
		# Suppress progress/host output during subscription enumeration to reduce noise
		$storedWarningPreference = $WarningPreference; $storedProgressPreference = $ProgressPreference; $WarningPreference = 'SilentlyContinue'; $ProgressPreference = 'SilentlyContinue'
		try {
			# Try to get subscriptions only for the current tenant using REST API for more precise filtering
			try {
				# Use ARM REST API to get subscriptions for the specific tenant
				$armApiResponse = Invoke-AzRestMethod -Method GET -Path '/subscriptions?api-version=2020-01-01' -ErrorAction Stop
				if ($armApiResponse.StatusCode -eq 200) {
					$armResponseContent = $armApiResponse.Content | ConvertFrom-Json
					$availableSubscriptions = $armResponseContent.value | Where-Object { 
						$_.tenantId -eq $tenantIdForContext -and 
						$_.state -eq 'Enabled' 
					} | ForEach-Object {
						# Convert ARM REST response to subscription-like object
						[pscustomobject]@{
							Id       = $_.subscriptionId
							Name     = $_.displayName
							TenantId = $_.tenantId
							State    = $_.state
						}
					}
				}
				else {
					throw "ARM API returned status $($armApiResponse.StatusCode)"
				}
			}
			catch {
				# Fallback to PowerShell cmdlet if REST API fails
				$allAzureSubscriptions = & {
					Get-AzSubscription -TenantId $tenantIdForContext -ErrorAction Stop -WarningAction SilentlyContinue
				} 2>$null 3>$null 4>$null 5>$null 6>$null
        
				# Double-filter to ensure we only get subscriptions from the current tenant
				$availableSubscriptions = $allAzureSubscriptions | Where-Object { 
					$_.TenantId -eq $tenantIdForContext -and 
					$_.State -eq 'Enabled' 
				}
			}
		}
		finally { $ProgressPreference = $storedProgressPreference; $WarningPreference = $storedWarningPreference }
	}
	catch { $availableSubscriptions = @() }
  
	# Verify tenant filtering results
	if ($availableSubscriptions -and $tenantIdForContext) {
		# Check if any subscriptions are still from other tenants (shouldn't happen with improved filtering)
		$crossTenantSubscriptions = $availableSubscriptions | Where-Object { $_.TenantId -ne $tenantIdForContext }
    
		if ($crossTenantSubscriptions.Count -gt 0) {
			# Filter them out if any remain
			$availableSubscriptions = $availableSubscriptions | Where-Object { $_.TenantId -eq $tenantIdForContext }
		}
	}
  
	# Filter subscriptions based on AzureSubscriptionIds parameter if specified
	if ($AzureSubscriptionIds -and $AzureSubscriptionIds.Count -gt 0) {
		$availableSubscriptions = $availableSubscriptions | Where-Object { $_.Id -in $AzureSubscriptionIds }
	}
  
	if (-not $availableSubscriptions) { if (-not $Quiet) { Write-Host '     ⚠ No enabled subscriptions found for Azure PIM' -ForegroundColor DarkYellow }; return @() }

	# Setup context mapping for Authentication Context ID resolution
	$authenticationContextById = @{}
	if ($AuthContexts) { foreach ($authenticationContext in $AuthContexts) { if ($authenticationContext.Id) { $authenticationContextById[$authenticationContext.Id] = $authenticationContext.DisplayName } } }

	$armApiVersion = 'api-version=2020-10-01'
	$pimPolicyResults = @()
	$totalSubscriptionsToProcess = ($availableSubscriptions | Measure-Object).Count
	$currentSubscriptionIndex = 0
	if (-not $NoProgress) { Write-Progress -Id 7 -Activity 'Azure PIM: Subscriptions' -Status 'Starting enumeration' -PercentComplete 0 }
  
	# Initialize role name cache if not present for performance optimization
	if (-not $script:__AuthContext_RoleNameCache) { $script:__AuthContext_RoleNameCache = @{} }
  
	foreach ($currentSubscription in $availableSubscriptions) {
		$currentSubscriptionIndex++
		if (-not $NoProgress) {
			$subscriptionProgressPercent = if ($totalSubscriptionsToProcess -gt 0) { [int](($currentSubscriptionIndex / $totalSubscriptionsToProcess) * 100) } else { 0 }
			Write-Progress -Id 7 -Activity 'Azure PIM: Subscriptions' -Status ('{0} ({1}/{2})' -f $currentSubscription.Name, $currentSubscriptionIndex, $totalSubscriptionsToProcess) -PercentComplete $subscriptionProgressPercent
		}
		if ($currentSubscription.State -and $currentSubscription.State -ne 'Enabled') { continue }
    
		# Set subscription context for subsequent API calls
		$null = & { Set-AzContext -Subscription $currentSubscription.Id -ErrorAction SilentlyContinue } 2>$null 3>$null 4>$null 5>$null 6>$null
		$subscriptionScope = "/subscriptions/$($currentSubscription.Id)"
    
		# Step 1: Get role management policy assignments to identify roles with custom PIM policies
		$assignmentPath = "$subscriptionScope/providers/Microsoft.Authorization/roleManagementPolicyAssignments?$armApiVersion"
		$pimManagedRoles = @{}
		try {
			$policyAssignments = (Invoke-AzRestMethod -Method GET -Path $assignmentPath).Content | ConvertFrom-Json
			if ($policyAssignments.value) {
				# Get role management policies to identify which ones have Authentication Context rules
				$policyPath = "$subscriptionScope/providers/Microsoft.Authorization/roleManagementPolicies?$armApiVersion"
				$roleManagementPolicyResponse = (Invoke-AzRestMethod -Method GET -Path $policyPath).Content | ConvertFrom-Json
				$authenticationContextPolicies = @{}
        
				if ($roleManagementPolicyResponse.value) {
					foreach ($roleManagementPolicy in $roleManagementPolicyResponse.value) {
						# Only consider policies that have Authentication Context rules since this is an AuthContext inventory
						$hasAuthenticationContextRules = $false
						if ($roleManagementPolicy.properties -and $roleManagementPolicy.properties.rules) {
							foreach ($policyRule in $roleManagementPolicy.properties.rules) {
								$ruleType = $policyRule.ruleType ?? $policyRule.properties.ruleType
								$isRuleEnabled = [bool]($policyRule.isEnabled ?? $policyRule.properties.isEnabled ?? $true)
                
								# Only flag as custom if it has Authentication Context rules
								if ($ruleType -eq 'RoleManagementPolicyAuthenticationContextRule' -and $isRuleEnabled) {
									$authContextClaimValue = $policyRule.claimValue ?? $policyRule.properties.claimValue
									if ($authContextClaimValue) {
										$hasAuthenticationContextRules = $true
										break
									}
								}
							}
						}
            
						if ($hasAuthenticationContextRules) {
							$authenticationContextPolicies[$roleManagementPolicy.id] = $true
						}
					}
				}
        
				# Now collect assignments for roles that have Authentication Context policies
				foreach ($policyAssignment in $policyAssignments.value) {
					if ($policyAssignment.properties -and $policyAssignment.properties.roleDefinitionId -and $policyAssignment.properties.policyId) {
						# Only include roles that have Authentication Context policies
						if ($authenticationContextPolicies.ContainsKey($policyAssignment.properties.policyId)) {
							$roleDefinitionId = $policyAssignment.properties.roleDefinitionId
							if (-not $pimManagedRoles.ContainsKey($roleDefinitionId)) {
								$pimManagedRoles[$roleDefinitionId] = @()
							}
							$pimManagedRoles[$roleDefinitionId] += $policyAssignment.properties.policyId
						}
					}
				}
			}
		}
		catch {
			if (-not $Quiet) { Write-Host "     ⚠ Failed to get PIM policy assignments for subscription $($currentSubscription.Name)" -ForegroundColor DarkYellow }
			continue
		}
    
		if ($pimManagedRoles.Count -eq 0) {
			continue
		}

		# Step 2: Process PIM-managed roles and check their policies for Authentication Context
		$pimRoleCount = $pimManagedRoles.Count
		$processedRolesCount = 0
    
		# Get all policies for this subscription (already retrieved in step 1 for efficiency)
		$policyPath = "$subscriptionScope/providers/Microsoft.Authorization/roleManagementPolicies?$armApiVersion"
		$roleManagementPoliciesById = @{}
		try {
			$roleManagementPolicyResponse = (Invoke-AzRestMethod -Method GET -Path $policyPath).Content | ConvertFrom-Json
			if ($roleManagementPolicyResponse.value) {
				foreach ($roleManagementPolicy in $roleManagementPolicyResponse.value) {
					$roleManagementPoliciesById[$roleManagementPolicy.id] = $roleManagementPolicy
				}
			}
		}
		catch {
			if (-not $Quiet) { Write-Host "     ⚠ Failed to get PIM policies for subscription $($currentSubscription.Name)" -ForegroundColor DarkYellow }
			continue
		}
    
		foreach ($roleDefinitionId in $pimManagedRoles.Keys) {
			$processedRolesCount++
			$rolePolicyIds = $pimManagedRoles[$roleDefinitionId]
      
			# Resolve role display name using cache for performance
			$roleDisplayName = $null
			if ($script:__AuthContext_RoleNameCache.ContainsKey($roleDefinitionId)) {
				$roleDisplayName = $script:__AuthContext_RoleNameCache[$roleDefinitionId]
			}
			else {
				# First try common built-in role mappings for performance
				$builtInRoleDefinitions = @{
					'8e3af657-a8ff-443c-a75c-2fe8c4bcb635' = 'Owner'
					'b24988ac-6180-42a0-ab88-20f7382dd24c' = 'Contributor'
					'acdd72a7-3385-48ef-bd42-f606fba81ae7' = 'Reader'
					'18d7d88d-d35e-4fb5-a5c3-7773c20a72d9' = 'User Access Administrator'
					'9980e02c-c2be-4d73-94e8-173b1dc7cf3c' = 'Virtual Machine Contributor'
					'17d1049b-9a84-46fb-8f53-869881c3d3ab' = 'Storage Account Contributor'
					'ba92f5b4-2d11-453d-a403-e96b0029c9fe' = 'Storage Blob Data Contributor'
					'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' = 'Storage Blob Data Owner'
					'2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' = 'Storage Blob Data Reader'
					'6a9a1e65-b6ba-474c-9a5e-ab46e99b38ad' = 'Key Vault Administrator'
					'00482a5a-887f-4fb3-b363-3b7fe8e74483' = 'Key Vault Secrets User'
				}
        
				if ($builtInRoleDefinitions.ContainsKey($roleDefinitionId)) {
					$roleDisplayName = $builtInRoleDefinitions[$roleDefinitionId]
					$script:__AuthContext_RoleNameCache[$roleDefinitionId] = $roleDisplayName
				}
				else {
					# Try to get role definition name via REST API for custom roles
					try {
						$roleDefinitionPath = "$roleDefinitionId/?api-version=2018-01-01-preview"
						$roleDefinitionResponse = Invoke-AzRestMethod -Method GET -Path $roleDefinitionPath
						if ($roleDefinitionResponse.StatusCode -eq 200) {
							$roleDefinitionContent = $roleDefinitionResponse.Content | ConvertFrom-Json
							if ($roleDefinitionContent.properties -and $roleDefinitionContent.properties.roleName) {
								$roleDisplayName = $roleDefinitionContent.properties.roleName
								$script:__AuthContext_RoleNameCache[$roleDefinitionId] = $roleDisplayName
							}
						}
					}
					catch {
						# If REST API fails, continue to fallback
					}
          
					# Fallback to truncated role ID if name resolution fails
					if (-not $roleDisplayName) {
						$roleDisplayName = if ($roleDefinitionId -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
							'Role ' + $Matches[1].Substring(0, 8)
						}
						else {
							'Role ' + $roleDefinitionId.Substring(0, [Math]::Min(8, $roleDefinitionId.Length))
						}
						$script:__AuthContext_RoleNameCache[$roleDefinitionId] = $roleDisplayName
					}
				}
			}
      
			# Show progress for PIM-managed roles processing (only processing roles that actually have PIM policies)
			if (-not $NoProgress) {
				$rolesProgressPercent = if ($pimRoleCount -gt 0) { [int](($processedRolesCount / $pimRoleCount) * 100) } else { 0 }
				Write-Progress -ParentId 7 -Id 8 -Activity 'Azure PIM: Policies' -Status "$roleDisplayName ($processedRolesCount/$pimRoleCount PIM roles)" -PercentComplete $rolesProgressPercent
			}
      
			# Check policies for this PIM-managed role
			foreach ($currentPolicyId in $rolePolicyIds) {
				if (-not $roleManagementPoliciesById.ContainsKey($currentPolicyId)) { continue }
        
				$fullPolicyDetails = $roleManagementPoliciesById[$currentPolicyId]
				$policyProperties = $fullPolicyDetails.properties
				if (-not $policyProperties) { continue }
        
				# Get rules for Authentication Context checking
				$policyRules = @()
				if ($policyProperties.rules) { $policyRules += @($policyProperties.rules) }
				if ($policyProperties.effectiveRules) { $policyRules += @($policyProperties.effectiveRules) }
				if (-not $policyRules) { continue }
        
				# Check for Authentication Context rules in the policy
				$authenticationContextIds = @(); $authenticationContextClassReferences = @(); $hasAuthenticationContextRules = $false
        
				foreach ($currentPolicyRule in $policyRules) {
					$currentRuleType = $currentPolicyRule.ruleType ?? $currentPolicyRule.properties.ruleType
					$isCurrentRuleEnabled = [bool]($currentPolicyRule.isEnabled ?? $currentPolicyRule.properties.isEnabled)
					$currentClaimValue = $currentPolicyRule.claimValue ?? $currentPolicyRule.properties.claimValue
          
					if ($currentRuleType -eq 'RoleManagementPolicyAuthenticationContextRule' -and $isCurrentRuleEnabled -and $currentClaimValue) {
						$hasAuthenticationContextRules = $true
						if ($currentClaimValue -match '^[0-9a-fA-F-]{36}$') { $authenticationContextIds += $currentClaimValue } else { $authenticationContextClassReferences += $currentClaimValue }
						continue
					}
          
					# Check array properties for Authentication Context IDs and Class References
					foreach ($authContextPropertyName in @('authenticationContextIds', 'authenticationContextClassReferences')) {
						$authContextPropertyValues = $currentPolicyRule.$authContextPropertyName ?? $currentPolicyRule.properties.$authContextPropertyName
						if ($authContextPropertyValues) {
							$hasAuthenticationContextRules = $true
							if ($authContextPropertyName -eq 'authenticationContextIds') { $authenticationContextIds += @($authContextPropertyValues) } else { $authenticationContextClassReferences += @($authContextPropertyValues) }
						}
					}
				}
        
				# JSON fallback parsing if structured properties didn't contain Authentication Context data
				if (-not $hasAuthenticationContextRules) {
					$policyRulesJson = $policyRules | ConvertTo-Json -Depth 10 -Compress
					if ($policyRulesJson -match 'authenticationContext') {
						$hasAuthenticationContextRules = $true
						$contextIdMatches = [regex]::Matches($policyRulesJson, '"authenticationContextIds"\s*:\s*\[(.*?)\]')
						foreach ($contextIdMatch in $contextIdMatches) { $authenticationContextIds += ([regex]::Matches($contextIdMatch.Groups[1].Value, '"([0-9a-fA-F-]{36})"') | ForEach-Object { $_.Groups[1].Value }) }
						$contextClassRefMatches = [regex]::Matches($policyRulesJson, '"authenticationContextClassReferences"\s*:\s*\[(.*?)\]')
						foreach ($contextClassRefMatch in $contextClassRefMatches) { $authenticationContextClassReferences += ([regex]::Matches($contextClassRefMatch.Groups[1].Value, '"([^"\\]+)"') | ForEach-Object { $_.Groups[1].Value }) }
					}
				}
        
				if (($authenticationContextIds.Count -eq 0) -and ($authenticationContextClassReferences.Count -eq 0)) { continue }
        
				# Found a policy with Authentication Context - create result object
				$policyScope = $policyProperties.scope ?? $subscriptionScope
				if (-not $policyScope -and $fullPolicyDetails.id -match '^(/subscriptions/[^/]+(?:/resourceGroups/[^/]+)?)') { $policyScope = $Matches[1] }
        
				$resolvedAuthenticationContextNames = @()
				if ($authenticationContextIds) { 
					foreach ($authenticationContextId in $authenticationContextIds) { 
						if ($authenticationContextById.ContainsKey($authenticationContextId)) { 
							$resolvedAuthenticationContextNames += $authenticationContextById[$authenticationContextId] 
						}
						else { 
							$resolvedAuthenticationContextNames += $authenticationContextId 
						} 
					} 
				}
        
				$pimPolicyResults += [pscustomobject]@{
					PolicyId             = $fullPolicyDetails.name
					Scope                = $policyScope
					ScopeType            = $( if ($policyScope -and $policyScope -match '/resourceGroups/') { 'ResourceGroup' } else { 'Subscription' } )
					AuthContextIds       = ($authenticationContextIds | Sort-Object -Unique) -join ','
					AuthContextClassRefs = ($authenticationContextClassReferences | Sort-Object -Unique) -join ','
					AuthContextNames     = ($resolvedAuthenticationContextNames | Sort-Object -Unique) -join ','
					RoleDefinitionId     = $roleDefinitionId
					RoleDisplayName      = $roleDisplayName
					Source               = 'AzureResource'
				}
			}
		}
	}
  
	if (-not $NoProgress) { 
		Write-Progress -Id 8 -Activity 'Azure PIM: Policies' -Completed
		Write-Progress -Id 7 -Activity 'Azure PIM: Subscriptions' -Completed
	}

	return $pimPolicyResults
}
