function Use-ScopedModules {
	<#
	.SYNOPSIS
		Temporarily imports specified modules for the duration of a scriptblock.

	.DESCRIPTION
		Captures which modules required importing, executes the provided scriptblock, then removes only those imported
		modules (leaving pre-existing imports intact). Useful to avoid long-lived assembly conflicts.

	.PARAMETER Names
		Array of module names to ensure within scope.

	.PARAMETER Action
		Scriptblock executed after ensuring all modules are imported.

	.PARAMETER QuietMode
		Suppress informational import/remove messages.

	.OUTPUTS
		Returns the output from the executed scriptblock.

	.EXAMPLE
		Use-ScopedModules -Names 'ExchangeOnlineManagement' -Action { Get-Label }
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][string[]]$Names,
		[Parameter(Mandatory)][scriptblock]$Action,
		[switch]$QuietMode
	)
	$imported = @()
	foreach ($moduleName in $Names) {
		if (-not (Get-Module -Name $moduleName)) {
			try {
				Invoke-ModuleOperation -Name $moduleName -Operation Import | Out-Null
				$imported += $moduleName
				if (-not $QuietMode) { Write-Host ('[Scoped] Imported {0}' -f $moduleName) -ForegroundColor DarkGray }
			}
			catch {
				$errorMessage = $_.Exception.Message
				$formattedMessage = 'Failed to import scoped module {0}: {1}' -f $moduleName, $errorMessage
				throw $formattedMessage
			}
		}
	}
	try { & $Action } finally {
		foreach ($moduleName in $imported) {
			try { Remove-Module $moduleName -Force -ErrorAction SilentlyContinue } catch { }
			if (-not $QuietMode) { Write-Host ('[Scoped] Removed {0}' -f $moduleName) -ForegroundColor DarkGray }
		}
	}
}
