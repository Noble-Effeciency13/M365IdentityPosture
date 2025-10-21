function Invoke-ModuleOperation {
	<#
	.SYNOPSIS
		Consolidated module management: import, install, or validate modules with optional WinPS compatibility.

	.DESCRIPTION
		Handles module installation, import validation, and availability checking in a consistent manner.
		Supports Windows PowerShell compatibility mode for PowerShell Core when needed.

	.PARAMETER Name
		Module name to operate on.

	.PARAMETER Operation
		Operation to perform: Import (default), Install, or Validate.

	.PARAMETER WinPSCompat
		Use Windows PowerShell compatibility mode on PowerShell Core.

	.PARAMETER Force
		Force reinstallation when using Install operation.

	.PARAMETER QuietMode
		Suppress informational output and warnings.

	.OUTPUTS
		Import: PSCustomObject with Name, Success, WinPSCompat properties or $null on failure.
		Install: No return value.
    	Validate: Boolean indicating module availability.

	.EXAMPLE
		Invoke-ModuleOperation -Name 'Microsoft.Graph.Authentication' -Operation Import
		
	.EXAMPLE
		Invoke-ModuleOperation -Name 'Microsoft.Online.SharePoint.PowerShell' -Operation Import -WinPSCompat
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][string]$Name,
		[ValidateSet('Import', 'Install', 'Validate')][string]$Operation = 'Import',
		[switch]$WinPSCompat,
		[switch]$Force,
		[switch]$QuietMode
	)
  
	switch ($Operation) {
		'Install' {
			if (-not (Get-Module -ListAvailable -Name $Name)) {
				if (-not $QuietMode) { Write-Host "Installing module $Name ..." -ForegroundColor Yellow }
				Install-Module $Name -Scope CurrentUser -Force:$Force -ErrorAction Stop
			}
		}
		'Import' {
			if (-not (Get-Module -Name $Name)) {
				try {
					if ($PSVersionTable.PSEdition -eq 'Core' -and $WinPSCompat) {
						Import-Module $Name -UseWindowsPowerShell -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
					}
					else {
						Import-Module $Name -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
					}
					return [pscustomobject]@{ Name = $Name; Success = $true; WinPSCompat = $WinPSCompat.IsPresent }
				}
				catch {
					if (-not $QuietMode) { Write-Warning "Failed to import module '$Name': $($_.Exception.Message)" }
					return $null
				}
			}
			else {
				# Module already loaded - return success object
				return [pscustomobject]@{ Name = $Name; Success = $true; WinPSCompat = $WinPSCompat.IsPresent }
			}
		}
		'Validate' {
			if (-not (Get-Module -ListAvailable -Name $Name)) {
				if (-not $QuietMode) { Write-Warning "Required module '$Name' is not installed. Please install it: Install-Module $Name -Scope CurrentUser" }
				return $false
			}
			return $true
		}
	}
}
