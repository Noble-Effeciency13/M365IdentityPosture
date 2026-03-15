function Show-ModuleBanner {
	<#!
	.SYNOPSIS
		Displays the module banner and available commands in interactive sessions.

	.DESCRIPTION
		Renders a simple console banner for interactive use. Suppressed when:
		- the M365IdentityPosture_QUIET environment variable is set
		- or the host is not ConsoleHost

	.PARAMETER MinWidth
		Minimum banner width.

	.PARAMETER Force
		Force output even when quiet conditions would suppress it.

	.PARAMETER NoCommands
		Do not list available exported commands.
	#>
	[CmdletBinding()] param(
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
			$root = if ($script:ModuleRoot) { $script:ModuleRoot } else { $PSScriptRoot }
			$publicPath = Join-Path -Path $root -ChildPath 'Public'
			$publicFunctions = Get-ChildItem -Path $publicPath -Filter '*.ps1' -ErrorAction SilentlyContinue |
				ForEach-Object { $_.BaseName } | Sort-Object
			foreach ($func in $publicFunctions) {
				Write-Host "  • $func" -ForegroundColor Green
			}
			Write-Host ''
			Write-Host 'For help on any command, run: ' -NoNewline -ForegroundColor DarkGray
			Write-Host 'Get-Help <CommandName> -Detailed' -ForegroundColor White
			Write-Host ''
		}
	}
	catch {
		Write-Host 'M365 Reporting Framework loaded.' -ForegroundColor Cyan
	}
}
