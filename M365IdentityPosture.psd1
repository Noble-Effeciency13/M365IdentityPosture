@{
	# Script module or binary module file associated with this manifest.
	RootModule           = 'M365IdentityPosture.psm1'
    
	# Version number of this module.
	ModuleVersion        = '1.0.0'
    
	# Supported PSEditions
	CompatiblePSEditions = @('Core')
    
	# ID used to uniquely identify this module
	GUID                 = 'a7c4b9e2-3f5d-4e8a-9c1b-2d6f8e9a5b7c'
    
	# Author of this module
	Author               = 'Sebastian Flæng Markdanner'
    
	# Company or vendor of this module
	CompanyName          = 'Chance of Security'
    
	# Copyright statement for this module
	Copyright            = '(c) 2025 Sebastian Flæng Markdanner. All rights reserved.'
    
	# Description of the functionality provided by this module
	Description          = @'
Comprehensive security posture assessment and identity governance reporting framework for Microsoft 365 and Azure environments.

Current Release (v1.0): Authentication Context Inventory
- Complete discovery and analysis of authentication context usage across all Microsoft 365 services
- Purview sensitivity labels with embedded authentication requirements
- Conditional Access policies referencing authentication contexts
- Privileged Identity Management (PIM) policies for directory roles, groups, and Azure resources
- SharePoint sites with direct or inherited authentication context assignments
- Microsoft 365 Groups and Teams with context-enforcing sensitivity labels
- Protected actions (RBAC) requiring authentication contexts
- Cross-service correlation with rich HTML reporting and metrics dashboard

Designed as an extensible framework for future identity and security analytics including Access Package reporting, 
Role Assignment auditing, Conditional Access gap analysis, and Identity Protection insights.
'@
    
	# Minimum version of the PowerShell engine required by this module
	PowerShellVersion    = '7.0'
    
	# Name of the PowerShell host required by this module
	# PowerShellHostName = ''
    
	# Minimum version of the PowerShell host required by this module
	# PowerShellHostVersion = ''
    
	# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
	# DotNetFrameworkVersion = ''
    
	# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
	# ClrVersion = ''
    
	# Processor architecture (None, X86, Amd64) required by this module
	# ProcessorArchitecture = ''
    
	# Modules that must be imported into the global environment prior to importing this module
	RequiredModules      = @()
    
	# Assemblies that must be loaded prior to importing this module
	# RequiredAssemblies = @()
    
	# Script files (.ps1) that are run in the caller's environment prior to importing this module.
	# ScriptsToProcess = @()
    
	# Type files (.ps1xml) to be loaded when importing this module
	# TypesToProcess = @()
    
	# Format files (.ps1xml) to be loaded when importing this module
	# FormatsToProcess = @()
    
	# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
	# NestedModules = @()
    
	# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
	FunctionsToExport    = @(
		'Invoke-AuthContextInventoryReport'
	)
    
	# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
	CmdletsToExport      = @()
    
	# Variables to export from this module
	VariablesToExport    = @()
    
	# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
	AliasesToExport      = @()
    
	# DSC resources to export from this module
	# DscResourcesToExport = @()
    
	# List of all modules packaged with this module
	# ModuleList = @()
    
	# List of all files packaged with this module
	# FileList = @()
    
	# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData          = @{
		PSData = @{
			# Tags applied to this module. These help with module discovery in online galleries.
			Tags                       = @(
				'Microsoft365',
				'M365',
				'Reporting',
				'AuthenticationContext',
				'ConditionalAccess',
				'MicrosoftGraph',
				'Azure',
				'EntraID',
				'AzureAD',
				'PIM',
				'PrivilegedIdentityManagement',
				'Purview',
				'SensitivityLabels',
				'SharePoint',
				'SharePointOnline',
				'SPO',
				'Teams',
				'MicrosoftTeams',
				'Security',
				'Compliance',
				'Governance',
				'IdentityGovernance',
				'ZeroTrust',
				'RBAC'
			)
            
			# A URL to the license for this module.
			LicenseUri                 = 'https://github.com/Noble-Effeciency13/M365IdentityPosture/blob/main/LICENSE'
            
			# A URL to the main website for this project.
			ProjectUri                 = 'https://github.com/Noble-Effeciency13/M365IdentityPosture'
            
			# A URL to an icon representing this module.
			# IconUri = ''
            
			# ReleaseNotes of this module
			ReleaseNotes               = @'
## Version 1.0.0 - 2025-10-21
Initial release of M365IdentityPosture module

### Features
- Authentication Context inventory across all Microsoft 365 services
- Purview sensitivity label analysis with authentication context detection
- Conditional Access policy mapping and analysis
- Privileged Identity Management (PIM) comprehensive coverage:
  - Directory role management policies
  - Group-based PIM with role assignments
  - Azure resource PIM (optional)
- SharePoint Online direct and inherited context detection
- Microsoft 365 Groups/Teams label inheritance tracking
- Protected actions (RBAC) authentication requirements
- Rich HTML reporting with runtime theme switching
- Cross-service correlation and metrics dashboard

### Technical Highlights
- PowerShell 7+ cross-platform support
- Dynamic module loading for optimal performance
- Comprehensive error handling and logging
- Memory-efficient processing for large tenants
- Modular architecture for future expansion

### Requirements
- PowerShell 7.0 or later
- Microsoft Graph and service-specific modules (auto-loaded)
- Global Reader or equivalent permissions

### Known Limitations
- Read-only operations (no tenant modifications)
- Azure PIM requires subscription-level access
- Large tenant processing may take extended time

For complete documentation, visit:
https://github.com/Noble-Effeciency13/M365IdentityPosture
'@
            
			# Prerelease string of this module
			# Prerelease = ''
            
			# Flag to indicate whether the module requires explicit user acceptance for install/update/save
			RequireLicenseAcceptance   = $false
            
			# External dependent modules of this module
			ExternalModuleDependencies = @(
				'Microsoft.Graph.Authentication',
				'Microsoft.Graph.Groups',
				'ExchangeOnlineManagement',
				'Microsoft.Online.SharePoint.PowerShell',
				'Az.Accounts',
				'Az.Resources'
			)
		} # End of PSData hashtable
	} # End of PrivateData hashtable
    
	# HelpInfo URI of this module
	# HelpInfoURI = ''
    
	# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
	# DefaultCommandPrefix = ''
}