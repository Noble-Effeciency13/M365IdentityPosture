function Invoke-AuthContextInventoryCore {
	<#
	.SYNOPSIS
		Core orchestration function for authentication context inventory collection.

	.DESCRIPTION
		Coordinates the complete authentication context discovery process across multiple
		Microsoft 365 services including Graph, Azure Resources, Groups, SharePoint, and Purview.
		Collects authentication context usage data and generates comprehensive reports.

	.PARAMETER Quiet
		Suppresses console output and progress indicators.

	.PARAMETER NoProgress
		Disables progress bar display.

	.PARAMETER TenantName
		Specifies the tenant name for the assessment.

	.PARAMETER OutputPath
		Path where output files will be saved.

	.PARAMETER UserPrincipalName
		User principal name for authentication context.

	.PARAMETER HtmlReportPath
		Path for the generated HTML report.

	.PARAMETER HtmlStyle
		CSS style configuration for the HTML report.

	.PARAMETER CredentialEncryptionKey
		Encryption key for credential storage.

	.PARAMETER Credential
		Credential object for authentication.

	.PARAMETER JsonOutputPath
		Path for JSON format output.

	.PARAMETER CsvOutputPath
		Path for CSV format output.

	.PARAMETER IncludeAzure
		Include Azure resource authentication context analysis.

	.PARAMETER IncludeGroups
		Include group-based authentication context analysis.

	.PARAMETER IncludeSharePoint
		Include SharePoint site authentication context analysis.

	.PARAMETER IncludePurview
		Include Microsoft Purview label authentication context analysis.

	.OUTPUTS
		Data object containing comprehensive authentication context inventory.
		
	.EXAMPLE
		Invoke-AuthContextInventoryCore -TenantName "contoso" -OutputPath "C:\Reports"
	#>
	[CmdletBinding()]
	param(
		[switch]$Quiet,
		[switch]$NoProgress,
		[string]$TenantName,
		[string]$OutputPath,
		[string]$UserPrincipalName,
		[string]$HtmlReportPath,
		[string]$HtmlStyle,
		[string]$HtmlLayout,
		[switch]$HtmlAllLayoutThemes,
		[switch]$HtmlAllLayouts,
		[switch]$NoAutoOpen,
		[switch]$ExcludeAzure,
		[string[]]$AzureSubscriptionIds
	)

	#region PowerShell Version Check
	if ($PSVersionTable.PSVersion -lt [version]'7.0') {
		Write-Error @"
This script requires PowerShell 7.0 or later for optimal performance and compatibility.
Current version: $($PSVersionTable.PSVersion)
Required version: 7.0+

Please install PowerShell 7+ from: https://github.com/PowerShell/PowerShell/releases
"@ -ErrorAction Stop
	}
	#endregion

	#region Script Metadata
	# Global script state variables
	$script:ToolVersion = '1.0.0'
	$Global:AuthContextTimestamp = (Get-Date -AsUTC).ToString('yyyyMMdd_HHmmss')
	#endregion

	#region Initialization and Derived Flags
	# Feature flags for optional phases
	$UsePIMAzure = -not $ExcludeAzure

	# Phased authentication state and data containers
	$script:PurviewAuthenticationData = [pscustomobject]@{
		SensitivityLabels         = [System.Collections.Generic.List[object]]::new()
		RawLabelData              = [System.Collections.Generic.List[object]]::new()
		UnifiedGroupsCollection   = [System.Collections.Generic.List[object]]::new()
		IsPurviewConnected        = $false
		IsExchangeOnlineConnected = $false
		ProcessingErrors          = [System.Collections.Generic.List[string]]::new()
	}

	$script:SharePointAuthenticationData = [pscustomobject]@{
		AllSiteCollection              = [System.Collections.Generic.List[object]]::new()
		SitesWithAuthenticationContext = [System.Collections.Generic.List[object]]::new()
		IsSharePointConnected          = $false
		ProcessingErrors               = [System.Collections.Generic.List[string]]::new()
	}

	$script:AzureAuthenticationData = [pscustomobject]@{
		IsAzureConnected = $false
		ProcessingErrors = [System.Collections.Generic.List[string]]::new()
	}

	# Display startup message
	if (-not $Quiet) { 
		Write-Host '══════════════════════════════════════════════════════════════════════════════════════' -ForegroundColor Cyan
		Write-Host "Authentication Context Inventory Report v$script:ToolVersion" -ForegroundColor Cyan
		Write-Host '══════════════════════════════════════════════════════════════════════════════════════' -ForegroundColor Cyan
		Write-Host 'Starting Authentication Context inventory analysis...' -ForegroundColor Green
	}

	# Ensure output directory exists
	if (-not (Test-Path -Path $OutputPath)) {
		if (-not $Quiet) { Write-Host "[Setup] Creating output directory: $OutputPath" -ForegroundColor Yellow }
		New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
	}
	#endregion

	#region Service Connections (Phased)
	if (-not $Quiet) {
		Write-Host "`n[Connection Phase] Starting phased connections..." -ForegroundColor Cyan
		Write-Host '══════════════════════════════════════════════════════════════════════════════════════' -ForegroundColor DarkCyan
	}
	Invoke-Preflight -QuietMode:$Quiet | Out-Null

	if (-not $Quiet) { Write-Host '[Phase 1] Purview Compliance' -ForegroundColor Cyan }
	$null = Invoke-PurviewPhase -QuietMode:$Quiet

	if (-not $Quiet) { Write-Host '[Phase 2] Microsoft Graph' -ForegroundColor Cyan }
	try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}
	$authContexts = Invoke-GraphPhase -QuietMode:$Quiet
	# Populate tenant metadata
	$script:CurrentTenantId = $null; $script:TenantShortName = $null
	$meta = Get-GraphTenantMetadata
	if ($meta) { $script:CurrentTenantId = $meta.TenantId; if (-not $TenantName -and $meta.TenantShortName) { $TenantName = $meta.TenantShortName } }

	if (-not $Quiet) { Write-Host '[Phase 3] SharePoint Online' -ForegroundColor Cyan }
	$null = Invoke-SharePointPhase -TenantName $TenantName -QuietMode:$Quiet

	if (-not $Quiet) { Write-Host '[Phase 4] Azure Resources' -ForegroundColor Cyan }
	$null = Invoke-AzurePhase -QuietMode:$Quiet -AzureSubscriptionIds $AzureSubscriptionIds
	#endregion

	#region Connection Summary
	if (-not $Quiet) {
		Write-Host "`n[Connection Summary]" -ForegroundColor Cyan
		$exStatus = if ($PurviewAuthenticationData.IsExchangeOnlineConnected) { '✓ EXO Loaded (unloaded now)' } else { '✗ EXO Failed' }
		$exColor = if ($PurviewAuthenticationData.IsExchangeOnlineConnected) { 'Green' } else { 'Red' }
		$purvStatus = if ($PurviewAuthenticationData.IsPurviewConnected) { '✓ Labels Retrieved' } else { '✗ Labels Skipped/Failed' }
		$purvColor = if ($PurviewAuthenticationData.IsPurviewConnected) { 'Green' } else { 'Yellow' }
		$graphStatus = if ($graphConnected) { '✓ Connected' } else { '✗ Not Connected' }
		$graphColor = if ($graphConnected) { 'Green' } else { 'Red' }
		$spoStatus = if ($SharePointAuthenticationData.IsSharePointConnected) { '✓ SPO Connected (unloaded)' } else { '✗ SPO Failed/Skipped' }
		$spoColor = if ($SharePointAuthenticationData.IsSharePointConnected) { 'Green' } else { 'Yellow' }
		$azStatus = if ($AzureAuthenticationData.IsAzureConnected) { '✓ Azure Connected (unloaded)' } else { '✗ Azure Skipped/Failed' }
		$azColor = if ($AzureAuthenticationData.IsAzureConnected) { 'Green' } else { 'Yellow' }
		Write-Host ('   Exchange (EXO):      {0}' -f $exStatus) -ForegroundColor $exColor
		Write-Host ('   Purview Labels:      {0}' -f $purvStatus) -ForegroundColor $purvColor
		Write-Host ('   Microsoft Graph:     {0}' -f $graphStatus) -ForegroundColor $graphColor
		Write-Host ('   SharePoint (SPO):    {0}' -f $spoStatus) -ForegroundColor $spoColor
		Write-Host ('   Azure (Accounts):    {0}' -f $azStatus) -ForegroundColor $azColor
		Write-Host '══════════════════════════════════════════════════════════════════════════════════════' -ForegroundColor DarkCyan
	}
	#endregion

	#region Sensitivity Label Analysis
	if (-not $Quiet) { 
		Write-Host "`n[Analysis Phase] Starting data collection and analysis..." -ForegroundColor Cyan 
		Write-Host '══════════════════════════════════════════════════════════════════════════════════════' -ForegroundColor DarkCyan
	}

	$labelsWithContext = @()
	$cachedLabels = $null
	if ($script:AllSensitivityLabels -and ($script:AllSensitivityLabels | Measure-Object).Count -gt 0) {
		$cachedLabels = $script:AllSensitivityLabels
	}
	elseif ($PurviewAuthenticationData.SensitivityLabels -and ($PurviewAuthenticationData.SensitivityLabels | Measure-Object).Count -gt 0) {
		$cachedLabels = $PurviewAuthenticationData.SensitivityLabels
	}

	if ($cachedLabels) {
		if (-not $Quiet) { Write-Host '[1/6] Analyzing sensitivity labels with Authentication Context requirements...' -ForegroundColor Green }
		$labelsWithContext = $cachedLabels | Sort-Object DisplayName
		$labelCount = ($labelsWithContext | Measure-Object).Count
		if ($labelCount -gt 0) {
			if (-not $Quiet) { Write-Host ('   ✓ Found {0} label(s) with Authentication Context requirements' -f $labelCount) -ForegroundColor DarkGreen }
		}
		else {
			if (-not $Quiet) { Write-Host '   ⚠ No labels found with Authentication Context enforcement' -ForegroundColor DarkYellow }
		}
		$labelIdSet = [System.Collections.Generic.HashSet[string]]::new()
		$labelsWithContext | ForEach-Object { if ($_.LabelId) { [void]$labelIdSet.Add([string]$_.LabelId) } }
		$script:LabelToAuthContext = @{}
		foreach ($labelWithAuthContext in $labelsWithContext) {
			if ($labelWithAuthContext.LabelId -and $labelWithAuthContext.AuthContextId) {
				$script:LabelToAuthContext[[string]$labelWithAuthContext.LabelId] = @{ Id = $labelWithAuthContext.AuthContextId; Name = $labelWithAuthContext.AuthContextName }
			}
		}
	}
	elseif ($PurviewAuthenticationData.IsPurviewConnected) {
		if (-not $Quiet) { Write-Host '[1/6] Analyzing sensitivity labels...' -ForegroundColor Green; Write-Host '   ⚠  No sensitivity labels returned from Purview' -ForegroundColor DarkYellow }
		$labelIdSet = [System.Collections.Generic.HashSet[string]]::new(); $labelsWithContext = @()
	}
	else {
		if (-not $Quiet) { Write-Host '[1/6] Skipping sensitivity label analysis (Purview not connected)' -ForegroundColor Yellow }
		$labelIdSet = [System.Collections.Generic.HashSet[string]]::new(); $labelsWithContext = @()
	}
	#endregion

	## SharePoint Site Analysis (cached)
	if (-not $Quiet) { Write-Host '[2/6] Analyzing SharePoint sites for Authentication Context assignments...' -ForegroundColor Green }
	$sharePointSitesRaw = @(); $sharePointSitesWithAuthContext = @(); $siteByGroupId = @{}
	if ($SharePointAuthenticationData.IsSharePointConnected) {
		$sharePointSitesRaw = $SharePointAuthenticationData.AllSiteCollection
		$sharePointSitesWithAuthContext = $SharePointAuthenticationData.SitesWithAuthenticationContext | Select-Object Url, Title, ConditionalAccessPolicy, AuthenticationContextId, AuthenticationContextName, GroupId, @{n = 'Storage (MB)'; e = { $null } } | Sort-Object AuthenticationContextName, Url
		if (-not $sharePointSitesWithAuthContext -or ($sharePointSitesWithAuthContext | Measure-Object).Count -eq 0) {
			if (-not $Quiet) { Write-Host '   ⚠  No sites found with direct Authentication Context assignments' -ForegroundColor DarkYellow }
			Write-Verbose 'No SharePoint sites with direct Authentication Context found (will still attempt inherited mapping).'
		}
		else {
			if (-not $Quiet) { Write-Host ('   ✓ Found {0} site(s) with Authentication Context requirements' -f $sharePointSitesWithAuthContext.Count) -ForegroundColor DarkGreen }
		}

		$siteByGroupId = @{}
		foreach ($sharePointSite in $sharePointSitesRaw) { 
			if ($sharePointSite.GroupId -and $sharePointSite.GroupId -ne [guid]::Empty) { 
				$siteByGroupId[$sharePointSite.GroupId.Guid] = $sharePointSite.Url 
			} 
		}
		if (-not $Quiet -and $siteByGroupId.Count -gt 0) { Write-Host ('   → Mapped {0} sites to Microsoft 365 Groups' -f $siteByGroupId.Count) -ForegroundColor DarkCyan }
	}
	else {
		if (-not $Quiet) { Write-Host '   ⚠ SharePoint phase not connected - skipping site analysis' -ForegroundColor DarkYellow }
		Write-Warning 'SPO phase not connected; skipping site analysis.'
		$siteByGroupId = @{}
	}

	#region Microsoft 365 Groups and Teams Analysis
	if (-not $Quiet) { Write-Host '[3/6] Analyzing Microsoft 365 Groups/Teams with Authentication Context labels...' -ForegroundColor Green }

	$allGroups = @()
	if ($graphConnected) {
		if (-not $Quiet) { Write-Host '   → Enumerating Microsoft 365 Groups (Graph)...' -ForegroundColor DarkCyan }
		try { $allGroups = Get-MgGroup -All -Property 'id,displayName,assignedLabels,groupTypes,resourceProvisioningOptions,mailNickname' } catch { Write-Warning "Get-MgGroup failed: $($_.Exception.Message)" }
		if (-not $Quiet) { Write-Host ('   → Found {0} total groups (Graph)' -f $allGroups.Count) -ForegroundColor DarkCyan }
	}
	if (-not $allGroups -or $allGroups.Count -eq 0) {
		if ($PurviewAuthenticationData.UnifiedGroupsCollection) {
			if (-not $Quiet) { Write-Host '   → Using EXO Unified Groups cache (Graph groups unavailable)' -ForegroundColor DarkCyan }
			$allGroups = $PurviewAuthenticationData.UnifiedGroupsCollection | ForEach-Object { [pscustomobject]@{ Id = $_.ExternalDirectoryObjectId; DisplayName = $_.DisplayName; MailNickname = $_.PrimarySmtpAddress.Split('@')[0]; AssignedLabels = @(); GroupTypes = @(); ResourceProvisioningOptions = @() } }
		}
	}

	$groupsWithContextLabel = @()
	if ($allGroups.Count -gt 0) {
		if (-not $Quiet) { Write-Host '   → Analyzing group label assignments...' -ForegroundColor DarkCyan }

		$script:groupsById = @{}
		foreach ($groupForMapping in $allGroups) { 
			if ($groupForMapping.Id -and $groupForMapping.DisplayName) { 
				$script:groupsById[$groupForMapping.Id] = $groupForMapping.DisplayName 
			} 
		}

		foreach ($currentGroup in $allGroups) {
			$assignedLabels = $null
			if ($currentGroup.PSObject.Properties['AssignedLabels']) { $assignedLabels = $currentGroup.AssignedLabels }
			if (-not $assignedLabels) { continue }

			$matchingAuthContextLabels = @($assignedLabels | Where-Object { $_.LabelId -and $labelIdSet.Contains($_.LabelId.ToString()) })

			if ($matchingAuthContextLabels.Count -gt 0) {
				$ContextId = $null; $ContextName = $null
				foreach ($matchingLabel in $matchingAuthContextLabels) { 
					$map = $script:LabelToAuthContext[[string]$matchingLabel.LabelId]
					if ($map) { $ContextId = $map.Id; $ContextName = $map.Name; break } 
				}
				$groupsWithContextLabel += [pscustomobject]@{
					'Group Id'          = $currentGroup.Id
					'Group Name'        = $currentGroup.DisplayName
					'Mail Nickname'     = $currentGroup.MailNickname
					'Is Team'           = ($currentGroup.ResourceProvisioningOptions -contains 'Team')
					'Group Types'       = ($currentGroup.GroupTypes -join ',')
					'Assigned Labels'   = ($matchingAuthContextLabels | ForEach-Object { $_.DisplayName } | Sort-Object -Unique) -join ','
					'Auth Context Id'   = $ContextId
					'Auth Context Name' = $ContextName
				}
			}
		}

		if ($groupsWithContextLabel.Count -gt 0) {
			if (-not $Quiet) { Write-Host "   ✓ Found $($groupsWithContextLabel.Count) group(s) with Authentication Context labels" -ForegroundColor DarkGreen }
		}
		else {
			if (-not $Quiet) { Write-Host '   ⚠  No groups found with Authentication Context labels' -ForegroundColor DarkYellow }
		}
	}
	if (-not $NoProgress) { Write-Progress -Id 1 -Activity 'Authentication Context Inventory' -Status 'Processing group/Team inheritance' -PercentComplete 55 }
	if (($groupsWithContextLabel | Measure-Object).Count -eq 0 -and $PurviewAuthenticationData.UnifiedGroupsCollection -and $PurviewAuthenticationData.UnifiedGroupsCollection.Count -gt 0 -and $PurviewAuthenticationData.SensitivityLabels) {
		foreach ($ug in $PurviewAuthenticationData.UnifiedGroupsCollection) {
			if (-not $ug.SensitivityLabelId) { continue }
			if ($labelIdSet.Contains([string]$ug.SensitivityLabelId)) {
				$map = $script:LabelToAuthContext[[string]$ug.SensitivityLabelId]
				$groupsWithContextLabel += [pscustomobject]@{
					'Group Id'          = $ug.ExternalDirectoryObjectId
					'Group Name'        = $ug.DisplayName
					'Mail Nickname'     = $ug.PrimarySmtpAddress.Split('@')[0]
					'Is Team'           = $false
					'Group Types'       = ''
					'Assigned Labels'   = $ug.SensitivityLabel
					'Auth Context Id'   = $map.Id
					'Auth Context Name' = $map.Name
				}
			}
		}
		if (-not $Quiet) { Write-Host ('   → EXO fallback mapped {0} group(s)' -f $groupsWithContextLabel.Count) -ForegroundColor DarkCyan }
	}

	if (($labelsWithContext | Measure-Object).Count -eq 0) { $groupsWithContextLabel = @() }
	else {
		$groupTotal = ($groupsWithContextLabel | Measure-Object).Count
		if ($groupTotal -gt 0) {
			$currentGroupIndex = 0
			$processedGroups = @()
			foreach ($currentGroupItem in $groupsWithContextLabel) {
				$currentGroupIndex++
				$pct = [int](($currentGroupIndex / $groupTotal) * 100)
				$nameForProgress = $null
				if ($currentGroupItem.PSObject.Properties.Name -contains 'Group Name') { $nameForProgress = $currentGroupItem.'Group Name' }
				elseif ($currentGroupItem.PSObject.Properties.Name -contains 'DisplayName') { $nameForProgress = $currentGroupItem.DisplayName }
				elseif ($currentGroupItem.PSObject.Properties.Name -contains 'GroupName') { $nameForProgress = $currentGroupItem.GroupName }
				if (-not $NoProgress) { Write-Progress -Id 3 -Activity 'Groups/Teams' -Status "Processing: $nameForProgress ($currentGroupIndex/$groupTotal)" -PercentComplete $pct }
				$processedGroups += $currentGroupItem
			}
			if (-not $NoProgress) { Write-Progress -Id 3 -Activity 'Groups/Teams' -Completed -Status 'Done' }
			$groupsWithContextLabel = $processedGroups
		}
		$groupsWithContextLabel = $groupsWithContextLabel | Sort-Object @{ Expression = { if ($_.PSObject.Properties.Name -contains 'Group Name') { $_.'Group Name' } elseif ($_.PSObject.Properties.Name -contains 'DisplayName') { $_.DisplayName } elseif ($_.PSObject.Properties.Name -contains 'GroupName') { $_.GroupName } else { $_ } } }
	}
	if (-not $NoProgress) { Write-Progress -Id 1 -Activity 'Authentication Context Inventory' -Status 'Group/Team analysis complete' -PercentComplete 65 }
	if (-not $NoProgress) { Write-Progress -Id 3 -Activity 'Groups/Teams' -Completed -Status 'Done' }

	# Conditional Access Policy enumeration
	if ($graphConnected) {
		$caPoliciesList = @()
		try {
			$caUri = 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies?$top=50'
			$caIndex = 0
			while ($caUri) {
				$page = Invoke-MgGraphRequest -Method GET -Uri $caUri -ErrorAction Stop
				if ($page.value) {
					foreach ($polItem in $page.value) {
						$caPoliciesList += $polItem; $caIndex++
						$percent = if ($caIndex -gt 0 -and $caIndex -lt 1000) { [math]::Min(90, [int]($caIndex)) } else { 90 }
						Write-Progress -Id 3 -Activity 'Conditional Access Policies' -Status "Processing policy $caIndex" -PercentComplete $percent
					}
				}
				$caUri = $page.'@odata.nextLink'
			}
		}
		catch { Write-Warning "Conditional Access policy enumeration failed: $($_.Exception.Message)" }
		Write-Progress -Id 3 -Activity 'Conditional Access Policies' -Completed -Status 'Done'
	}

	if ($null -eq $labelsWithContext -or ($labelsWithContext | Measure-Object).Count -eq 0) { $labelsWithContext = [pscustomobject]@{ Info = 'No label rows returned' } }
	$inheritedSites = @()
	if ($groupsWithContextLabel -and $siteByGroupId.Count -gt 0) {
		$inheritedSites = foreach ($groupRow in $groupsWithContextLabel) {
			$siteUrl = $null
			$groupIdForMap = if ($groupRow.PSObject.Properties.Name -contains 'Group Id') { $groupRow.'Group Id' } else { $null }
			if ($groupIdForMap -and $siteByGroupId.ContainsKey($groupIdForMap)) { $siteUrl = $siteByGroupId[$groupIdForMap] }
			if ($siteUrl) {
				$labelText = $null
				if ($groupRow.PSObject.Properties.Name -contains 'Sensitivity Label' -and $groupRow.'Sensitivity Label') { $labelText = $groupRow.'Sensitivity Label' }
				elseif ($groupRow.PSObject.Properties.Name -contains 'Assigned Labels' -and $groupRow.'Assigned Labels') { $labelText = $groupRow.'Assigned Labels' }

				[pscustomobject]@{
					Url                       = $siteUrl
					Title                     = $( if ($groupRow.PSObject.Properties.Name -contains 'Group Name') { $groupRow.'Group Name' } elseif ($groupRow.PSObject.Properties.Name -contains 'DisplayName') { $groupRow.DisplayName } else { $null } )
					ConditionalAccessPolicy   = 'Inherited'
					AuthenticationContextId   = $(if ($groupRow.PSObject.Properties.Name -contains 'Auth Context Id') { $groupRow.'Auth Context Id' } else { $null })
					AuthenticationContextName = $(if ($groupRow.PSObject.Properties.Name -contains 'Auth Context Name') { $groupRow.'Auth Context Name' } else { $null })
					SensitivityLabel          = $labelText
					Template                  = $null
					GroupId                   = $groupIdForMap
					StorageUsageCurrentMB     = $null
					Source                    = 'InheritedViaLabel'
				}
			}
		}
	}
	if ($inheritedSites) { $inheritedSites = $inheritedSites | Sort-Object Url -Unique }
	$directSites = $sharePointSitesWithAuthContext
	if (-not $inheritedSites) { $inheritedSites = @() }
	if (-not $inheritedSites -and $groupsWithContextLabel -and $spoConnected) {
		$guesses = foreach ($groupRow in $groupsWithContextLabel) {
			$needsGuess = $true
			if ($groupRow.PSObject.Properties.Name -contains 'Group Id') {
				$gidTmp = $groupRow.'Group Id'
				if ($gidTmp -and $siteByGroupId.ContainsKey($gidTmp)) { $needsGuess = $false }
			}
			if ($needsGuess) {
				$guessUrl = "https://$TenantName.sharepoint.com/sites/$($groupRow.MailNickname)"
				try {
					$siteObj = Get-SPOSite -Identity $guessUrl -ErrorAction SilentlyContinue
					if ($siteObj) {
						$derivedContextName = $null
						if ($groupRow.PSObject.Properties.Name -contains 'AssignedLabelNames' -and $groupRow.AssignedLabelNames) { $derivedContextName = ($groupRow.AssignedLabelNames -split ',')[0] }
						elseif ($groupRow.PSObject.Properties.Name -contains 'Assigned Labels' -and $groupRow.'Assigned Labels') { $derivedContextName = ($groupRow.'Assigned Labels' -split ',')[0] }
						[pscustomobject]@{ Url = $siteObj.Url; Title = $groupRow.DisplayName; ConditionalAccessPolicy = 'Inherited'; AuthenticationContextId = $null; AuthenticationContextName = $derivedContextName; SensitivityLabel = $derivedContextName; Template = $siteObj.Template; GroupId = $groupRow.GroupId; StorageUsageCurrentMB = ([math]::Round(($siteObj.StorageUsageCurrent / 1MB), 2) 2>$null); Source = 'InheritedViaLabelGuess' }
					}
				}
				catch { }
			}
		}
		if ($guesses) { $inheritedSites += $guesses }
	}
	$sitesCombined = @()
	$sitesCombined += $directSites
	$sitesCombined += $inheritedSites
	if ( ($null -eq $inheritedSites -or $inheritedSites.Count -eq 0) -and $allSpoSites -and $allSpoSites.Count -gt 0 -and $groupsWithContextLabel -and ($groupsWithContextLabel | Measure-Object).Count -gt 0 ) {
		$lateMap = @{}
		$allSpoSites | Where-Object { $_.GroupId -and $_.GroupId -ne [guid]::Empty } | ForEach-Object { $lateMap[$_.GroupId.Guid] = $_ }
		$lateDerived = foreach ($groupRow in $groupsWithContextLabel) {
			$gidLate = $null; if ($groupRow.PSObject.Properties.Name -contains 'Group Id') { $gidLate = $groupRow.'Group Id' }
			if ($gidLate -and $lateMap.ContainsKey($gidLate)) {
				$sObj = $lateMap[$gidLate]
				$ContextLate = if ($groupRow.PSObject.Properties.Name -contains 'Auth Context Name') { $groupRow.'Auth Context Name' } elseif ($groupRow.PSObject.Properties.Name -contains 'Assigned Labels') { ($groupRow.'Assigned Labels' -split ',')[0] } else { $null }
				[pscustomobject]@{ Url = $sObj.Url; Title = $sObj.Title; ConditionalAccessPolicy = 'Inherited'; AuthenticationContextId = $null; AuthenticationContextName = $ContextLate; SensitivityLabel = $ContextLate; GroupId = $gidLate; 'Storage (MB)' = ([math]::Round(($sObj.StorageUsageCurrent / 1MB), 2) 2>$null); Source = 'InheritedViaGroupLabelLate' }
			}
		}
		if ($lateDerived) { $sitesCombined += ($lateDerived | Sort-Object Url -Unique) }
	}
	if (-not $sitesCombined -or ($sitesCombined | Measure-Object).Count -eq 0) {
		if ($allSpoSites -and ($allSpoSites | Measure-Object).Count -gt 0) {
			$sitesCombined = $allSpoSites | Select-Object @{n = 'Url'; e = { $_.Url } }, @{n = 'Title'; e = { $_.Title } }, @{n = 'ConditionalAccessPolicy'; e = { $_.ConditionalAccessPolicy } }, @{n = 'AuthenticationContextName'; e = { '' } }, @{n = 'AuthContextFallback'; e = { 'None' } }
		}
		else {
			$sitesCombined = [pscustomobject]@{ Info = 'No site rows returned' }
		}
	}
	$spoWithContext = $sitesCombined
	if ($null -eq $spoWithContext -or ($spoWithContext | Measure-Object).Count -eq 0) { $spoWithContext = [pscustomobject]@{ Info = 'No site rows returned' } }
	if ($null -eq $groupsWithContextLabel -or ($groupsWithContextLabel | Measure-Object).Count -eq 0) { $groupsWithContextLabel = [pscustomobject]@{ Info = 'No group rows returned' } }
	if ($null -eq $authContexts -or ($authContexts | Measure-Object).Count -eq 0) { $authContexts = [pscustomobject]@{ Info = 'No authentication contexts returned' } }

	if ($spoWithContext -and ($spoWithContext | Measure-Object).Count -gt 0 -and -not ($spoWithContext[0].PSObject.Properties.Name -contains 'Info')) {
		$spoWithContext = $spoWithContext | ForEach-Object {
			if ($_ -isnot [pscustomobject]) { $_ } else {
				$ContextId = $_.AuthenticationContextId
				$ContextName = $_.AuthenticationContextName
				if (-not $ContextName -and $ContextId) {
					foreach ($kv in $script:LabelToAuthContext.GetEnumerator()) { if ($kv.Value.Id -eq $ContextId) { $ContextName = $kv.Value.Name; break } }
				}
				if (-not $ContextId -and $ContextName -and $authContexts) {
					$matchContext = $authContexts | Where-Object { $_.DisplayName -eq $ContextName } | Select-Object -First 1
					if ($matchContext) { $ContextId = $matchContext.Id }
				}
				$typeVal = $_.ConditionalAccessPolicy
				if ($typeVal -eq 'AuthenticationContext') { $typeVal = 'Direct' }
				elseif ($typeVal -eq 'Inherited') { $typeVal = 'Inherited' }
				elseif ($_.AuthenticationContextName) { $typeVal = 'Direct' }
				$sensLbl = $null
				if ($_.PSObject.Properties.Name -contains 'SensitivityLabel' -and $_.SensitivityLabel) { $sensLbl = $_.SensitivityLabel }
				elseif ($_.PSObject.Properties.Name -contains 'Assigned Labels' -and $_.'Assigned Labels') { $sensLbl = $_.'Assigned Labels' }
				elseif ($typeVal -eq 'Inherited' -and $ContextName) { $sensLbl = $ContextName }
				[pscustomobject]@{
					'Site Url'          = $_.Url
					'Site Title'        = $_.Title
					'Auth Context Type' = $typeVal
					'Auth Context Id'   = $ContextId
					'Auth Context Name' = $ContextName
					'Sensitivity Label' = $sensLbl
					'Group Id'          = $_.GroupId
					'Storage (MB)'      = $_.'Storage (MB)'
				}
			}
		} | Sort-Object 'Site Title'
	}
	#endregion

	#region Advanced Policy Analysis
	$caPolicies = $protectedActions = $pimPolicies = @()
	if ($graphConnected) {
		if (-not $Quiet) { Write-Host '[4/6] Analyzing Conditional Access policies...' -ForegroundColor Green }
		if (-not $NoProgress) { Write-Progress -Id 1 -Activity 'Authentication Context Inventory' -Status 'Analyzing Conditional Access policies' -PercentComplete 70 }

		if (-not $Quiet) { Write-Host '   → Analyzing Conditional Access policies...' -ForegroundColor DarkCyan }
		if ($authContexts -and ($authContexts | Get-Member -Name Id -ErrorAction SilentlyContinue) -and ($authContexts | Measure-Object).Count -gt 0 -and ($authContexts[0].PSObject.Properties.Name -contains 'Id')) {
			$caPolicies = Get-ConditionalAccessPoliciesWithAuthContext -AuthContexts $authContexts
			if ($caPolicies.Count -gt 0) {
				if (-not $Quiet) { Write-Host "   ✓ Found $($caPolicies.Count) Conditional Access policy/policies with Authentication Context references" -ForegroundColor DarkGreen }
			}
			else {
				if (-not $Quiet) { Write-Host '   ⚠  No Conditional Access policies found with Authentication Context references' -ForegroundColor DarkYellow }
			}
		}
		else {
			if (-not $Quiet) { Write-Host '   - Skipping Conditional Access analysis (no Authentication Contexts available)' -ForegroundColor Yellow }
			$caPolicies = @()
		}

		if (-not $Quiet) { Write-Host '[5/6] Analyzing Protected Actions...' -ForegroundColor Green }
		if (-not $Quiet) { Write-Host '   → Analyzing Protected Actions...' -ForegroundColor DarkCyan }
		$protectedActions = Get-ProtectedActionsWithAuthContext -AuthContexts $authContexts
		if ($protectedActions.Count -gt 0) {
			if (-not $Quiet) { Write-Host ('   ✓ Found {0} Protected Action(s) with Authentication Context requirements' -f $protectedActions.Count) -ForegroundColor DarkGreen }
		}
		else {
			if (-not $Quiet) { Write-Host '   ⚠  No Protected Actions found with Authentication Context requirements' -ForegroundColor DarkYellow }
		}

		$script:caPoliciesExport = @()
		if ($caPolicies) {
			$script:caPoliciesExport = $caPolicies | ForEach-Object {
				$acId = $null
				if ($_.AuthContextIds) { $acId = $_.AuthContextIds }
				elseif ($_.AuthContextClassRefs) { $acId = $_.AuthContextClassRefs }
				[pscustomobject]@{
					'Policy Name'        = $_.PolicyName
					'Policy Id'          = $_.PolicyId
					'State'              = $_.State
					'Auth Context Id'    = $acId
					'Auth Context Names' = $_.AuthContextNames
				}
			} | Sort-Object 'Policy Name'
		}
	}
	else {
		if (-not $Quiet) { Write-Host '[4/6] Skipping advanced policy analysis (Graph not connected)' -ForegroundColor Yellow }
	}
	#endregion

	#region PIM Policy Analysis
	if (-not $Quiet) { Write-Host '[6/6] Analyzing PIM policies...' -ForegroundColor Green }
	$azureResourcePim = @(); $pimPolicies = @(); $pimPoliciesEntra = @(); $pimPoliciesGroups = @()
	if ($graphConnected) {
		if (-not $NoProgress) {
			Write-Progress -Id 4 -Activity 'Conditional Access Policies' -Completed -Status 'Done'
			Write-Progress -Id 5 -Activity 'Protected Actions' -Completed -Status 'Done'
			Write-Progress -Id 1 -Activity 'Authentication Context Inventory' -Status 'Analyzing PIM policies' -PercentComplete 80
		}
  if (-not $Quiet) { Write-Host '   → Collecting PIM policies (Entra Directory Roles)...' -ForegroundColor DarkCyan }
  # Restored original style collection focusing only on auth-context referencing directory policies
  $pimDirPolicies = Get-EntraPIMPPoliciesWithAuthContext -AuthContexts $authContexts
		if (-not $NoProgress -and $pimDirPolicies) {
			$dirTotal = ($pimDirPolicies | Measure-Object).Count; $dIdx = 0
			foreach ($dp in $pimDirPolicies) { $dIdx++; $pct = [int](($dIdx / $dirTotal) * 100); Write-Progress -Id 6 -Activity 'PIM Policies (Directory)' -Status "Policy $dIdx/$dirTotal (Scope=/ Directory)" -PercentComplete $pct }
			Write-Progress -Id 6 -Activity 'PIM Policies (Directory)' -Completed -Status "Processed $dirTotal directory policies"
		}
		if (-not $Quiet) { Write-Host '   → Discovering managed PIM-for-Groups resources...' -ForegroundColor DarkCyan }
		$managedPimGroups = Get-PIMManagedGroupsResources
		$pimGroupPolicies = @()
		if ($managedPimGroups -and $managedPimGroups.Count -gt 0) {
			$managedGroupIds = $managedPimGroups | Select-Object -ExpandProperty GroupObjectId -Unique
			$groupNameMap = @{}
			foreach ($managedGroup in $managedPimGroups) { if ($managedGroup.GroupObjectId -and $managedGroup.DisplayName) { $groupNameMap[$managedGroup.GroupObjectId] = $managedGroup.DisplayName } }
			if (-not $Quiet) { Write-Host ('   ✓ Managed PIM groups discovered: {0}' -f $managedGroupIds.Count) -ForegroundColor DarkGreen }
			if (-not $Quiet) { Write-Host '   → Collecting PIM policies (Managed Groups) ...' -ForegroundColor DarkCyan }
			$pimGroupPolicies = Get-GroupPIMPoliciesForManagedGroups -GroupIds $managedGroupIds -AuthContexts $authContexts -NameMap $groupNameMap
			if (-not $NoProgress -and $pimGroupPolicies) {
				$groupPolicyTotal = ($pimGroupPolicies | Measure-Object).Count; $groupPolicyIndex = 0
				foreach ($groupPolicy in $pimGroupPolicies) { $groupPolicyIndex++; $pct = [int](($groupPolicyIndex / $groupPolicyTotal) * 100); Write-Progress -Id 6 -Activity 'PIM Policies (Groups)' -Status "Policy $groupPolicyIndex/$groupPolicyTotal (Managed group scope)" -PercentComplete $pct }
				Write-Progress -Id 6 -Activity 'PIM Policies (Groups)' -Completed -Status "Processed $groupPolicyTotal managed group policies"
			}
		}
		else {
			if (-not $Quiet) { Write-Host '      ✓ No managed PIM-for-Groups resources discovered (treating as zero group PIM policies)' -ForegroundColor DarkGray }
			$pimGroupPolicies = @()
		}
		$pimPolicies = @(); $pimPolicies += $pimDirPolicies; $pimPolicies += $pimGroupPolicies
		$pimPoliciesEntra = $pimDirPolicies
		$pimPoliciesGroups = $pimGroupPolicies
		if (-not $Quiet) {
			$entraPolicyCount = ($pimPoliciesEntra | Measure-Object).Count
			$groupsPolicyCount = ($pimPoliciesGroups | Measure-Object).Count
			if ($entraPolicyCount -gt 0) { Write-Host ('   ✓ Found {0} PIM Policies requiring authentication context for Entra' -f $entraPolicyCount) -ForegroundColor DarkGreen } else { Write-Host '   ⚠  No PIM Policies found requiring authentication context for Entra' -ForegroundColor DarkYellow }
			if ($groupsPolicyCount -gt 0) { Write-Host ('   ✓ Found {0} PIM Policies requiring authentication context for Groups' -f $groupsPolicyCount) -ForegroundColor DarkGreen } else { Write-Host '   ⚠  No PIM Policies found requiring authentication context for Groups' -ForegroundColor DarkYellow }
		}
		# Directory export: project a simple row per policy (role definition id resolved later in HTML shaping if needed)
		if ($pimPoliciesEntra -and ($pimPoliciesEntra | Measure-Object).Count -gt 0) {
			$script:pimPoliciesEntraExport = $pimPoliciesEntra | ForEach-Object {
				[pscustomobject]@{
					'RoleDefinitionId'     = $_.RoleDefinitionId
					'AuthContextIds'       = $_.AuthContextIds
					'AuthContextClassRefs' = $_.AuthContextClassRefs
				}
			}
		}
		# Group export: manual projection (avoid helper invocation binding issues) one row per policy with role name resolution
		if ($pimGroupPolicies -and ($pimGroupPolicies | Measure-Object).Count -gt 0) {
			$script:pimPoliciesGroupsExport = @()
			$groupRoleMap = @{}
			$distinctGroupRoleIds = $pimGroupPolicies | Where-Object { $_.RoleDefinitionId } | Select-Object -ExpandProperty RoleDefinitionId -Unique
			foreach ($rid in $distinctGroupRoleIds) {
				$resolvedName = $null
				if ($rid -match '^(owner|Owner)$') { $resolvedName = 'Owner' }
				elseif ($rid -match '^(member|Member)$') { $resolvedName = 'Member' }
				else {
					try {
						$rDef = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions/$rid?`$select=id,displayName" -ErrorAction Stop
						if ($rDef.id -and $rDef.displayName) { $resolvedName = $rDef.displayName }
					}
					catch {}
					if (-not $resolvedName) { $resolvedName = $rid }
				}
				$groupRoleMap[$rid] = $resolvedName
			}
			foreach ($gp in $pimGroupPolicies) {
				$grpName = $null
				if ($gp.PSObject.Properties.Name -contains 'GroupName' -and $gp.GroupName) { $grpName = $gp.GroupName }
				elseif ($gp.PSObject.Properties.Name -contains 'ScopeId' -and $gp.ScopeId -and $script:groupsById.ContainsKey($gp.ScopeId)) { $grpName = $script:groupsById[$gp.ScopeId] }
				$roleName = $null
				if ($gp.PSObject.Properties.Name -contains 'RoleDefinitionId' -and $gp.RoleDefinitionId) { $roleName = $groupRoleMap[$gp.RoleDefinitionId] }
				$acIdOut = $null; foreach ($pn in 'AuthContextIds', 'AuthContextClassRefs', 'AuthContextClassReferences', 'AuthContextId') { if ($gp.PSObject.Properties.Name -contains $pn -and $gp.$pn) { $acIdOut = $gp.$pn; break } }
				$acNameOut = $null; foreach ($pn in 'AuthContextNames', 'MatchedContextNamesText') { if ($gp.PSObject.Properties.Name -contains $pn -and $gp.$pn) { $acNameOut = $gp.$pn; break } }
				$script:pimPoliciesGroupsExport += [pscustomobject]@{ 'Group Name' = $grpName; 'Role Name' = $roleName; 'Auth Context Id' = $acIdOut; 'Auth Context Name' = $acNameOut }
			}
		}
		if (-not $NoProgress) { Write-Progress -Id 6 -Activity 'PIM Policies' -Completed -Status ('Directory={0}, Groups={1}' -f (($pimPoliciesEntra | Measure-Object).Count), (($pimPoliciesGroups | Measure-Object).Count)) }
		if (-not $NoProgress) { Write-Progress -Id 1 -Activity 'Authentication Context Inventory' -Status 'PIM policy analysis complete' -PercentComplete 90 }
		if ($UsePIMAzure) {
			if (-not $Quiet) { Write-Host '   → Collecting PIM policies (Azure Resources)...' -ForegroundColor DarkCyan }
			$tenantForPim = $script:CurrentTenantId
			if (-not $tenantForPim) { try { $tenantForPim = (Get-MgContext -ErrorAction SilentlyContinue).TenantId } catch {} }
			if (-not $tenantForPim) { try { $tenantForPim = (Get-AzContext -ErrorAction SilentlyContinue).Tenant.Id } catch {} }
			$azureResourcePim = Invoke-AzureResourcePIMCollection -AuthContexts $authContexts -AccountUpn $UserPrincipalName -TenantId $tenantForPim -AzureSubscriptionIds $AzureSubscriptionIds -Quiet:$Quiet
			$azureCount = ($azureResourcePim | Measure-Object).Count
			if (-not $Quiet) { 
				if ($azureCount -gt 0) { Write-Host ('   ✓ Found {0} PIM Policies requiring authentication context for Azure Resources' -f $azureCount) -ForegroundColor DarkGreen } else { Write-Host '   ⚠  No PIM Policies found requiring authentication context for Azure Resources' -ForegroundColor DarkYellow }
			}
		}
	}
	#endregion

	#region Report Generation and Cleanup
	if (-not $Quiet) { 
		Write-Host "`n[Report Generation] Creating output files..." -ForegroundColor Cyan 
		Write-Host '══════════════════════════════════════════════════════════════════════════════════════' -ForegroundColor DarkCyan
	}

	try {
  # Prefer projected export; if helper did not yield rows fallback to original raw policy objects for visibility
  $pimEntraOut = if ($script:pimPoliciesEntraExport -and ($script:pimPoliciesEntraExport | Measure-Object).Count -gt 0) { $script:pimPoliciesEntraExport | Sort-Object 'RoleDefinitionId' } else { $pimPoliciesEntra | Sort-Object @{ Expression = { $_.RoleDefinitionId } } }
  $pimGroupOut = if ($script:pimPoliciesGroupsExport -and ($script:pimPoliciesGroupsExport | Measure-Object).Count -gt 0) { $script:pimPoliciesGroupsExport | Sort-Object 'Role Name' } else { $pimPoliciesGroups | Sort-Object @{ Expression = { $_.RoleDefinitionId } } }
		$pimAzureOut = @()
		if ($azureResourcePim) {
			$authContextMap = @{}
			if ($authContexts) { foreach ($authContext in $authContexts) { if ($authContext.Id -and $authContext.DisplayName) { $authContextMap[$authContext.Id] = $authContext.DisplayName } } }
			$roleCache = @{}
			$pimAzureOut = $azureResourcePim | ForEach-Object {
				$roleName = $null
				if ($_.PSObject.Properties.Name -contains 'RoleDisplayName' -and $_.RoleDisplayName) { $roleName = $_.RoleDisplayName }
				elseif ($_.PSObject.Properties.Name -contains 'RoleDefinitionId' -and $_.RoleDefinitionId -match '([^/]+)$') {
					$roleGuid = $Matches[1]
					if ($roleCache.ContainsKey($roleGuid)) { $roleName = $roleCache[$roleGuid] }
				}
				if (-not $roleName -and $_.RoleDefinitionId -and ($_.RoleDefinitionId -match '([^/]+)$')) {
					$roleGuid = $Matches[1]
					try {
						$subId = $null
						if ($_.Scope -match '/subscriptions/([^/]+)') { $subId = $Matches[1] }
						if ($subId) { Set-AzContext -Subscription $subId -ErrorAction SilentlyContinue | Out-Null }
						if ($roleCache.ContainsKey($roleGuid)) { $roleName = $roleCache[$roleGuid] }
						else {
							$rd = Get-AzRoleDefinition -Id $roleGuid -ErrorAction SilentlyContinue
							if ($rd -and $rd.RoleName) { $roleName = $rd.RoleName; $roleCache[$roleGuid] = $roleName }
						}
					}
					catch {}
				}
				$acId = $_.AuthContextClassRefs
				$acName = $_.AuthContextNames
				if (-not $acName -and $acId) { $acFirst = ($acId -split ',')[0]; if ($authContextMap.ContainsKey($acFirst)) { $acName = $authContextMap[$acFirst] } }
				[pscustomobject]@{
					'Role Name'         = $roleName
					'Scope'             = $_.Scope
					'ScopeType'         = $_.ScopeType
					'Auth Context Id'   = $acId
					'Auth Context Name' = $acName
					'Source'            = $_.Source
				}
			} | Sort-Object 'Role Name'
		}
	}
	catch { if (-not $Quiet) { Write-Host '   ✗ Report data preparation failed' -ForegroundColor Red } }

	$htmlPath = if ($HtmlReportPath) { $HtmlReportPath } else { Join-Path $OutputPath ("AuthContext_Inventory_${Global:AuthContextTimestamp}.html") }
	try {
		$caHtml = if ($script:caPoliciesExport) { $script:caPoliciesExport } else { $caPolicies }
		# Prefer projected export (already normalized). If absent, derive minimal projection from raw policies retaining context tokens.
		$pimEntraHtml = @()
		if ($pimEntraOut -and ($pimEntraOut | Measure-Object).Count -gt 0) {
			# Build role name cache by resolving roleDefinitionId via Graph directory roleDefinitions endpoint
			$roleNameCache = @{}
			# Build a set of unique role definition ids for bulk resolution
			$uniqueRoleIds = $pimEntraOut | Where-Object { $_.RoleDefinitionId } | Select-Object -ExpandProperty RoleDefinitionId -Unique
			$roleNameCache = @{}
			# Seed with common well-known directory role template ids (subset)
			$wellKnownDirectoryRoles = @{
				'62e90394-69f5-4237-9190-012177145e10' = 'Global Administrator'
				'b0afded3-7a9c-4d45-82ef-ef1f6489327f' = 'Privileged Role Administrator'
				'29232cdf-9323-42fd-ade2-1d097af3e4de' = 'User Administrator'
				'3a2c7ab9-5cd9-4e5e-b407-bc39f3b09c5b' = 'Security Administrator'
				'f2ef992c-3afb-46b9-b7cf-a126ee74c451' = 'Compliance Administrator'
				'6e4349e6-4c0f-487b-9e0a-0d0373d16d8f' = 'Exchange Administrator'
				'0f971eea-4d1b-4626-a10d-6c6d1393cd83' = 'SharePoint Administrator'
				'7698a772-e0ea-40d7-bd30-dd56b74395bf' = 'Teams Administrator'
				'be2f45a1-457e-42d8-9e3c-66d72cce6b2f' = 'Cloud Application Administrator'
				'74ef975b-6605-40e6-8d43-30f49c6d4e7a' = 'Authentication Policy Administrator'
				'9c094953-4995-41ec-b83c-2dc9b41f0f41' = 'Identity Governance Administrator'
				'82610a66-2f2a-4f17-b474-75b63ce3a2fb' = 'Groups Administrator'
				'cf1c38e5-3621-4007-8b0a-4c4e38fbad74' = 'Helpdesk Administrator'
			}
			foreach ($wk in $wellKnownDirectoryRoles.Keys) { $roleNameCache[$wk] = $wellKnownDirectoryRoles[$wk] }
			# Prefetch role definitions & templates & active roles
			$prefetchUris = @(
				'https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?$select=id,displayName&$top=200',
				'https://graph.microsoft.com/v1.0/directoryRoleTemplates?$select=id,displayName&$top=200',
				'https://graph.microsoft.com/v1.0/directoryRoles?$select=id,displayName,roleTemplateId&$top=200'
			)
			foreach ($uri in $prefetchUris) {
				try {
					$resp = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
					$vals = if ($resp.value) { $resp.value } else { @($resp) }
					foreach ($v in $vals) {
						if ($v.id -and $v.displayName) {
							if (-not $roleNameCache.ContainsKey($v.id)) { $roleNameCache[$v.id] = $v.displayName }
						}
						if ($v.PSObject.Properties.Name -contains 'roleTemplateId' -and $v.roleTemplateId -and $v.displayName) {
							if (-not $roleNameCache.ContainsKey($v.roleTemplateId)) { $roleNameCache[$v.roleTemplateId] = $v.displayName }
						}
					}
				}
				catch {}
			}
			# Beta fallback if still unresolved ids
			$unresolved = $uniqueRoleIds | Where-Object { -not $roleNameCache.ContainsKey($_) }
			if ($unresolved.Count -gt 0) {
				$betaUris = @(
					'https://graph.microsoft.com/beta/roleManagement/directory/roleDefinitions?$select=id,displayName&$top=400',
					'https://graph.microsoft.com/beta/directoryRoleTemplates?$select=id,displayName&$top=400'
				)
				foreach ($bUri in $betaUris) {
					try {
						$bResp = Invoke-MgGraphRequest -Method GET -Uri $bUri -ErrorAction Stop
						$bVals = if ($bResp.value) { $bResp.value } else { @($bResp) }
						foreach ($bv in $bVals) {
							if ($bv.id -and $bv.displayName -and (-not $roleNameCache.ContainsKey($bv.id))) { $roleNameCache[$bv.id] = $bv.displayName }
						}
					}
					catch {}
				}
			}
			# Final guarantee mapping (fallback id->id)
			foreach ($rId in $uniqueRoleIds) { if (-not $roleNameCache.ContainsKey($rId)) { $roleNameCache[$rId] = $rId } }
			foreach ($row in $pimEntraOut) {
				$roleDefId = $null
				if ($row.PSObject.Properties.Name -contains 'RoleDefinitionId') { $roleDefId = $row.RoleDefinitionId }
				if (-not $roleDefId) { continue }
				$acIdVal = $null; foreach ($pn in 'AuthContextIds', 'AuthContextClassRefs', 'AuthContextClassReferences', 'AuthContextId') { if ($row.PSObject.Properties.Name -contains $pn -and $row.$pn) { $acIdVal = $row.$pn; break } }
				$acNameVal = $null; foreach ($pn in 'AuthContextNames', 'MatchedContextNamesText') { if ($row.PSObject.Properties.Name -contains $pn -and $row.$pn) { $acNameVal = $row.$pn; break } }
				# Derive context name from auth contexts when not explicitly present
				if (-not $acNameVal -and $acIdVal -and $authContexts) {
					$firstIds = $acIdVal -split ',' | Select-Object -First 3
					$mappedNames = @()
					foreach ($fid in $firstIds) {
						$matchCtx = $authContexts | Where-Object { $_.Id -eq $fid }
						if ($matchCtx) { $mappedNames += $matchCtx.DisplayName }
					}
					if ($mappedNames.Count -gt 0) { $acNameVal = ($mappedNames -join ',') }
				}
				$resolvedRoleName = if ($roleNameCache.ContainsKey($roleDefId)) { $roleNameCache[$roleDefId] } else { $roleDefId }
				$pimEntraHtml += [pscustomobject]@{ 'Role Name' = $resolvedRoleName; 'Auth Context Id' = $acIdVal; 'Auth Context Name' = $acNameVal }
			}
  }
  $pimGroupsHtml = $pimGroupOut | ForEach-Object {
			$grpName = $_.'Group Name'
			if (-not $grpName -and $_.PSObject.Properties.Name -contains 'GroupName') { $grpName = $_.GroupName }
			elseif (-not $grpName -and $_.PSObject.Properties.Name -contains 'ScopeId') { $grpName = $_.ScopeId }
			$roleName = $_.'Role Name'
			if (-not $roleName -and $_.PSObject.Properties.Name -contains 'RoleDefinitionId') { $roleName = $_.RoleDefinitionId }
			$acIds = @()
			foreach ($pn in 'Auth Context Id', 'AuthContextIds', 'AuthContextClassRefs', 'AuthContextClassReferences', 'RequiredAuthContextIds', 'AuthContextId') {
				if ($_.PSObject.Properties.Name -contains $pn) {
					$val = $_.$pn
					if ($val) { if ($val -is [System.Collections.IEnumerable] -and $val -isnot [string]) { $acIds += ($val | ForEach-Object { $_ }) } else { $acIds += ($val -split ',') } }
				}
			}
			$acId = if ($acIds.Count -gt 0) { ($acIds | Where-Object { $_ } | Select-Object -Unique) -join ',' } else { $null }
			$acNameVals = @()
			foreach ($pn in 'Auth Context Name', 'AuthContextNames') { if ($_.PSObject.Properties.Name -contains $pn) { $v = $_.$pn; if ($v) { if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { $acNameVals += ($v | ForEach-Object { $_ }) } else { $acNameVals += ($v -split ',') } } } }
			$acName = if ($acNameVals.Count -gt 0) { ($acNameVals | Where-Object { $_ } | Select-Object -Unique) -join ',' } else { $null }
			[pscustomobject]@{ 'Group Name' = $grpName; 'Role Name' = $roleName; 'Auth Context Id' = $acId; 'Auth Context Name' = $acName }
  }
  # Remove unwanted Group Id column from security groups dataset
  $groupsSlim = $groupsWithContextLabel | Select-Object * -ExcludeProperty 'Group Id'
		$pimAzureHtml = $pimAzureOut
  if ($HtmlAllLayouts) {
			$baseName = [System.IO.Path]::GetFileNameWithoutExtension($htmlPath)
			$dirName = [System.IO.Path]::GetDirectoryName($htmlPath)
			foreach ($layoutVariant in 'Classic', 'Tabbed', 'TabbedOverview', 'Sidebar', 'Masonry', 'Dashboard', 'Layoutv2') {
				$variantPath = Join-Path $dirName ($baseName + '_' + $layoutVariant + '.html')
				if (-not $Quiet) { Write-Host "   → Generating layout variant: $layoutVariant ($variantPath)" -ForegroundColor DarkCyan }
				New-AuthContextHtmlReport -AuthContexts $authContexts -Labels $labelsWithContext -Sites $spoWithContext -Groups $groupsSlim -CA $caHtml -ProtectedActions $protectedActions -PIMPoliciesEntra $pimEntraHtml -PIMPoliciesGroups $pimGroupsHtml -PIMPoliciesAzureResources $pimAzureHtml -Path $variantPath -Style $HtmlStyle -Layout $layoutVariant -GenerateAllThemesForLayout:$HtmlAllLayoutThemes -QuietMode:$Quiet | Out-Null
			}
			# Primary path uses requested or default layout for consistency
			New-AuthContextHtmlReport -AuthContexts $authContexts -Labels $labelsWithContext -Sites $spoWithContext -Groups $groupsSlim -CA $caHtml -ProtectedActions $protectedActions -PIMPoliciesEntra $pimEntraHtml -PIMPoliciesGroups $pimGroupsHtml -PIMPoliciesAzureResources $pimAzureHtml -Path $htmlPath -Style $HtmlStyle -Layout $(if ($HtmlLayout) { $HtmlLayout } else { 'Classic' }) -GenerateAllThemesForLayout:$HtmlAllLayoutThemes -QuietMode:$Quiet | Out-Null
  }
  else {
			New-AuthContextHtmlReport -AuthContexts $authContexts -Labels $labelsWithContext -Sites $spoWithContext -Groups $groupsSlim -CA $caHtml -ProtectedActions $protectedActions -PIMPoliciesEntra $pimEntraHtml -PIMPoliciesGroups $pimGroupsHtml -PIMPoliciesAzureResources $pimAzureHtml -Path $htmlPath -Style $HtmlStyle -Layout $(if ($HtmlLayout) { $HtmlLayout } else { 'Classic' }) -GenerateAllThemesForLayout:$HtmlAllLayoutThemes -QuietMode:$Quiet | Out-Null
  }
		if (-not $Quiet) { Write-Host "   ✓ HTML report saved: $htmlPath" -ForegroundColor DarkGreen }
		if (-not $NoAutoOpen) { Start-Process $htmlPath; if (-not $Quiet) { Write-Host '   → Opening HTML report in default browser...' -ForegroundColor DarkCyan } }
	}
	catch { if (-not $Quiet) { Write-Host '   ✗ HTML report generation failed' -ForegroundColor Red }; Write-Warning "HTML report generation failed: $($_.Exception.Message)" }
	if (-not $Quiet) { 
		Write-Host "`n[Completion Summary]" -ForegroundColor Cyan
		Write-Host "   Authentication Contexts: $(($authContexts | Measure-Object).Count)" -ForegroundColor White
		$labelCount = ($labelsWithContext | Measure-Object).Count
		Write-Host ('   Sensitivity Labels:      {0}' -f $labelCount) -ForegroundColor White
		$sitesDirectlyAssigned = ($spoWithContext | Measure-Object).Count
		$sitesInheritedFromGroups = 0
		if ($siteByGroupId -and $groupsWithContextLabel) {
			$groupIdsWithContext = [System.Collections.Generic.HashSet[string]]::new()
			foreach ($groupWithLabel in $groupsWithContextLabel) { if ($groupWithLabel.GroupId) { [void]$groupIdsWithContext.Add([string]$groupWithLabel.GroupId) } }
			foreach ($groupId in $siteByGroupId.Keys) { if ($groupIdsWithContext.Contains([string]$groupId)) { $sitesInheritedFromGroups++ } }
		}
		$totalSitesWithContext = $sitesDirectlyAssigned + $sitesInheritedFromGroups
		Write-Host ('   SharePoint Sites:        {0}' -f $totalSitesWithContext) -ForegroundColor White
		Write-Host "   Microsoft 365 Groups:    $(($groupsWithContextLabel | Measure-Object).Count)" -ForegroundColor White
		Write-Host "   CA Policies:             $(($caPolicies | Measure-Object).Count)" -ForegroundColor White
		Write-Host "   Protected Actions:       $(($protectedActions | Measure-Object).Count)" -ForegroundColor White
		if ($graphConnected -and ($pimPoliciesEntra -or $pimPoliciesGroups -or ($UsePIMAzure -and $azureResourcePim))) {
			Write-Host "   PIM Policies (Entra):    $(($pimPoliciesEntra | Measure-Object).Count)" -ForegroundColor White
			Write-Host "   PIM Policies (Groups):   $(($pimPoliciesGroups | Measure-Object).Count)" -ForegroundColor White
			if ($UsePIMAzure) { Write-Host "   PIM Policies (Azure):    $(($azureResourcePim | Measure-Object).Count)" -ForegroundColor White }
		}
		Write-Host "   Report saved to:        $OutputPath" -ForegroundColor White
		Write-Host '══════════════════════════════════════════════════════════════════════════════════════' -ForegroundColor Cyan
		Write-Host 'Authentication Context inventory analysis completed successfully!' -ForegroundColor Green
	}
	try { } finally { Invoke-GracefulCleanup -QuietMode:$Quiet }
	#endregion
}
