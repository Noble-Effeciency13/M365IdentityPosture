function Invoke-AuthContextInventoryReport {
	<#
	.SYNOPSIS
	Comprehensive inventory of Authentication Context enforcement across Microsoft 365, Entra ID, and Azure environments.

	.DESCRIPTION
	Performs a phased, read-only discovery of Authentication Context enforcement across:
	
	Phase 1 - Purview & Exchange Online:
		* Sensitivity labels (Sites & Groups scope) with embedded Authentication Context requirements
		* Exchange Online protection policies and protected actions
	
	Phase 2 - Microsoft Graph:
		* Authentication Context Class References discovery  
		* M365 Groups / Teams with Authentication Context enforcement via labels
		* Conditional Access policies referencing Authentication Contexts
		* Entra PIM (directory + group roles) requiring Authentication Context for activation
	
	Phase 3 - SharePoint Online:
		* SharePoint sites with direct Authentication Context assignment
		* Site-level Authentication Context policies and enforcement
	
	Phase 4 - Azure Resources (Optional):
		* Azure Resource PIM policies requiring Authentication Context for role activation
		* Subscription and resource group level PIM policy analysis

	.PARAMETER TenantName
	Tenant short name (e.g. 'contoso' from https://contoso-admin.sharepoint.com). 
	If not specified, will attempt to auto-detect from current context.

	.PARAMETER OutputPath
	Directory for report output. Default: C:\Reports\M365AuthContext\

	.PARAMETER UserPrincipalName
	Optional UPN hint to reduce interactive authentication prompts across Purview, Graph, and Azure connections.

	.PARAMETER SharePointOnlineCredential
	Optional credential for SharePoint Online authentication (break-glass scenarios only).

	.PARAMETER Quiet
	Minimize console output to essential status messages only.

	.PARAMETER NoProgress
	Suppress Write-Progress updates during processing.

	.PARAMETER HtmlReportPath
	Custom path for HTML report output. If not specified, uses OutputPath with auto-generated filename.

	.PARAMETER NoAutoOpen
	Prevent automatic opening of the HTML report after generation.

	.PARAMETER ExcludeAzure
	Skip Azure Resource PIM enumeration entirely. Reduces required permissions and module dependencies.

	.PARAMETER AzureSubscriptionIds
	Specific Azure subscription IDs to process for PIM policies. Accepts single ID or array of subscription GUIDs. 
	If not specified, all accessible subscriptions are processed. Use with -ExcludeAzure to skip Azure entirely.

	.PARAMETER HtmlStyle
	Select the visual theme for the HTML report. Available values: Classic, Dark.
	Classic is the light theme. Dark is the dark theme. A runtime toggle button in the report lets you switch between them regardless of initial choice.

	.PARAMETER HtmlLayout
	Structural layout variant for the report content: TabbedOverview (default - Overview tab plus individual section tabs), Classic (sections stacked), Tabbed, Sidebar (navigation rail), Masonry (multi-column cards), Dashboard (summary cards with modal detail), Layoutv2 (modern card grid with search & collapsible cards).

	.PARAMETER HtmlAllLayoutThemes
	When specified, generate all theme variants for the chosen layout alongside the primary report.

	.PARAMETER HtmlAllLayouts
	Generate all layout variants (Classic, Tabbed, Sidebar, Masonry, Dashboard) for the chosen theme. Can be combined with -HtmlAllLayoutThemes to produce every style/layout permutation.

	.OUTPUTS
	HTML report consolidating Authentication Context usage across all discovered services and policies.
	Returns the path to the generated HTML report.

	.EXAMPLE
	Invoke-AuthContextInventoryReport -TenantName contoso
	
	Performs full discovery across all phases and generates comprehensive HTML report.

	.EXAMPLE
	Invoke-AuthContextInventoryReport -TenantName contoso -ExcludeAzure -Quiet
	
	Skips Azure Resource PIM phase and minimizes console output. Useful for environments without Azure access.

	.EXAMPLE
	Invoke-AuthContextInventoryReport -TenantName contoso -AzureSubscriptionIds @('12345678-1234-1234-1234-123456789abc','87654321-4321-4321-4321-987654321def')
	
	Processes only specified Azure subscriptions for PIM policy analysis, reducing scope and processing time.

	.EXAMPLE
	Invoke-AuthContextInventoryReport -TenantName contoso -UserPrincipalName admin@contoso.com -OutputPath D:\Reports -NoAutoOpen
	
	Uses specified UPN for authentication hints, custom output directory, and prevents automatic report opening.

	.NOTES
	Module:    M365IdentityPosture
	Author:    Sebastian Flæng Markdanner
	Website:   https://chanceofsecurity.com  
	Version:   1.0.0
	Date:      07-10-2025
	
	All operations are read-only; no configuration changes performed.

	Required Permissions:

	Microsoft Graph API (Delegated):
	- Directory.Read.All                     # Read directory data, users, groups
	- Group.Read.All                         # Read all groups and their properties
	- Policy.Read.All                        # Read all organizational policies
	- Policy.Read.ConditionalAccess          # Read Conditional Access policies
	- AuthenticationContext.Read.All         # Read authentication context classes
	- RoleManagement.Read.Directory          # Read directory role assignments
	- RoleManagement.Read.All                # Read all role management data
	- PrivilegedAccess.Read.AzureADGroup     # Read PIM group policies
	- InformationProtectionPolicy.Read.All   # Read sensitivity labels
	- User.Read.All                          # Read user profiles
	- Application.Read.All                   # Read application registrations
	- AuditLog.Read.All                      # Read audit logs (for PIM policies)
	- CrossTenantInformation.ReadBasic.All   # Read tenant information
	- Sites.Read.All                         # Read SharePoint sites via Graph
	
	Exchange Online Management:
	- View-Only Organization Management role  # Read Exchange configuration
	- Or Global Reader role                   # Alternative read-only access
	
	SharePoint Online:
	- SharePoint Administrator role           # Full SharePoint read access
	- Or Global Reader role                   # Alternative read-only access
	
	Azure (Optional - for Azure Resource PIM):
	- Reader role on target subscriptions     # Read Azure resource configuration
	- Security Reader role                    # Read security configurations
	#>
	[CmdletBinding()]
	param(
		[Parameter()]
		[Alias('Tenant')]
		[ValidatePattern('^[a-z0-9-]+$')]
		[string]$TenantName,
	
		[Parameter()]
		[Alias('OutPath')]
		[ValidateScript({
				if (!(Test-Path $_)) {
					try {
						New-Item -ItemType Directory -Force -Path $_ | Out-Null
						return $true
					}
					catch {
						throw "Cannot create output directory: $_"
					}
				}
				return $true
			})]
		[string]$OutputPath = 'C:\Reports\M365AuthContext\',
	
		[Parameter()]
		[Alias('UPN')]
		[ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
		[string]$UserPrincipalName,
	
		[Parameter()]
		[Alias('Credential')]
		[System.Management.Automation.PSCredential]$SharePointOnlineCredential,
	
		[Parameter()]
		[Alias('Silent')]
		[switch]$Quiet,
	
		[Parameter()]
		[switch]$NoProgress,
	
		[Parameter()]
		[Alias('HtmlPath')]
		[ValidatePattern('\.html?$')]
		[string]$HtmlReportPath,
	
		[Parameter()]
		[Alias('DoNotOpen')]
		[switch]$NoAutoOpen,
	
		[Parameter()]
		[Alias('NoAzurePIM')]
		[switch]$ExcludeAzure,
	
		[Parameter()]
		[Alias('SubscriptionIds', 'SubIds')]
		[ValidateScript({
				foreach ($id in $_) {
					if ($id -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
						throw "Invalid subscription ID format: $id"
					}
				}
				return $true
			})]
		[string[]]$AzureSubscriptionIds
		,
		[Parameter()]
		[ValidateSet('Classic', 'Dark')]
		[string]$HtmlStyle = 'Classic'
		,
		[Parameter()]
		[ValidateSet('TabbedOverview', 'Classic', 'Tabbed', 'Sidebar', 'Masonry', 'Dashboard', 'Layoutv2')]
		[string]$HtmlLayout = 'TabbedOverview'
		,
		[Parameter()]
		[switch]$HtmlAllLayoutThemes
		,
		[Parameter()]
		[switch]$HtmlAllLayouts
	)

	begin {
		# Ensure module state is properly initialized
		if (-not $script:ModuleVersion) {
			Write-Warning 'Module state not initialized. Some features may not work correctly.'
		}
	
		# Log the start of the operation
		Write-ModuleLog -Message 'Starting Authentication Context Inventory Report' -Level Info
		Write-ModuleLog -Message "Parameters: TenantName=$TenantName, OutputPath=$OutputPath, ExcludeAzure=$ExcludeAzure" -Level Debug
	
		# Set script-level variables for use in nested functions
		$script:ReportQuiet = $Quiet
		$script:ReportNoProgress = $NoProgress
	}

	process {
		try {
	
			# Call the core inventory function
			$reportParams = @{
				Quiet        = $Quiet
				NoProgress   = $NoProgress
				OutputPath   = $OutputPath
				ExcludeAzure = $ExcludeAzure
			}
		
			# Add optional parameters only if provided
			if ($TenantName) { $reportParams['TenantName'] = $TenantName }
			if ($UserPrincipalName) { $reportParams['UserPrincipalName'] = $UserPrincipalName }
			if ($SharePointOnlineCredential) { $reportParams['SharePointOnlineCredential'] = $SharePointOnlineCredential }
			if ($HtmlReportPath) { $reportParams['HtmlReportPath'] = $HtmlReportPath }
			if ($NoAutoOpen) { $reportParams['NoAutoOpen'] = $NoAutoOpen }
			if ($AzureSubscriptionIds) { $reportParams['AzureSubscriptionIds'] = $AzureSubscriptionIds }
			if ($HtmlStyle) { $reportParams['HtmlStyle'] = $HtmlStyle }
			if ($HtmlLayout) { $reportParams['HtmlLayout'] = $HtmlLayout }
			if ($HtmlAllLayoutThemes) { $reportParams['HtmlAllLayoutThemes'] = $HtmlAllLayoutThemes }
			if ($HtmlAllLayouts) { $reportParams['HtmlAllLayouts'] = $HtmlAllLayouts }
		
			# Invoke the core function
			$result = Invoke-AuthContextInventoryCore @reportParams
		
			# Return the report path
			return $result
		}
		catch {
			Write-ModuleLog -Message "Error during report generation: $_" -Level Error
			throw
		}
	}

	end {
		Write-ModuleLog -Message 'Authentication Context Inventory Report completed' -Level Info
	
		if (-not $Quiet) {
			Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
			Write-Host '  Report Generation Complete' -ForegroundColor Green
			Write-Host "  Log file: $script:LogPath" -ForegroundColor Gray
			Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
		}
	}
}