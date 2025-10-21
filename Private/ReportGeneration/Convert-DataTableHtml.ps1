function Convert-DataTableHtml {
	<#
	.SYNOPSIS
		Converts PowerShell data objects to HTML table format.

	.DESCRIPTION
		Transforms an array of PowerShell objects into a formatted HTML table with proper
		encoding and structure. Returns a message if no data is provided.

	.PARAMETER Data
		The data objects to convert to HTML table format.

	.PARAMETER Title
		Optional title for the table (currently not used in output).

	.OUTPUTS
		String containing the HTML table representation of the data.

	.EXAMPLE
		$htmlTable = Convert-DataTableHtml -Data $users -Title "User List"
	#>
	param($Data, $Title)
    
	if (-not $Data) { 
		return '<p>No data</p>' 
	}
    
	$rows = @($Data)
	$props = ($rows[0].PSObject.Properties.Name)
	$thead = ($props | ForEach-Object { "<th>$_</th>" }) -join ''
	$tbody = foreach ($r in $rows) { 
		'<tr>' + (($props | ForEach-Object { 
			'<td>' + [System.Web.HttpUtility]::HtmlEncode([string]$r.$_) + '</td>' 
		}) -join '') + '</tr>' 
	}
    
	return "<table><thead><tr>$thead</tr></thead><tbody>$($tbody -join '')</tbody></table>"
}
