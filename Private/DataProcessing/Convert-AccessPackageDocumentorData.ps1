function Convert-AccessPackageDocumentorData {
	<#!
	.SYNOPSIS
		Transforms raw access package data into a Documentor-friendly node/edge structure with detail payloads.

	.DESCRIPTION
		Creates Cytoscape-ready nodes and edges to visualize relationships between access packages, policies,
		resources, approval stages, custom extensions, verified ID requirements, and requestor justification rules.

	.PARAMETER AccessPackageData
		PSCustomObject returned by Get-AccessPackageGraphData.

	.OUTPUTS
		PSCustomObject with Nodes, Edges, and Stats properties ready for HTML rendering.
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][psobject]$AccessPackageData
	)

	$nodes = @()
	$edges = @()
	$resourceMap = @{}
	$catalogMap = @{}
	$uncatId = 'cat-uncategorized'

	if (-not $AccessPackageData.AccessPackages -or $AccessPackageData.AccessPackages.Count -eq 0) {
		$stats = [pscustomobject]@{ PackageCount = 0; PolicyCount = 0; ResourceCount = 0; CatalogCount = 0 }
		return [pscustomobject]@{ Nodes = $nodes; Edges = $edges; Stats = $stats }
	}

	foreach ($pkg in $AccessPackageData.AccessPackages) {
		# Catalog node (deduplicated)
		$catalogId = $pkg.Catalog?.Id
		if ($catalogId) {
			$catNodeId = "cat-$catalogId"
			if (-not $catalogMap.ContainsKey($catNodeId)) {
				$catalogMap[$catNodeId] = $true
				$nodes += [pscustomobject]@{
					id    = $catNodeId
					label = $pkg.Catalog.DisplayName
					type  = 'catalog'
					data  = @{
						description = $pkg.Catalog.Description
						catalogId   = $pkg.Catalog.Id
					}
				}
			}
		} else {
			if (-not $catalogMap.ContainsKey($uncatId)) {
				$catalogMap[$uncatId] = $true
				$nodes += [pscustomobject]@{
					id    = $uncatId
					label = 'Uncatalogued'
					type  = 'catalog'
					data  = @{}
				}
			}
			$catNodeId = $uncatId
		}

		$pkgId = "ap-$($pkg.Id)"
		$nodes += [pscustomobject]@{
			id    = $pkgId
			label = $pkg.DisplayName
			type  = 'package'
			data  = @{
				description = $pkg.Description
				catalog     = if ($pkg.Catalog) { $pkg.Catalog.DisplayName } else { $null }
				catalogId   = if ($pkg.Catalog) { $pkg.Catalog.Id } else { $null }
			}
		}
		$edges += [pscustomobject]@{ id = "edge-$catNodeId-$pkgId"; source = $catNodeId; target = $pkgId; type = 'contains' }

		# Group node: Policies
		$polGroupId = "polgrp-$($pkg.Id)"
		$policyList = @($pkg.AssignmentPolicies | Where-Object { $_ })
		$nodes += [pscustomobject]@{
			id    = $polGroupId
			label = "Policies ($($policyList.Count))"
			type  = 'policy-group'
			data  = @{
				packageName = $pkg.DisplayName
				count       = $policyList.Count
			}
		}
		$edges += [pscustomobject]@{ id = "edge-$pkgId-$polGroupId"; source = $pkgId; target = $polGroupId; type = 'group' }

		# Group node: Resources
		$resGroupId = "resgrp-$($pkg.Id)"
		$resourceList = @($pkg.accessPackageResourceRoleScopes | Where-Object { $_ })
		$nodes += [pscustomobject]@{
			id    = $resGroupId
			label = "Resources ($($resourceList.Count))"
			type  = 'resource-group'
			data  = @{
				packageName = $pkg.DisplayName
				count       = $resourceList.Count
			}
		}
		$edges += [pscustomobject]@{ id = "edge-$pkgId-$resGroupId"; source = $pkgId; target = $resGroupId; type = 'group' }

		# Resources (children of the Resources group node)
		foreach ($rrs in $resourceList) {
			$role = $rrs.role
			$scope = $rrs.scope
			$resource = $role.resource
			$typeLabel = Get-AccessPackageResourceTypeLabel -Resource $resource

			$resLabel = if ($resource.displayName) { $resource.displayName } else { $resource.originId }
			$roleDisplay = if ($role.displayName) { $role.displayName } else { $role.originId }
			$originSys = $resource.originSystem

			$nodeId = "res-$($pkg.Id)-$($rrs.id)"
			if (-not $resourceMap.ContainsKey($nodeId)) {
				$resourceMap[$nodeId] = $true
				$sharedKey = "{0}|{1}|{2}" -f $originSys, $resource.originId, $resource.resourceType
				$nodes += [pscustomobject]@{
					id    = $nodeId
					label = "${typeLabel}: $resLabel ($roleDisplay)"
					type  = 'resource'
					data  = @{
						name           = $resLabel
						type           = $resource.resourceType
						typeLabel      = $typeLabel
						originSystem   = $originSys
						originId       = $resource.originId
						resourceId     = $resource.id
						roleDisplay    = $roleDisplay
						roleId         = $role.id
						assignmentType = $scope.originId
						scope          = $scope.displayName
						scopeId        = $scope.id
						sharedKey      = $sharedKey
					}
				}
			}
			$edges += [pscustomobject]@{ id = "edge-$resGroupId-$nodeId"; source = $resGroupId; target = $nodeId; type = 'resource' }
		}

		# Policies (children of the Policies group node)
		foreach ($policy in $policyList) {
			$polId = "pol-$($policy.Id)"
			# Derive audience prefix from allowedTargetScope (case-insensitive)
			$targetScope = @($policy.AllowedTargetScope | ForEach-Object { $_.ToString().ToLower() })
			$audiencePrefix = 'Admin Only: '
			if (-not $targetScope -or $targetScope.Count -eq 0 -or $targetScope -contains 'none' -or $targetScope -contains 'notspecified') {
				$audiencePrefix = 'Admin Only: '
			}
			elseif ($targetScope -like '*connectedorganization*') {
				$audiencePrefix = 'External: '
			}
			else {
				# Default to Internal for any in-tenant targets (allDirectory*, allUsers*, allPrincipals*, allMembers*, etc.)
				$audiencePrefix = 'Internal: '
			}

			# Normalize approval settings across legacy and current property names
			$approvalSettings = $policy.ApprovalSettings
			if (-not $approvalSettings) { $approvalSettings = $policy.requestApprovalSettings }
			if (-not $approvalSettings) { $approvalSettings = $policy.RequestApprovalSettings }

			$requestorJustification = $policy.RequestorSettings?.RequestsJustificationRequired
			if ($null -eq $requestorJustification -and $approvalSettings) {
				$requestorJustification = $approvalSettings.isRequestorJustificationRequired
			}
			
			# Extract questions - check both camelCase and PascalCase, use PSObject.Properties for reliability
			$questionsArray = @()
			$questionsProperty = $policy.PSObject.Properties | Where-Object { $_.Name -eq 'questions' -or $_.Name -eq 'Questions' } | Select-Object -First 1
			if ($questionsProperty -and $questionsProperty.Value) {
				$questionsArray = @($questionsProperty.Value)
			}
			
			# Extract specificAllowedTargets - check both camelCase and PascalCase
			$targetsArray = @()
			$targetsProperty = $policy.PSObject.Properties | Where-Object { $_.Name -eq 'specificAllowedTargets' -or $_.Name -eq 'SpecificAllowedTargets' } | Select-Object -First 1
			if ($targetsProperty -and $targetsProperty.Value) {
				$targetsArray = @($targetsProperty.Value)
			}
			
			$nodes += [pscustomobject]@{
				id    = $polId
				label = "$audiencePrefix$($policy.DisplayName)"
				type  = 'policy'
				data  = @{
					description             = $policy.Description
					durationInDays          = $policy.DurationInDays
					requestorSettings       = $policy.RequestorSettings
					requestorJustification  = $requestorJustification
					requestApprovalSettings = $approvalSettings
					verificationSettings    = $policy.RequestorSettings?.VerifiableCredentialSettings
					questions               = $questionsArray
					approvalSettings        = $approvalSettings
					allowedTargetScope      = $policy.AllowedTargetScope
					audiencePrefix          = $audiencePrefix.Trim()
					specificAllowedTargets  = $targetsArray
					reviewSettings          = $policy.ReviewSettings
					schedule                = $policy.Schedule
					expiration              = $policy.Expiration
					automaticRequestSettings = $policy.AutomaticRequestSettings
					notificationSettings    = $policy.NotificationSettings
					assignmentRequirements  = $policy.Requirements
				}
			}
			$edges += [pscustomobject]@{ id = "edge-$polGroupId-$polId"; source = $polGroupId; target = $polId; type = 'policy' }

			# Approval stages
			$approvalStages = @()
			if ($approvalSettings) {
				if ($approvalSettings.ApprovalStages) { $approvalStages = @($approvalSettings.ApprovalStages) }
				elseif ($approvalSettings.stages) { $approvalStages = @($approvalSettings.stages) }
			}
			if ($approvalStages.Count -gt 0) {
				$stageIndex = 0
				$prevStageId = $null
				foreach ($stage in $approvalStages) {
					$stageIndex++
					$stageId = "appr-$($policy.Id)-$stageIndex"
					$nodes += [pscustomobject]@{
						id    = $stageId
						label = "Approval Stage $stageIndex"
						type  = 'approval-stage'
					data  = @{
							primaryApprovers        = if ($stage.PrimaryApprovers -or $stage.primaryApprovers) { @($stage.PrimaryApprovers ?? $stage.primaryApprovers) } else { @() }
							backupApprovers         = if ($stage.BackupApprovers -or $stage.fallbackPrimaryApprovers -or $stage.backupApprovers) { @($stage.BackupApprovers ?? $stage.fallbackPrimaryApprovers ?? $stage.backupApprovers) } else { @() }
							escalationApprovers     = if ($stage.EscalationApprovers -or $stage.escalationApprovers) { @($stage.EscalationApprovers ?? $stage.escalationApprovers) } else { @() }
							approvalMode            = $stage.ApprovalStageTimeOutBehavior ?? $stage.durationBeforeAutomaticDenial
							approvalStageTimeOutInDays = $stage.DurationBeforeAutomaticDenialInDays ?? $stage.approvalStageTimeOutInDays ?? $stage.durationBeforeAutomaticDenial
							isApproverJustificationRequired = $stage.IsApproverJustificationRequired ?? $stage.isApproverJustificationRequired
							isEscalationEnabled     = $stage.IsEscalationEnabled ?? $stage.isEscalationEnabled
							escalationTimeInMinutes = $stage.EscalationTimeInMinutes ?? $stage.escalationTimeInMinutes
							escalationTimeInDays    = if (($stage.EscalationTimeInMinutes -ne $null) -or ($stage.escalationTimeInMinutes -ne $null)) { 
								[math]::Round(($stage.EscalationTimeInMinutes ?? $stage.escalationTimeInMinutes) / 1440, 2) 
							} elseif (($stage.EscalationTimeInDays -ne $null) -or ($stage.escalationTimeInDays -ne $null)) {
								$stage.EscalationTimeInDays ?? $stage.escalationTimeInDays
							} else { 
								$null 
							}
							escalationTime          = $stage.EscalationTime ?? $stage.escalationTime
							durationBeforeEscalation = $stage.DurationBeforeEscalation ?? $stage.durationBeforeEscalation
						}
					}
					if ($stageIndex -eq 1) {
						$edges += [pscustomobject]@{ id = "edge-$polId-$stageId"; source = $polId; target = $stageId; type = 'approval' }
					} elseif ($prevStageId) {
						$edges += [pscustomobject]@{ id = "edge-$prevStageId-$stageId"; source = $prevStageId; target = $stageId; type = 'approval-seq' }
					}
					$prevStageId = $stageId
				}
			}

			# Custom extensions (beta when available)
			if ($AccessPackageData.CustomExtensionsByPolicy.ContainsKey($policy.Id)) {
				$extSet = $AccessPackageData.CustomExtensionsByPolicy[$policy.Id]
				if ($extSet) {
					foreach ($ext in $extSet) {
						$extId = "ext-$($policy.Id)-$($ext.id)"
						$nodes += [pscustomobject]@{
							id    = $extId
							label = $ext.customExtension?.displayName
							type  = 'custom-extension'
							data  = @{
								stage             = $ext.stage
								customExtensionId = $ext.customExtension?.id
								condition         = $ext.customExtension?.clientConfiguration?.timeoutDuration
								# Include full custom extension object for richer client-side rendering
								customExtension   = if ($ext.customExtension) { $ext.customExtension } else { $null }
							}
						}
						$edges += [pscustomobject]@{ id = "edge-$polId-$extId"; source = $polId; target = $extId; type = 'custom-extension' }
					}
				}
			}
		}
	}

	$extCount = 0
	if ($AccessPackageData.CustomExtensionsByPolicy) {
		# Count unique custom extensions by their Id, not total references across policies
		$allExtensions = $AccessPackageData.CustomExtensionsByPolicy.Values | ForEach-Object { $_ } | Where-Object { $_ -and $_.customExtension }
		$uniqueExtIds = $allExtensions | ForEach-Object { $_.customExtension.id } | Where-Object { $_ } | Select-Object -Unique
		$extCount = ($uniqueExtIds | Measure-Object).Count
	}

	# ----------------------------
	# Orphaned Resources - Resources in catalog but not assigned to any active access package
	# ----------------------------
	$orphanedResourceCount = 0
	if ($AccessPackageData.OrphanedResourcesByCatalog) {
		foreach ($catalogId in $AccessPackageData.OrphanedResourcesByCatalog.Keys) {
			$orphanedResources = @($AccessPackageData.OrphanedResourcesByCatalog[$catalogId])
			if ($orphanedResources.Count -eq 0) { continue }
			
			$catNodeId = "cat-$catalogId"
			# Only add orphaned resources if the catalog node exists
			if (-not $catalogMap.ContainsKey($catNodeId)) { continue }
			
			# Create orphaned resources group node
			$orphanedGroupId = "orphaned-$catalogId"
			$nodes += [pscustomobject]@{
				id    = $orphanedGroupId
				label = "Orphaned Resources ($($orphanedResources.Count))"
				type  = 'orphaned-group'
				data  = @{
					catalogId = $catalogId
					count     = $orphanedResources.Count
				}
			}
			$edges += [pscustomobject]@{ id = "edge-$catNodeId-$orphanedGroupId"; source = $catNodeId; target = $orphanedGroupId; type = 'orphaned' }
			
			# Create individual orphaned resource nodes
			foreach ($orphanedResource in $orphanedResources) {
				if (-not $orphanedResource.id) { continue }
				
				$typeLabel = Get-AccessPackageResourceTypeLabel -Resource $orphanedResource
				$resLabel = if ($orphanedResource.displayName) { $orphanedResource.displayName } else { $orphanedResource.originId }
				
				# Get role information if available
				$roleDisplay = "Unknown Role"
				if ($orphanedResource.roles -and $orphanedResource.roles.Count -gt 0) {
					$firstRole = $orphanedResource.roles[0]
					$roleDisplay = if ($firstRole.displayName) { $firstRole.displayName } else { $firstRole.originId }
				}
				
				$orphanedResId = "orphaned-res-$catalogId-$($orphanedResource.id)"
				$nodes += [pscustomobject]@{
					id    = $orphanedResId
					label = "${typeLabel}: $resLabel ($roleDisplay)"
					type  = 'orphaned-resource'
					data  = @{
						name         = $resLabel
						type         = $orphanedResource.resourceType
						typeLabel    = $typeLabel
						originSystem = $orphanedResource.originSystem
						originId     = $orphanedResource.originId
						resourceId   = $orphanedResource.id
						catalogId    = $catalogId
					}
				}
				$edges += [pscustomobject]@{ id = "edge-$orphanedGroupId-$orphanedResId"; source = $orphanedGroupId; target = $orphanedResId; type = 'orphaned-resource' }
				$orphanedResourceCount++
			}
		}
	}

	# ----------------------------
	# Separation of Duty (SoD) Edges
	# ----------------------------
	if ($AccessPackageData.IncompatibleAccessPackages) {
		$sodPairs = @{}
		# Create a set of valid package IDs for validation
		$validPackageIds = @{}
		foreach ($node in $nodes) {
			if ($node.type -eq 'package') {
				$validPackageIds[$node.id] = $true
			}
		}
		
		foreach ($sod in @($AccessPackageData.IncompatibleAccessPackages)) {
			if (-not $sod.SourcePackageId -or -not $sod.TargetPackageId) { continue }
			
			# Validate both nodes exist before creating edge
			$sourceNodeId = "ap-$($sod.SourcePackageId)"
			$targetNodeId = "ap-$($sod.TargetPackageId)"
			
			if (-not $validPackageIds.ContainsKey($sourceNodeId) -or -not $validPackageIds.ContainsKey($targetNodeId)) {
				# Skip if either package doesn't exist in the current dataset
				continue
			}
			
			# Create bidirectional key to avoid duplicate edges (A-B and B-A are the same)
			$key1 = "$($sod.SourcePackageId)|$($sod.TargetPackageId)"
			$key2 = "$($sod.TargetPackageId)|$($sod.SourcePackageId)"
			
			if (-not $sodPairs.ContainsKey($key1) -and -not $sodPairs.ContainsKey($key2)) {
				$sodPairs[$key1] = $true
				$edges += [pscustomobject]@{
					id     = "sod-$($sod.SourcePackageId)-$($sod.TargetPackageId)"
					source = $sourceNodeId
					target = $targetNodeId
					type   = 'sod-conflict'
				}
			}
		}
	}
	
	$stats = [pscustomobject]@{
		CatalogCount = $catalogMap.Count
		PackageCount = ($AccessPackageData.AccessPackages | Measure-Object).Count
		PolicyCount  = ($AccessPackageData.AccessPackages | ForEach-Object { $_.AssignmentPolicies } | Where-Object { $_ } | Measure-Object).Count
		ResourceCount = $resourceMap.Count
		ExtensionCount = $extCount
		OrphanedResourceCount = $orphanedResourceCount
	}

	return [pscustomobject]@{
		Nodes = $nodes
		Edges = $edges
		Stats = $stats
	}
}
