#Requires -Version 7.0
#Requires -PSEdition Core

<#
.SYNOPSIS
    M365 Identity & Security Posture Assessment Module
.DESCRIPTION
    Comprehensive identity and access security reporting framework for Microsoft 
    cloud services. Provides assessment tools for Authentication Context, Access 
    Packages, Role Assignments, Conditional Access, and related security 
    configurations across Microsoft 365, Azure AD/Entra ID, and hybrid scenarios.
.NOTES
    Module Name: M365IdentityPosture
    Author: Sebastian Flæng Markdanner
    Website: https://chanceofsecurity.com
    Version: 1.0.0
#>

# Module configuration
$script:ModuleRoot = $PSScriptRoot
$script:ModuleName = 'M365IdentityPosture'
$script:ModuleVersion = '1.0.0'
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

# Internal logging function (define before using)
function Write-ModuleLog {
	param(
		[Parameter(Mandatory)]
		[string]$Message,
        
		[ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Verbose', 'Success')]
		[string]$Level = 'Info',
        
		[switch]$NoConsole
	)
    
	$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
	$logEntry = "$timestamp [$Level] $Message"
    
	# Write to log file
	try {
		if ($script:LogPath) {
			Add-Content -Path $script:LogPath -Value $logEntry -ErrorAction SilentlyContinue
		}
	}
	catch {
		# Silently continue if log write fails
	}
    
	# Write to appropriate stream unless suppressed
	if (-not $NoConsole) {
		switch ($Level) {
			'Warning' { Write-Warning $Message }
			'Error' { Write-Error $Message }
			'Debug' { Write-Debug $Message }
			'Verbose' { Write-Verbose $Message }
			'Success' { Write-Host $Message -ForegroundColor Green }
			default { Write-Information $Message -InformationAction Continue }
		}
	}
}

# Dynamic banner display helper (internal)
function Show-ModuleBanner {
	param(
		[int]$MinWidth = 65,
		[switch]$Force,
		[switch]$NoCommands
	)

	if (-not $Force) {
		if ($env:M365IdentityPosture_QUIET -or $Host.Name -ne 'ConsoleHost') { return }
	}

	try {
		$primaryLines = @(
			"M365 Identity & Security Posture v$script:ModuleVersion",
			'Identity, Access & Security Reporting for Microsoft Cloud'
		)
		$infoLines = @(
			'Author: Sebastian Flæng Markdanner',
			'Website: https://chanceofsecurity.com'
		)

		$maxLen = @($primaryLines + $infoLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
		$innerWidth = [Math]::Max($MinWidth, $maxLen)

		$top = '╔' + ('═' * ($innerWidth + 2)) + '╗'
		$midSep = '╠' + ('═' * ($innerWidth + 2)) + '╣'
		$bottom = '╚' + ('═' * ($innerWidth + 2)) + '╝'

		Write-Host ''
		Write-Host $top -ForegroundColor Cyan
		foreach ($l in $primaryLines) {
			$padTotal = $innerWidth - $l.Length
			$leftPad = [int][Math]::Floor($padTotal / 2)
			$rightPad = $padTotal - $leftPad
			Write-Host ('║ ' + (' ' * $leftPad) + $l + (' ' * $rightPad) + ' ║') -ForegroundColor Cyan
		}
		Write-Host $midSep -ForegroundColor Cyan
		foreach ($l in $infoLines) {
			$padTotal = $innerWidth - $l.Length
			$leftPad = [int][Math]::Floor($padTotal / 2)
			$rightPad = $padTotal - $leftPad
			Write-Host ('║ ' + (' ' * $leftPad) + $l + (' ' * $rightPad) + ' ║') -ForegroundColor DarkGray
		}
		Write-Host $bottom -ForegroundColor Cyan
		Write-Host ''

		if (-not $NoCommands) {
			Write-Host 'Available Commands:' -ForegroundColor Yellow
			Write-Host '  • Invoke-AuthContextInventoryReport' -ForegroundColor Green
			Write-Host ''
			Write-Host 'For help, run: ' -NoNewline -ForegroundColor DarkGray
			Write-Host 'Get-Help Invoke-AuthContextInventoryReport -Detailed' -ForegroundColor White
			Write-Host ''
		}
	}
	catch {
		Write-Host 'M365 Reporting Framework loaded.' -ForegroundColor Cyan
	}
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
    
	# Only show banner on initial import, not during function execution
	if (-not $isInternalCall) {
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
			# Silently continue
		}
	}
    
	# Clean up SharePoint connection
	if (Get-Module Microsoft.Online.SharePoint.PowerShell) {
		try {
			Write-ModuleLog -Message 'Disconnecting from SharePoint Online' -Level Info -NoConsole
			Disconnect-SPOService -ErrorAction SilentlyContinue | Out-Null
		}
		catch {
			# Silently continue
		}
	}
    
	# Clean up Exchange Online connection
	if (Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' }) {
		try {
			Write-ModuleLog -Message 'Disconnecting from Exchange Online' -Level Info -NoConsole
			Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
		}
		catch {
			# Silently continue
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
			# Silently continue
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