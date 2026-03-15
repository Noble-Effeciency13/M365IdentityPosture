#Requires -Version 7.0
#Requires -PSEdition Core

<#
.SYNOPSIS
    M365 Identity & Security Posture Assessment Module
.DESCRIPTION
    Comprehensive identity and access security reporting framework for Microsoft 
    cloud services. Provides assessment tools for Authentication Context, Access 
    Package documentation with interactive visualization, Role Assignments, 
    Conditional Access policies, and related security configurations across 
    Microsoft 365, Azure AD/Entra ID, and hybrid scenarios.
.NOTES
    Module Name: M365IdentityPosture
    Author: Sebastian Flæng Markdanner
    Website: https://chanceofsecurity.com
    GitHub: https://github.com/Noble-Effeciency13/M365IdentityPosture
    Version: 1.1.0
#>

# Module configuration
$script:ModuleRoot = $PSScriptRoot
$script:ModuleName = 'M365IdentityPosture'
$script:ModuleVersion = '1.1.0'
$script:ToolVersion = $script:ModuleVersion

# Initialize module-scoped variables
$script:graphConnected = $false
$script:CurrentTenantId = $null
$script:TenantShortName = $null
$script:LogPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "$($script:ModuleName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Authentication data containers (module-scoped)
$script:PurviewAuthenticationData = $null
$script:SharePointAuthenticationData = $null
$script:AzureAuthenticationData = $null
$script:AllSensitivityLabels = $null

# Role name cache for performance optimization
$script:__AuthContext_RoleNameCache = @{}

# Load core internal functions early (logging + banner) so they are available during module initialization.
try {
	. (Join-Path -Path $PSScriptRoot -ChildPath 'Private\Utilities\Write-ModuleLog.ps1')
	. (Join-Path -Path $PSScriptRoot -ChildPath 'Private\Utilities\Show-ModuleBanner.ps1')
}
catch {
	throw "Failed to load core module utilities (Write-ModuleLog/Show-ModuleBanner): $($_.Exception.Message)"
}

# Initialize module logging
Write-ModuleLog -Message "Module initialization started: $script:ModuleName v$script:ModuleVersion" -Level Info -NoConsole
Write-ModuleLog -Message "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Info -NoConsole
Write-ModuleLog -Message "Operating System: $($PSVersionTable.OS)" -Level Info -NoConsole

# Get function definition files
Write-ModuleLog -Message 'Loading module functions...' -Level Verbose -NoConsole

# Recursively discover ALL private function files (any subfolder under Private)
$privateRoot = Join-Path $PSScriptRoot 'Private'
$Private = @()
if (Test-Path $privateRoot) {
	$Private = Get-ChildItem -Path $privateRoot -Filter '*.ps1' -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName
	# These are loaded explicitly above (needed early in module initialization).
	$Private = @(
		$Private | Where-Object {
			$_.FullName -notlike '*\Private\Utilities\Write-ModuleLog.ps1' -and
			$_.FullName -notlike '*\Private\Utilities\Show-ModuleBanner.ps1'
		}
	)
	# Group for logging by relative folder
	$grouped = $Private | Group-Object { Split-Path $_.FullName -Parent }
	foreach ($g in $grouped) {
		$relative = ($g.Name -replace [Regex]::Escape($privateRoot), 'Private')
		Write-ModuleLog -Message ('Found {0} functions in {1}' -f $g.Count, $relative) -Level Verbose -NoConsole
	}
	Write-ModuleLog -Message ('Total private function files discovered recursively: {0}' -f ($Private.Count)) -Level Verbose -NoConsole
}

# Load public functions AFTER private functions
$Public = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
Write-ModuleLog -Message "Found $($Public.Count) public functions" -Level Verbose -NoConsole

Write-ModuleLog -Message "Total functions to load: $($Public.Count + $Private.Count)" -Level Verbose -NoConsole

# Dot source the function files - PRIVATE FIRST, then PUBLIC
$functionLoadErrors = @()

# Load private functions
foreach ($import in $Private) {
	try {
		Write-ModuleLog -Message "Importing private function: $($import.Name)" -Level Verbose -NoConsole
		. $import.FullName
	}
	catch {
		$errorMsg = "Failed to import private function $($import.Name): $_"
		Write-ModuleLog -Message $errorMsg -Level Error
		$functionLoadErrors += $errorMsg
	}
}

