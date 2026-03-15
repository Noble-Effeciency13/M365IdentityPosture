function ConvertTo-GraphBatchUrl {
	<#!
	.SYNOPSIS
		Normalizes a Microsoft Graph URL for use inside a $batch request.

	.DESCRIPTION
		Microsoft Graph $batch sub-requests require a URL that is relative to the service root.
		This helper accepts:
		- a service-root relative URL (e.g. /users/{id})
		- a versioned relative URL (e.g. /v1.0/users/{id} or /beta/users/{id})
		- a full Graph URL (e.g. https://graph.microsoft.com/v1.0/users/{id})
		and returns a service-root relative URL.

	.PARAMETER Url
		The URL to normalize.

	.OUTPUTS
		System.String
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Url
	)

	$u = $Url.Trim()

	# Allow callers to pass full Graph URLs; convert to relative.
	if ($u -match '^https?://graph\.microsoft\.com/') {
		try {
			$uri = [uri]$u
			$u = $uri.AbsolutePath
			if ($uri.Query) { $u += $uri.Query }
		}
		catch {
			Write-Verbose "Failed to parse Graph URL $u; continuing with original value: $_"
		}
	}

	# Ensure leading slash.
	if (-not $u.StartsWith('/')) { $u = '/' + $u }

	# Strip version prefix if present. In $batch, the URL must be relative to the service root.
	if ($u.StartsWith('/v1.0/')) { $u = $u.Substring(5) }
	elseif ($u.StartsWith('/beta/')) { $u = $u.Substring(5) }

	return $u
}
