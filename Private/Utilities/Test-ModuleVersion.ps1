function Test-ModuleVersion {
	<#
	.SYNOPSIS
		Checks if the current module version is up to date with PSGallery.
	
	.DESCRIPTION
		Compares the currently loaded module version against the latest version
		available on PowerShell Gallery. Displays a warning if an update is available.
		Runs silently if the module is current or if PSGallery is unreachable.
	
	.PARAMETER ModuleName
		Name of the module to check. Defaults to M365IdentityPosture.
	
	.PARAMETER CurrentVersion
		Current version of the module. Defaults to script-scoped version.
	
	.EXAMPLE
		Test-ModuleVersion
		Checks if M365IdentityPosture module has updates available.
	#>
	[CmdletBinding()]
	param(
		[Parameter()]
		[string]$ModuleName = 'M365IdentityPosture',
		
		[Parameter()]
		[version]$CurrentVersion = $script:ModuleVersion
	)
	
	try {
		# Suppress progress bars for faster execution
		$oldProgressPreference = $ProgressPreference
		$ProgressPreference = 'SilentlyContinue'
		
		# Query PSGallery for latest version
		$published = Find-Module -Name $ModuleName -Repository PSGallery -ErrorAction Stop
		
		if ($published -and $published.Version) {
			$latestVersion = [version]$published.Version
			
			# Compare versions
			if ($latestVersion -gt $CurrentVersion) {
				$message = @"

╔════════════════════════════════════════════════════════════════════════════════╗
║                           UPDATE AVAILABLE                                     ║
╠════════════════════════════════════════════════════════════════════════════════╣
║  A newer version of $ModuleName is available!                        ║
║                                                                                ║
║  Current Version:  $CurrentVersion                                                      ║
║  Latest Version:   $latestVersion                                                      ║
║                                                                                ║
║  Update Command:                                                               ║
║  Update-Module -Name $ModuleName -Force                                ║
║                                                                                ║
║  Release Notes:                                                                ║
║  https://github.com/Noble-Effeciency13/M365IdentityPosture/releases           ║
╚════════════════════════════════════════════════════════════════════════════════╝

"@
				Write-Warning $message
			}
		}
	}
	catch {
		# Silently ignore errors (network issues, PSGallery unavailable, etc.)
		Write-ModuleLog -Message "Version check failed: $($_.Exception.Message)" -Level Debug -NoConsole
	}
	finally {
		$ProgressPreference = $oldProgressPreference
	}
}
