function Get-AccessPackageGraphData {
	<#!
	.SYNOPSIS
		Collects Access Package configuration, resources, policies, and custom extensions from Microsoft Graph.

	.DESCRIPTION
		Uses Microsoft Graph Identity Governance endpoints (beta where required) to retrieve access packages with
		assignment policies, resource role scopes, approval settings, requestor settings, verified ID requirements,
		and custom extension stage settings. Returns a PSCustomObject containing raw data collections.

	.PARAMETER QuietMode
		Suppress console output.

	.OUTPUTS
		PSCustomObject with AccessPackages, CustomExtensionsByPolicy, and RetrievalTimestamp.
	#>
	[CmdletBinding()] param([switch]$QuietMode, [bool]$IncludeBeta = $true, [string]$TenantId, [string]$ClientId)
	$null = $IncludeBeta

	if (-not (Import-GraphEntitlementModules -QuietMode:$QuietMode)) {
		throw 'Unable to load Microsoft Graph modules required for Entitlement Management.'
	}

	$extraScopes = @('Directory.Read.All', 'RoleManagement.Read.Directory', 'Sites.Read.All')
	if (-not (Connect-GraphEntitlementSafe -QuietMode:$QuietMode -TenantId:$TenantId -ClientId:$ClientId -AdditionalScopes $extraScopes)) {
		throw 'Unable to connect to Microsoft Graph with Entitlement Management scopes.'
	}

	$timestamp = Get-Date -AsUTC
	if (-not $QuietMode) { Write-Host "[Access Packages] Retrieving access packages and policies (v1.0 REST)..." -ForegroundColor Cyan }

	# Build REST query (v1.0). We only expand catalog here; policies/resources are collected separately
	# with batching for performance.
	$expand = 'catalog'
	$uri = "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/accessPackages?%24expand=$expand"

	$packages = @()
	try {
		$packages = Invoke-GraphPagedRequest -StartUri $uri -QuietMode:$QuietMode
	}
	catch {
		$err = $_
		$status = $null; $body = $null
		try { if ($err.Exception.Response) { $status = $err.Exception.Response.StatusCode.value__ } } catch { Write-Verbose 'Failed to read status code from exception response.' }
		try { if ($err.ErrorDetails.Message) { $body = $err.ErrorDetails.Message } } catch { Write-Verbose 'Failed to read error details message from exception.' }
		if ($status -eq 403) {
			$ctx = Get-MgContext -ErrorAction SilentlyContinue
			$acct = $ctx.Account
			$scopeList = if ($ctx.Scopes) { $ctx.Scopes -join ', ' } else { 'unknown' }
			Write-ModuleLog -Message "Graph call forbidden. Ensure EntitlementManagement.Read.All (delegated) is granted and admin consented, and the signed-in account has permission to the catalog (e.g., Access Package Reader/Manager, Identity Governance Admin, or Global Reader). Account: $acct Scopes: $scopeList" -Level Error
		}
		throw "Failed to retrieve access packages: $($err.Exception.Message). Status: $status. Body: $body"
	}

	# ----------------------------
	# Assignment policy collection
	# ----------------------------
	if (-not $QuietMode) { Write-Host "[Access Packages] Retrieving assignment policies (batched)..." -ForegroundColor Cyan }

	# 1) List base policies per package using Graph $batch (20 packages/request)
	$policyListRequests = @()
	foreach ($pkg in $packages) {
		if (-not $pkg.Id) { continue }
		$filter = [uri]::EscapeDataString("accessPackage/id eq '$($pkg.Id)'")
		$policyListRequests += @{
			id = $pkg.Id
			method = 'GET'
			url = "/identityGovernance/entitlementManagement/assignmentPolicies?`$filter=$filter"
		}
	}

	$basePoliciesByPackage = @{}
	if ($policyListRequests.Count -gt 0) {
		$responses = Invoke-GraphBatch -Requests $policyListRequests -BatchEndpointVersion 'v1.0' -QuietMode:$QuietMode
		foreach ($r in $responses) {
			$pkgId = $r.id
			if (-not $basePoliciesByPackage.ContainsKey($pkgId)) { $basePoliciesByPackage[$pkgId] = @() }
			if ($r.status -eq 200 -and $r.body -and $r.body.value) {
				$basePoliciesByPackage[$pkgId] = @($r.body.value | ForEach-Object { ConvertTo-PSCustomObjectRecursive $_ })
			}
			else {
				# keep empty; don't throw to avoid killing report on one package
				if ($r.status -and -not $QuietMode) {
					Write-ModuleLog -Message "Policy list failed for package $pkgId (HTTP $($r.status))." -Level Warning
				}
			}
		}
	}

	# 2) Fetch detailed policy records (questions/requestApprovalSettings/etc.) using Graph $batch
	$allBasePolicies = @()
	foreach ($pkgId in $basePoliciesByPackage.Keys) {
		$allBasePolicies += @($basePoliciesByPackage[$pkgId])
	}
	$policyIds = @($allBasePolicies | Where-Object { $_.Id } | Select-Object -ExpandProperty Id -Unique)

	$policyDetailsById = @{}
	if ($policyIds.Count -gt 0) {
		# Use assignmentPolicies for policy detail retrieval.
		# This endpoint supports expanding customExtensionStageSettings with the linked customExtension (v1.0).
		$policyDetailExpand = "?`$expand=customExtensionStageSettings(`$expand=customExtension)"
		$detailRequests = @(
			$policyIds | ForEach-Object {
				@{ id = $_; method = 'GET'; url = "/identityGovernance/entitlementManagement/assignmentPolicies/$($_)$policyDetailExpand" }
			}
		)
		$detailResponses = Invoke-GraphBatch -Requests $detailRequests -BatchEndpointVersion 'v1.0' -QuietMode:$QuietMode
		foreach ($dr in $detailResponses) {
			if ($dr.status -eq 200 -and $dr.body) {
				$policyDetailsById[$dr.id] = (ConvertTo-PSCustomObjectRecursive $dr.body)
			}
		}
	}

	# 3) Attach detailed policies back to packages (preserve contract: always set AssignmentPolicies array)
	foreach ($pkg in $packages) {
		if (-not $pkg.Id) { continue }
		$pols = @()
		if ($basePoliciesByPackage.ContainsKey($pkg.Id)) {
			foreach ($bp in @($basePoliciesByPackage[$pkg.Id])) {
				if ($bp.Id -and $policyDetailsById.ContainsKey($bp.Id)) { $pols += $policyDetailsById[$bp.Id] }
				else { $pols += $bp }
			}
		}
		# PSCustomObject cannot add new properties via assignment; use Add-Member with -Force.
		$pkg | Add-Member -MemberType NoteProperty -Name 'AssignmentPolicies' -Value @($pols) -Force
	}

	# 4) Enrich specificAllowedTargets using directoryObjects/getByIds (bulk)
	$targetIds = @()
	foreach ($pkg in $packages) {
		foreach ($policy in @($pkg.AssignmentPolicies)) {
			$targets = $policy.specificAllowedTargets
			if (-not $targets) { continue }
			foreach ($t in @($targets)) {
				if ($t.'@odata.type' -eq '#microsoft.graph.singleUser' -and $t.userId) { $targetIds += $t.userId }
				elseif ($t.'@odata.type' -eq '#microsoft.graph.groupMembers' -and $t.groupId) { $targetIds += $t.groupId }
			}
		}
	}
	$dirObjMap = @{}
	if ($targetIds.Count -gt 0) {
		$dirObjMap = Resolve-DirectoryObjectsByIds -Ids $targetIds -QuietMode:$QuietMode
	}

	if ($dirObjMap.Count -gt 0) {
		foreach ($pkg in $packages) {
			foreach ($policy in @($pkg.AssignmentPolicies)) {
				$targets = $policy.specificAllowedTargets
				if (-not $targets) { continue }
				$enriched = @()
				foreach ($t in @($targets)) {
					if ($t.'@odata.type' -eq '#microsoft.graph.singleUser' -and $t.userId -and $dirObjMap.ContainsKey($t.userId)) {
						$u = $dirObjMap[$t.userId]
						$t | Add-Member -MemberType NoteProperty -Name 'displayName' -Value $u.displayName -Force
						$t | Add-Member -MemberType NoteProperty -Name 'userPrincipalName' -Value $u.userPrincipalName -Force
						$t | Add-Member -MemberType NoteProperty -Name 'id' -Value $u.id -Force
					}
					elseif ($t.'@odata.type' -eq '#microsoft.graph.groupMembers' -and $t.groupId -and $dirObjMap.ContainsKey($t.groupId)) {
						$g = $dirObjMap[$t.groupId]
						# Preserve existing converter behavior which reads 'description' for groups.
						$t | Add-Member -MemberType NoteProperty -Name 'description' -Value $g.displayName -Force
						$t | Add-Member -MemberType NoteProperty -Name 'displayName' -Value $g.displayName -Force
						$t | Add-Member -MemberType NoteProperty -Name 'id' -Value $g.id -Force
					}
					$enriched += $t
				}
				$policy.specificAllowedTargets = $enriched
			}
		}
	}

	# 5) Enrich approval stage approvers using directoryObjects/getByIds (bulk)
	$approverIds = @()
	foreach ($pkg in $packages) {
		foreach ($policy in @($pkg.AssignmentPolicies)) {
			# Get approval settings from multiple possible property names
			$approvalSettings = $policy.ApprovalSettings
			if (-not $approvalSettings) { $approvalSettings = $policy.requestApprovalSettings }
			if (-not $approvalSettings) { $approvalSettings = $policy.RequestApprovalSettings }
			if (-not $approvalSettings) { continue }

			# Get approval stages from multiple possible property names
			$approvalStages = @()
			if ($approvalSettings.ApprovalStages) { $approvalStages = @($approvalSettings.ApprovalStages) }
			elseif ($approvalSettings.stages) { $approvalStages = @($approvalSettings.stages) }
			
			foreach ($stage in $approvalStages) {
				# Extract approver lists from all three possible properties
				$approverLists = @()
				if ($stage.PrimaryApprovers) { $approverLists += @($stage.PrimaryApprovers) }
				elseif ($stage.primaryApprovers) { $approverLists += @($stage.primaryApprovers) }
				
				if ($stage.BackupApprovers) { $approverLists += @($stage.BackupApprovers) }
				elseif ($stage.fallbackPrimaryApprovers) { $approverLists += @($stage.fallbackPrimaryApprovers) }
				elseif ($stage.backupApprovers) { $approverLists += @($stage.backupApprovers) }
				
				if ($stage.EscalationApprovers) { $approverLists += @($stage.EscalationApprovers) }
				elseif ($stage.escalationApprovers) { $approverLists += @($stage.escalationApprovers) }

				foreach ($approverList in $approverLists) {
					foreach ($approver in @($approverList)) {
						if ($approver.'@odata.type' -eq '#microsoft.graph.singleUser' -and $approver.userId) { 
							$approverIds += $approver.userId 
						}
						elseif ($approver.'@odata.type' -eq '#microsoft.graph.groupMembers' -and $approver.groupId) { 
							$approverIds += $approver.groupId 
						}
					}
				}
			}
		}
	}

	$approverObjMap = @{}
	if ($approverIds.Count -gt 0) {
		$approverObjMap = Resolve-DirectoryObjectsByIds -Ids $approverIds -QuietMode:$QuietMode
	}

	if ($approverObjMap.Count -gt 0) {
		foreach ($pkg in $packages) {
			foreach ($policy in @($pkg.AssignmentPolicies)) {
				# Get approval settings from multiple possible property names
				$approvalSettings = $policy.ApprovalSettings
				if (-not $approvalSettings) { $approvalSettings = $policy.requestApprovalSettings }
				if (-not $approvalSettings) { $approvalSettings = $policy.RequestApprovalSettings }
				if (-not $approvalSettings) { continue }

				# Get approval stages from multiple possible property names
				$approvalStages = @()
				if ($approvalSettings.ApprovalStages) { $approvalStages = @($approvalSettings.ApprovalStages) }
				elseif ($approvalSettings.stages) { $approvalStages = @($approvalSettings.stages) }
				
				foreach ($stage in $approvalStages) {
					# Helper function to enrich an approver list
					$enrichApproverList = {
						param($approverList)
						if (-not $approverList) { return @() }
						$enriched = @()
						foreach ($approver in @($approverList)) {
							if ($approver.'@odata.type' -eq '#microsoft.graph.singleUser' -and $approver.userId -and $approverObjMap.ContainsKey($approver.userId)) {
								$u = $approverObjMap[$approver.userId]
								$approver | Add-Member -MemberType NoteProperty -Name 'displayName' -Value $u.displayName -Force
								$approver | Add-Member -MemberType NoteProperty -Name 'userPrincipalName' -Value $u.userPrincipalName -Force
								$approver | Add-Member -MemberType NoteProperty -Name 'id' -Value $u.id -Force
							}
							elseif ($approver.'@odata.type' -eq '#microsoft.graph.groupMembers' -and $approver.groupId -and $approverObjMap.ContainsKey($approver.groupId)) {
								$g = $approverObjMap[$approver.groupId]
								$approver | Add-Member -MemberType NoteProperty -Name 'description' -Value $g.displayName -Force
								$approver | Add-Member -MemberType NoteProperty -Name 'displayName' -Value $g.displayName -Force
								$approver | Add-Member -MemberType NoteProperty -Name 'id' -Value $g.id -Force
							}
							$enriched += $approver
						}
						return $enriched
					}

					# Enrich all three approver properties
					if ($stage.PrimaryApprovers) { 
						$stage.PrimaryApprovers = & $enrichApproverList $stage.PrimaryApprovers 
					}
					elseif ($stage.primaryApprovers) { 
						$stage.primaryApprovers = & $enrichApproverList $stage.primaryApprovers 
					}
					
					if ($stage.BackupApprovers) { 
						$stage.BackupApprovers = & $enrichApproverList $stage.BackupApprovers 
					}
					elseif ($stage.fallbackPrimaryApprovers) { 
						$stage.fallbackPrimaryApprovers = & $enrichApproverList $stage.fallbackPrimaryApprovers 
					}
					elseif ($stage.backupApprovers) { 
						$stage.backupApprovers = & $enrichApproverList $stage.backupApprovers 
					}
					
					if ($stage.EscalationApprovers) { 
						$stage.EscalationApprovers = & $enrichApproverList $stage.EscalationApprovers 
					}
					elseif ($stage.escalationApprovers) { 
						$stage.escalationApprovers = & $enrichApproverList $stage.escalationApprovers 
					}
				}
			}
		}
	}

	# If no packages returned, surface a warning with context to aid troubleshooting
	if (-not $packages -or $packages.Count -eq 0) {
		$ctx = Get-MgContext -ErrorAction SilentlyContinue
		$acct = $ctx.Account
		$tenant = $ctx.TenantId
		Write-ModuleLog -Message "No access packages returned by Graph. Account: $acct Tenant: $tenant Endpoint: $uri" -Level Warning
	}
	else {
		$pkgCount = $packages.Count
		$policyCount = ($packages | ForEach-Object { $_.AssignmentPolicies } | Where-Object { $_ } | Measure-Object).Count
		if (-not $QuietMode) { Write-Host "   ✓ Retrieved $pkgCount access packages (policies: $policyCount)" -ForegroundColor DarkGreen }
	}

	# ----------------------------
	# Resource role scopes (batched)
	# ----------------------------
	if (-not $QuietMode) { Write-Host "[Access Packages] Retrieving resource role scopes (batched)..." -ForegroundColor Cyan }

	$rrsRequests = @()
	foreach ($pkg in $packages) {
		if (-not $pkg.Id) { continue }
		# Add $top to reduce likelihood of paging (still handle nextLink when it happens)
		$rrsRequests += @{
			id = $pkg.Id
			method = 'GET'
			url = "/identityGovernance/entitlementManagement/accessPackages/$($pkg.Id)/resourceRoleScopes?`$top=999&`$expand=role(`$expand=resource),scope(`$expand=resource)"
		}
	}

	$rrsByPackage = @{}
	if ($rrsRequests.Count -gt 0) {
		$rrsResponses = Invoke-GraphBatch -Requests $rrsRequests -BatchEndpointVersion 'v1.0' -QuietMode:$QuietMode
		foreach ($r in $rrsResponses) {
			$pkgId = $r.id
			$rrsByPackage[$pkgId] = @()
			if ($r.status -eq 200 -and $r.body) {
				if ($r.body.value) {
					$rrsByPackage[$pkgId] = @($r.body.value | ForEach-Object { ConvertTo-PSCustomObjectRecursive $_ })
				}
				# paging fallback (rare, but safe)
				if ($r.body.'@odata.nextLink') {
					try {
						$extra = Invoke-GraphPagedRequest -StartUri $r.body.'@odata.nextLink' -QuietMode:$QuietMode
						if ($extra) { $rrsByPackage[$pkgId] += @($extra) }
					}
					catch {
						Write-ModuleLog -Message "Failed paging additional resource role scopes for package $($pkgId): $($_.Exception.Message)" -Level Warning
					}
				}
			}
			elseif ($r.status -eq 404) {
				$rrsByPackage[$pkgId] = @()
			}
			else {
				if ($r.status -and -not $QuietMode) {
					Write-ModuleLog -Message "Resource role scopes failed for package $pkgId (HTTP $($r.status))." -Level Warning
				}
			}
		}
	}

	foreach ($pkg in $packages) {
		if (-not $pkg.Id) { continue }
		$scopes = if ($rrsByPackage.ContainsKey($pkg.Id)) { @($rrsByPackage[$pkg.Id]) } else { @() }
		$pkg | Add-Member -MemberType NoteProperty -Name 'accessPackageResourceRoleScopes' -Value $scopes -Force
	}

	# ----------------------------
	# Service principal enrichment (batched)
	# ----------------------------
	$spIds = @()
	foreach ($pkg in $packages) {
		foreach ($rrs in @($pkg.accessPackageResourceRoleScopes)) {
			$role = $rrs.role
			$resource = $role.resource
			if (-not $resource) { continue }
			if ($resource.originSystem -eq 'AadApplication' -or $resource.originSystem -eq 'AadServicePrincipal') {
				if ($resource.originId) { $spIds += $resource.originId }
			}
		}
	}
	$spIds = @($spIds | Where-Object { $_ } | Select-Object -Unique)

	$spById = @{}
	if ($spIds.Count -gt 0) {
		$spRequests = @(
			$spIds | ForEach-Object {
				@{ id = $_; method = 'GET'; url = "/servicePrincipals/$($_)?`$select=displayName,appRoles" }
			}
		)
		$spResponses = Invoke-GraphBatch -Requests $spRequests -BatchEndpointVersion 'v1.0' -QuietMode:$QuietMode
		foreach ($sr in $spResponses) {
			if ($sr.status -eq 200 -and $sr.body) {
				$spById[$sr.id] = (ConvertTo-PSCustomObjectRecursive $sr.body)
			}
		}
	}

	foreach ($pkg in $packages) {
		foreach ($rrs in @($pkg.accessPackageResourceRoleScopes)) {
			$role = $rrs.role
			$resource = $role.resource
			if (-not $resource) { continue }
			if ($resource.originSystem -eq 'AadApplication' -or $resource.originSystem -eq 'AadServicePrincipal') {
				$spId = $resource.originId
				if (-not $spId -or -not $spById.ContainsKey($spId)) { continue }
				$sp = $spById[$spId]
				if ($sp.displayName) { $resource.displayName = $sp.displayName }

				# map role display if possible
				$roleIdCandidate = $null
				if ($role.originId) { $roleIdCandidate = $role.originId }
				elseif ($role.roleId) { $roleIdCandidate = $role.roleId }
				elseif ($role.id) { $roleIdCandidate = $role.id }
				if ($roleIdCandidate -and $sp.appRoles) {
					$matched = @($sp.appRoles | Where-Object { $_.id -eq $roleIdCandidate } | Select-Object -First 1)
					if ($matched -and $matched.displayName) { $role.displayName = $matched.displayName }
				}
			}
		}
	}

	# Summarize resource role scopes and custom extensions
	if (-not $QuietMode) {
		$resourceCount = ($packages | ForEach-Object { $_.accessPackageResourceRoleScopes } | Where-Object { $_ } | Measure-Object).Count
		Write-Host "   ✓ Resources discovered: $resourceCount" -ForegroundColor DarkGreen
	}

	# ----------------------------
	# Custom extensions (v1.0)
	# ----------------------------
	# In this tenant, Graph v1.0 does not expose customExtensionHandlers, but it DOES support
	# customExtensionStageSettings when expanded on accessPackageAssignmentPolicies.
	$policyExtensions = @{}
	$allPolicies = @(
		$packages | ForEach-Object { $_.AssignmentPolicies } | Where-Object { $_ -and $_.Id }
	)
	$allPolicyIds = @($allPolicies | ForEach-Object { $_.Id } | Select-Object -Unique)
	foreach ($policyId in $allPolicyIds) { $policyExtensions[$policyId] = @() }

	foreach ($policy in $allPolicies) {
		$stageSettingsProp = $policy.PSObject.Properties | Where-Object { $_.Name -eq 'customExtensionStageSettings' -or $_.Name -eq 'CustomExtensionStageSettings' } | Select-Object -First 1
		if ($stageSettingsProp -and $stageSettingsProp.Value) {
			$policyExtensions[$policy.Id] = ConvertTo-PolicyCustomExtensions -PolicyId $policy.Id -StageSettings @($stageSettingsProp.Value)
		}
	}
	
	if (-not $QuietMode) {
		# Count unique custom extensions by their Id, not total references across policies
		$allExtensions = $policyExtensions.Values | ForEach-Object { $_ } | Where-Object { $_ -and $_.customExtension }
		$uniqueExtIds = $allExtensions | ForEach-Object { $_.customExtension.id } | Where-Object { $_ } | Select-Object -Unique
		$extCount = ($uniqueExtIds | Measure-Object).Count
		Write-Host "   ✓ Custom extensions discovered: $extCount" -ForegroundColor DarkGreen
	}

	# ----------------------------
	# Separation of Duty (SoD) - Incompatible Access Packages
	# ----------------------------
	$incompatiblePackages = @()
	if (-not $QuietMode) { Write-Host "[Access Packages] Retrieving separation of duty (incompatible packages)..." -ForegroundColor Cyan }
	
	try {
		# Query each access package for its incompatible relationships
		foreach ($pkg in $packages) {
			if (-not $pkg.Id) { continue }
			$sodUri = "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/accessPackages/$($pkg.Id)/incompatibleAccessPackages"
			try {
				$incompatible = Invoke-GraphPagedRequest -StartUri $sodUri -QuietMode:$true
				foreach ($incomp in @($incompatible)) {
					if ($incomp.id) {
						$incompatiblePackages += [pscustomobject]@{
							SourcePackageId = $pkg.Id
							TargetPackageId = $incomp.id
						}
					}
				}
			}
			catch {
				# Some tenants may not have SoD configured or may return 404/403
				if (-not $QuietMode) { Write-Host "   Note: Could not retrieve SoD data for package $($pkg.Id): $_" -ForegroundColor Yellow }
			}
		}
		if (-not $QuietMode) {
			$sodCount = ($incompatiblePackages | Measure-Object).Count
			Write-Host "   ✓ Separation of duty conflicts discovered: $sodCount" -ForegroundColor DarkGreen
		}
	}
	catch {
		if (-not $QuietMode) { Write-Host "   ⚠ Separation of duty data collection skipped: $_" -ForegroundColor Yellow }
	}

	# ----------------------------
	# Orphaned Resources - Resources in catalogs not assigned to any active access package
	# ----------------------------
	$orphanedResourcesByCatalog = @{}
	if (-not $QuietMode) { Write-Host "[Access Packages] Identifying orphaned resources in catalogs..." -ForegroundColor Cyan }
	
	try {
		# Get unique catalogs from packages
		$catalogIds = @($packages | Where-Object { $_.Catalog -and $_.Catalog.Id } | ForEach-Object { $_.Catalog.Id } | Select-Object -Unique)
		
		foreach ($catalogId in $catalogIds) {
			$orphanedResourcesByCatalog[$catalogId] = @()
			
			# Get all resources in this catalog
			$catalogResourcesUri = "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/catalogs/$catalogId/resources?`$expand=roles,scopes"
			try {
				$catalogResources = Invoke-GraphPagedRequest -StartUri $catalogResourcesUri -QuietMode:$true
				
				# Build a set of resource IDs that are assigned to ANY access packages in this catalog (regardless of state)
				$assignedResourceIds = @{}
				$packagesInCatalog = @($packages | Where-Object { $_.Catalog -and $_.Catalog.Id -eq $catalogId })
				foreach ($pkg in $packagesInCatalog) {
					foreach ($rrs in @($pkg.accessPackageResourceRoleScopes)) {
						if ($rrs.role -and $rrs.role.resource -and $rrs.role.resource.id) {
							$assignedResourceIds[$rrs.role.resource.id] = $true
						}
					}
				}
				
				# Identify orphaned resources (in catalog but not assigned to any active package)
				foreach ($catalogResource in @($catalogResources)) {
					if (-not $catalogResource.id) { continue }
					if (-not $assignedResourceIds.ContainsKey($catalogResource.id)) {
						# This resource is orphaned
						$orphanedResourcesByCatalog[$catalogId] += $catalogResource
					}
				}
			}
			catch {
				if (-not $QuietMode) { Write-Host "   Note: Could not retrieve catalog resources for catalog $catalogId : $_" -ForegroundColor Yellow }
			}
		}
		
		if (-not $QuietMode) {
			$orphanedCount = ($orphanedResourcesByCatalog.Values | ForEach-Object { $_ } | Measure-Object).Count
			Write-Host "   ✓ Orphaned resources identified: $orphanedCount" -ForegroundColor DarkGreen
		}
	}
	catch {
		if (-not $QuietMode) { Write-Host "   ⚠ Orphaned resource identification skipped: $_" -ForegroundColor Yellow }
	}

	return [pscustomobject]@{
		AccessPackages             = $packages
		CustomExtensionsByPolicy   = $policyExtensions
		IncompatibleAccessPackages = $incompatiblePackages
		OrphanedResourcesByCatalog = $orphanedResourcesByCatalog
		RetrievedAtUtc             = $timestamp
	}
}
