function Invoke-GraphRequestSafe {
	<#!
	.SYNOPSIS
		Invokes Microsoft Graph requests with retry/backoff for throttling and transient failures.

	.DESCRIPTION
		Wraps Invoke-MgGraphRequest and retries on 429 and common transient 5xx/408 errors.
		Honors Retry-After when available.
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][ValidateSet('GET','POST','PUT','PATCH','DELETE')][string]$Method,
		[Parameter(Mandatory)][string]$Uri,
		[object]$Body,
		[int]$MaxRetries = 6,
		[switch]$QuietMode
	)

	$attempt = 0
	while ($true) {
		try {
			if ($PSBoundParameters.ContainsKey('Body')) {
				return Invoke-MgGraphRequest -Method $Method -Uri $Uri -Body $Body -ErrorAction Stop
			}
			return Invoke-MgGraphRequest -Method $Method -Uri $Uri -ErrorAction Stop
		}
		catch {
			$attempt++

			$status = $null
			try { if ($_.Exception.Response) { $status = $_.Exception.Response.StatusCode.value__ } } catch { Write-Verbose "Failed to read status code from Graph exception: $_" }

			$transient = @($status) -contains 429 -or @($status) -contains 408 -or @($status) -contains 500 -or @($status) -contains 502 -or @($status) -contains 503 -or @($status) -contains 504
			if (-not $transient -or $attempt -gt $MaxRetries) {
				throw
			}

			$retryAfterSeconds = Get-GraphRetryAfterSeconds -ErrorRecord $_
			$delaySeconds = if ($retryAfterSeconds) {
				$retryAfterSeconds
			}
			else {
				# exponential backoff with a small cap
				[int]([Math]::Min(60, [Math]::Pow(2, $attempt)))
			}

			if (-not $QuietMode) {
				Write-ModuleLog -Message "Graph request throttled/transient (HTTP $status). Retrying in $delaySeconds s (attempt $attempt/$MaxRetries)." -Level Warning
			}
			Start-Sleep -Seconds $delaySeconds
		}
	}
}
