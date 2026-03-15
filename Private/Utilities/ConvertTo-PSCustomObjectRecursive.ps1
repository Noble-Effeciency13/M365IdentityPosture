function ConvertTo-PSCustomObjectRecursive {
	<#!
	.SYNOPSIS
		Recursively converts Graph hashtable responses into PSCustomObjects.

	.DESCRIPTION
		Invoke-MgGraphRequest returns nested hashtables/arrays. This helper converts them to
		PSCustomObject structures so downstream code can use dot notation consistently.
	#>
	[CmdletBinding()] param(
		[Parameter(ValueFromPipeline)]$InputObject
	)
	process {
		if ($null -eq $InputObject) { return $null }
		if ($InputObject -is [System.Collections.Hashtable]) {
			$obj = [PSCustomObject]@{}
			foreach ($key in $InputObject.Keys) {
				$obj | Add-Member -MemberType NoteProperty -Name $key -Value (ConvertTo-PSCustomObjectRecursive $InputObject[$key])
			}
			return $obj
		}
		elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
			return @($InputObject | ForEach-Object { ConvertTo-PSCustomObjectRecursive $_ })
		}
		else {
			return $InputObject
		}
	}
}
