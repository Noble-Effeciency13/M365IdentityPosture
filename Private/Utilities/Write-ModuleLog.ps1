function Write-ModuleLog {
	<#!
	.SYNOPSIS
		Writes a structured log entry for this module.

	.DESCRIPTION
		Writes to a module-scoped log file (when configured) and optionally to console output.
		Designed for both interactive UX and troubleshooting.

	.PARAMETER Message
		The log message.

	.PARAMETER Level
		Severity level.

	.PARAMETER NoConsole
		Suppress console output.
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,

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
		Write-Verbose ("Failed to write log entry to {0}: {1}" -f $script:LogPath, $_.Exception.Message)
	}

	# Write to appropriate stream unless suppressed
	if (-not $NoConsole) {
		switch ($Level) {
			'Warning' { Write-Warning $Message }
			'Error' { Write-Error $Message }
			'Debug' { Write-Debug $Message }
			'Verbose' { Write-Verbose $Message }
			'Success' { Write-Information $Message -InformationAction Continue }
			default { Write-Information $Message -InformationAction Continue }
		}
	}
}