# Load public functions (they can now access private functions)
foreach ($import in $Public) {
	try {
		Write-ModuleLog -Message "Importing public function: $($import.Name)" -Level Verbose -NoConsole
		. $import.FullName
	}
	catch {
		$errorMsg = "Failed to import public function $($import.Name): $_"
		Write-ModuleLog -Message $errorMsg -Level Error
		$functionLoadErrors += $errorMsg
	}
}

if ($functionLoadErrors.Count -gt 0) {
	throw "Module initialization failed. $($functionLoadErrors.Count) functions failed to load. Check the log at: $script:LogPath"
}

# Export only the public functions
if ($Public.Count -gt 0) {
	Export-ModuleMember -Function $Public.BaseName
	Write-ModuleLog -Message "Exported $($Public.Count) public functions: $($Public.BaseName -join ', ')" -Level Verbose -NoConsole
}

# Also explicitly export the Write-ModuleLog function for use in public functions
Export-ModuleMember -Function 'Write-ModuleLog'

# Module initialization complete
Write-ModuleLog -Message 'Module initialization completed successfully' -Level Success -NoConsole

# Display module information when loaded interactively
if ($Host.Name -eq 'ConsoleHost' -and -not $env:M365IdentityPosture_QUIET) {
	# Check if we're being called from within our own module functions
	$callStack = Get-PSCallStack
	$isInternalCall = $callStack | Where-Object { 
		$_.Command -like 'Invoke-AuthContext*' -or 
		$_.InvocationInfo.MyCommand.Module.Name -eq $script:ModuleName 
	}
    
	# Only show banner and version check on initial import, not during function execution
	if (-not $isInternalCall) {
		# Check for module updates (silent if PSGallery unavailable)
		Test-ModuleVersion
		
		# Display module banner
		Show-ModuleBanner -MinWidth 67
	}
}

# Module cleanup on removal
$OnRemoveScript = {
	Write-ModuleLog -Message 'Module removal initiated' -Level Info -NoConsole
    
	# Disconnect from services if connected
	if ($script:graphConnected) {
		try {
			Write-ModuleLog -Message 'Disconnecting from Microsoft Graph' -Level Info -NoConsole
			Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
		}
		catch {
			Write-Verbose "Failed to disconnect from Microsoft Graph: $_"
		}
	}
    
	# Clean up SharePoint connection
	if (Get-Module Microsoft.Online.SharePoint.PowerShell) {
		try {
			Write-ModuleLog -Message 'Disconnecting from SharePoint Online' -Level Info -NoConsole
			Disconnect-SPOService -ErrorAction SilentlyContinue | Out-Null
		}
		catch {
			Write-Verbose "Failed to disconnect from SharePoint Online: $_"
		}
	}
    
	# Clean up Exchange Online connection
	if (Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' }) {
		try {
			Write-ModuleLog -Message 'Disconnecting from Exchange Online' -Level Info -NoConsole
			Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
		}
		catch {
			Write-Verbose "Failed to disconnect from Exchange Online: $_"
		}
	}
    
	# Clean up Azure connection
	$azContext = Get-AzContext -ErrorAction SilentlyContinue
	if ($azContext) {
		try {
			Write-ModuleLog -Message 'Disconnecting from Azure' -Level Info -NoConsole
			Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
		}
		catch {
			Write-Verbose "Failed to disconnect from Azure: $_"
		}
	}
    
	Write-ModuleLog -Message 'Module removal completed' -Level Info -NoConsole
	Write-Verbose "$script:ModuleName module removed and connections cleaned up"
}

$ExecutionContext.SessionState.Module.OnRemove += $OnRemoveScript

# Module is ready
Write-ModuleLog -Message 'Module ready for use' -Level Success -NoConsole
Write-Verbose "Module $script:ModuleName v$script:ModuleVersion loaded successfully"

# Test that critical functions are available
$criticalFunctions = @('Invoke-AuthContextInventoryCore', 'Invoke-Preflight', 'Invoke-GraphPhase')
$missingFunctions = @()
foreach ($func in $criticalFunctions) {
	if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
		$missingFunctions += $func
		Write-ModuleLog -Message "Critical function missing: $func" -Level Error -NoConsole
	}
}

if ($missingFunctions.Count -gt 0) {
	Write-Warning "Module loaded with missing critical functions: $($missingFunctions -join ', ')"
	Write-Warning 'Some features may not work correctly.'
}