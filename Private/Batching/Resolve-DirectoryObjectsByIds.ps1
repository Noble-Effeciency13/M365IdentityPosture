function Resolve-DirectoryObjectsByIds {
	<#!
	.SYNOPSIS
		Bulk-resolves Azure AD directory object IDs to basic properties.

	.DESCRIPTION
		Uses POST /directoryObjects/getByIds to resolve users/groups/etc in fewer round-trips.
		Returns a hashtable keyed by id.
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][string[]]$Ids,
		[string[]]$Types = @('user','group'),
		[int]$ChunkSize = 1000,
		[int]$MaxRetries = 6,
		[switch]$QuietMode
	)

	$map = @{}
	$idsClean = @($Ids | Where-Object { $_ } | Select-Object -Unique)
	if ($idsClean.Count -eq 0) { return $map }

	for ($i = 0; $i -lt $idsClean.Count; $i += $ChunkSize) {
		$end = [Math]::Min($i + $ChunkSize - 1, $idsClean.Count - 1)
		$chunk = $idsClean[$i..$end]

		$body = @{ ids = $chunk; types = $Types } | ConvertTo-Json -Depth 6
		$uri = 'https://graph.microsoft.com/v1.0/directoryObjects/getByIds'
		try {
			$res = Invoke-GraphRequestSafe -Method POST -Uri $uri -Body $body -MaxRetries $MaxRetries -QuietMode:$QuietMode
			$converted = ConvertTo-PSCustomObjectRecursive $res
			foreach ($obj in @($converted.value)) {
				if ($obj.id) { $map[$obj.id] = $obj }
			}
		}
		catch {
			Write-ModuleLog -Message "Failed bulk directoryObjects/getByIds: $($_.Exception.Message)" -Level Warning
		}
	}

	return $map
}
