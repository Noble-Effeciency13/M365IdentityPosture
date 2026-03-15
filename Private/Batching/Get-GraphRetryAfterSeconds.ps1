function Get-GraphRetryAfterSeconds {
	<#!
	.SYNOPSIS
		Extracts a Retry-After delay (seconds) from a Microsoft Graph error.

	.DESCRIPTION
		Used by retry logic to honor Graph throttling and backoff guidance.
		Returns $null when Retry-After is not present or cannot be parsed.

	.PARAMETER ErrorRecord
		The caught error record from Invoke-MgGraphRequest.

	.OUTPUTS
		System.Nullable[Int32]
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)]$ErrorRecord
	)

	$retryAfter = $null
	try {
		$headers = $ErrorRecord.Exception.Response.Headers
		if ($headers) {
			# Can be string, array, or typed header object.
			$ra = $headers['Retry-After']
			if ($ra) {
				if ($ra -is [System.Array]) { $retryAfter = $ra[0] } else { $retryAfter = $ra }
			}
		}
	}
	catch { Write-Verbose "Failed to parse Retry-After header: $($_)" }

	if ($retryAfter) {
		[int]$secs = 0
		if ([int]::TryParse([string]$retryAfter, [ref]$secs)) { return [Math]::Max(1, $secs) }
	}

	return $null
}
