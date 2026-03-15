function Invoke-AccessPackageDocumentorCore {
	<#!
	.SYNOPSIS
		Core workflow for Access Package Documentor reporting.

	.DESCRIPTION
		Connects to Microsoft Graph (read-only), retrieves access packages with policies/resources/custom extensions,
		converts to a documentation graph, and emits an interactive HTML report.

	.PARAMETER OutputPath
		Directory where the HTML report will be saved.

	.PARAMETER HtmlReportPath
		Optional explicit HTML file path. If not provided, one is generated in OutputPath.

	.PARAMETER Theme
		Preferred theme: Auto, Light, Dark.

	.PARAMETER Quiet
		Suppress console chatter.

	.PARAMETER NoAutoOpen
		Do not open the HTML automatically after generation.
	#>
	[CmdletBinding()] param(
		[string]$OutputPath,
		[string]$HtmlReportPath,
		[ValidateSet('Auto','Light','Dark')][string]$Theme = 'Auto',
		[bool]$IncludeBeta = $true,
		[string]$TenantId,
		[string]$ClientId,
		[switch]$Quiet,
		[switch]$NoAutoOpen,
		[switch]$ExportCsv
	)

	if ($PSVersionTable.PSVersion -lt [version]'7.0') {
		throw 'PowerShell 7.0+ is required.'
	}

	if (-not $OutputPath) { $OutputPath = 'C:\Reports\M365AccessPackages\' }
	if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null }

	if (-not $HtmlReportPath) {
		$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
		$HtmlReportPath = Join-Path $OutputPath "AccessPackages_$ts.html"
	}

	$reportPath = $null
	try {
		$data = Get-AccessPackageGraphData -QuietMode:$Quiet -IncludeBeta:$IncludeBeta -TenantId:$TenantId -ClientId:$ClientId
		$graphData = Convert-AccessPackageDocumentorData -AccessPackageData $data
		$reportPath = New-AccessPackageDocumentorHtml -Data $graphData -OutputPath $HtmlReportPath -Theme $Theme

		Write-ModuleLog -Message "Access Package Documentor report generated: $reportPath" -Level Success

		# Export to CSV if requested
		if ($ExportCsv) {
			$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
			$csvBasePath = Join-Path $OutputPath "AccessPackages_$ts"
			
			# Export access packages
			$packagesPath = "${csvBasePath}_Packages.csv"
			$data.AccessPackages | Select-Object Id, DisplayName, Description, @{N='CatalogName';E={$_.Catalog.DisplayName}}, @{N='CatalogId';E={$_.Catalog.Id}}, CreatedDateTime, ModifiedDateTime | Export-Csv -Path $packagesPath -NoTypeInformation -Encoding UTF8
			if (-not $Quiet) { Write-Host "   ✓ Exported packages to: $packagesPath" -ForegroundColor DarkGreen }
			
			# Export policies
			$policiesPath = "${csvBasePath}_Policies.csv"
			$policies = $data.AccessPackages | ForEach-Object {
				$pkg = $_
				$pkg.AssignmentPolicies | ForEach-Object {
					[PSCustomObject]@{
						PolicyId = $_.Id
						PolicyName = $_.DisplayName
						Description = $_.Description
						PackageName = $pkg.DisplayName
						PackageId = $pkg.Id
						AllowedTargetScope = $_.AllowedTargetScope
						DurationInDays = $_.DurationInDays
						CreatedDateTime = $_.CreatedDateTime
						ModifiedDateTime = $_.ModifiedDateTime
					}
				}
			}
			$policies | Export-Csv -Path $policiesPath -NoTypeInformation -Encoding UTF8
			if (-not $Quiet) { Write-Host "   ✓ Exported policies to: $policiesPath" -ForegroundColor DarkGreen }
			
			# Export resources
			$resourcesPath = "${csvBasePath}_Resources.csv"
			$resources = $data.AccessPackages | ForEach-Object {
				$pkg = $_
				$_.accessPackageResourceRoleScopes | ForEach-Object {
					$rrs = $_
					[PSCustomObject]@{
						ResourceId = $rrs.id
						ResourceName = $rrs.role.resource.displayName
						ResourceType = $rrs.role.resource.resourceType
						OriginSystem = $rrs.role.resource.originSystem
						OriginId = $rrs.role.resource.originId
						RoleName = $rrs.role.displayName
						RoleId = $rrs.role.id
						ScopeName = $rrs.scope.displayName
						PackageName = $pkg.DisplayName
						PackageId = $pkg.Id
					}
				}
			}
			$resources | Export-Csv -Path $resourcesPath -NoTypeInformation -Encoding UTF8
			if (-not $Quiet) { Write-Host "   ✓ Exported resources to: $resourcesPath" -ForegroundColor DarkGreen }
		}

		if (-not $NoAutoOpen) {
			try { Start-Process $reportPath | Out-Null } catch { Write-ModuleLog -Message "Failed to auto-open report: $($_.Exception.Message)" -Level Warning }
		}

		return $reportPath
	}
	finally {
		try {
			if ($script:graphConnected -and $script:graphDisconnectOnExit -and (Get-MgContext -ErrorAction SilentlyContinue)) {
				Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
				if (-not $Quiet) { Write-Host '   ✓ Disconnected Microsoft Graph session' -ForegroundColor DarkGray }
			}
		}
		catch {
			Write-ModuleLog -Message "Graph disconnect warning: $($_.Exception.Message)" -Level Warning
		}
	}
}
