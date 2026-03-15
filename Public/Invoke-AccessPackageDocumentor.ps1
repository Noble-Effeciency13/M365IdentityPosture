function Invoke-AccessPackageDocumentor {
	<#!
	.SYNOPSIS
		Generates an interactive HTML documentation of Microsoft Entra Access Packages, policies, and resources.

	.DESCRIPTION
		Read-only report that inventories Access Packages, assignment policies (approval steps, justification, verified ID),
		and linked resources, then renders an interactive light/dark HTML documentation with zoom and export. Uses Microsoft Graph
		REST v1.0 only; no beta SDK calls.

	.PARAMETER OutputPath
		Directory for the HTML report. Default: C:\Reports\M365AccessPackages\

	.PARAMETER HtmlReportPath
		Optional explicit HTML file path. If omitted, a timestamped file is created under OutputPath.

	.PARAMETER Theme
		Preferred theme: Auto (default), Light, Dark.

	.PARAMETER TenantId
		The tenant ID of the Entra ID tenant used for authentication. Required when using a custom app registration.

	.PARAMETER ClientId
		The application (client) ID for the Microsoft Graph API authentication. Required when using a custom app registration.

	.PARAMETER Quiet
		Suppress non-essential console output.

	.PARAMETER NoAutoOpen
		Do not automatically open the generated report.

	.PARAMETER ExportCsv
		Export access package data to CSV files (one per entity type: packages, policies, resources).

	.OUTPUTS
		String path to the generated HTML report.
	#>
	[CmdletBinding()] param(
		[Parameter()][ValidateScript({ if (!(Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }; $true })][string]$OutputPath = 'C:\Reports\M365AccessPackages\',
		[Parameter()][ValidatePattern('\.html?$')][string]$HtmlReportPath,
		[Parameter()][ValidateSet('Auto','Light','Dark')][string]$Theme = 'Auto',
		[string]$TenantId,
		[string]$ClientId,
		[switch]$Quiet,
		[switch]$NoAutoOpen,
		[switch]$ExportCsv
	)

	begin {
		Write-ModuleLog -Message 'Starting Access Package Documentor Report' -Level Info
	}

	process {
		try {
			$params = @{ OutputPath = $OutputPath; HtmlReportPath = $HtmlReportPath; Theme = $Theme; TenantId = $TenantId; ClientId = $ClientId; Quiet = $Quiet; NoAutoOpen = $NoAutoOpen; IncludeBeta = $true; ExportCsv = $ExportCsv }
			$result = Invoke-AccessPackageDocumentorCore @params
			return $result
		}
		catch {
			Write-ModuleLog -Message "Error during Access Package report generation: $_" -Level Error
			throw
		}
	}

	end {
		Write-ModuleLog -Message 'Access Package Documentor Report completed' -Level Info
	}
}
