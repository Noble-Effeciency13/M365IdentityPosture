function Invoke-GraphPagedRequest {
	<#!
	.SYNOPSIS
		Retrieves all pages from a Microsoft Graph collection endpoint.

	.DESCRIPTION
		Follows @odata.nextLink until exhausted and converts returned items into PSCustomObjects.
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][string]$StartUri,
		[int]$MaxRetries = 6,
		[switch]$QuietMode
	)

	$results = @()
	$next = $StartUri
	while ($next) {
		$response = Invoke-GraphRequestSafe -Method GET -Uri $next -MaxRetries $MaxRetries -QuietMode:$QuietMode
		if ($response.value) {
			$items = $response.value | ForEach-Object { ConvertTo-PSCustomObjectRecursive $_ }
			$results += $items
		}
		$next = $response.'@odata.nextLink'
	}
	return $results
}
