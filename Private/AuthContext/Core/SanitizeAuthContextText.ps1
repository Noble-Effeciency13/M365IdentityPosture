function SanitizeAuthContextText {
	<#
	.SYNOPSIS
		Cleans up authentication context text formatting in data objects.
		
	.DESCRIPTION
		Removes unwanted quote characters from authentication context ID fields to ensure
		consistent formatting across the data. Processes properties that match authentication
		context naming patterns.

	.PARAMETER Data
		The data object or collection to process for text sanitization.

	.OUTPUTS
		The sanitized data object with cleaned authentication context text.

	.EXAMPLE
		$cleanData = SanitizeAuthContextText -Data $authContextData
	#>
	param([object]$Data)
	if (-not $Data) { return $Data }
	foreach ($row in $Data) {
		foreach ($propertyName in $row.PSObject.Properties.Name) {
			if ($propertyName -match 'Auth.*Context.*(Id|Ids|ClassRef)') {
				$val = [string]$row.$propertyName
				if ($val) {
					$row.$propertyName = ($val -replace "(^|[,; ]+)'(?=(c\d+\b|[0-9a-fA-F-]{32,36}\b))", '$1')
				}
			}
		}
	}
	return $Data
}
