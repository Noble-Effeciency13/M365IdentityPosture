function ConvertTo-PolicyCustomExtensions {
	<#!
	.SYNOPSIS
		Converts access package policy custom extension stage settings into a normalized collection.

	.DESCRIPTION
		The Access Package Documentor converter expects custom extensions to be provided per-policy as an array
		of objects with:
		- id
		- stage
		- customExtension (expanded)

		This helper converts Graph's customExtensionStageSettings array into that shape.

	.PARAMETER PolicyId
		The assignment policy id.

	.PARAMETER StageSettings
		The customExtensionStageSettings array from Microsoft Graph.

	.OUTPUTS
		System.Object[]
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PolicyId,
		[Parameter(Mandatory)][ValidateNotNull()][object[]]$StageSettings
	)

	$converted = @()
	$stageIdx = 0
	foreach ($s in @($StageSettings)) {
		$stageIdx++
		$ss = if ($s -is [psobject]) { $s } else { ConvertTo-PSCustomObjectRecursive $s }
		$converted += [pscustomobject]@{
			id              = if ($ss.id) { $ss.id } else { ("{0}-stage-{1}" -f $PolicyId, $stageIdx) }
			stage           = $ss.stage
			customExtension = $ss.customExtension
		}
	}

	return ,$converted
}
