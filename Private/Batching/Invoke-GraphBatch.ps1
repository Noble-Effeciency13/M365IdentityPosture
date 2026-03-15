function Invoke-GraphBatch {
	<#!
	.SYNOPSIS
		Invokes Microsoft Graph $batch with chunking and retry.

	.DESCRIPTION
		Splits requests into batches of up to 20 and returns the combined responses.
		Request urls MUST be relative (e.g. /v1.0/users/{id}?$select=...).
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][hashtable[]]$Requests,
		[int]$BatchSize = 20,
		[int]$MaxRetries = 6,
		[ValidateSet('v1.0','beta')][string]$BatchEndpointVersion = 'v1.0',
		[switch]$QuietMode
	)

	if ($BatchSize -gt 20) { $BatchSize = 20 }
	if ($BatchSize -lt 1) { $BatchSize = 1 }

	$allResponses = @()
	for ($i = 0; $i -lt $Requests.Count; $i += $BatchSize) {
		$end = [Math]::Min($i + $BatchSize - 1, $Requests.Count - 1)
		$chunk = $Requests[$i..$end]

		$body = @{ requests = @() }
		foreach ($r in $chunk) {
			$id = if ($r.ContainsKey('id') -and $r.id) { [string]$r.id } else { [string]([guid]::NewGuid()) }
			$reqUrl = ConvertTo-GraphBatchUrl -Url ([string]$r.url)
			$req = @{ id = $id; method = $r.method; url = $reqUrl }
			if ($r.ContainsKey('headers') -and $r.headers) { $req.headers = $r.headers }
			if ($r.ContainsKey('body')) { $req.body = $r.body }
			$body.requests += $req
		}

		$batchUri = "https://graph.microsoft.com/$BatchEndpointVersion/`$batch"
		$json = $body | ConvertTo-Json -Depth 30
		$res = Invoke-GraphRequestSafe -Method POST -Uri $batchUri -Body $json -MaxRetries $MaxRetries -QuietMode:$QuietMode
		$converted = ConvertTo-PSCustomObjectRecursive $res
		if ($converted.responses) { $allResponses += @($converted.responses) }
	}

	return $allResponses
}
