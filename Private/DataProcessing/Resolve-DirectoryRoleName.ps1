function Resolve-DirectoryRoleName {
	<#
	.SYNOPSIS
		Resolves a directory role template/definition GUID to a human-readable display name.

	.DESCRIPTION
		Attempts multiple Graph lookups in order: unified role definitions by templateId, roleDefinitions by id,
		directoryRoleTemplates by id, then active directoryRoles filtered by roleTemplateId. Returns the first
		displayName found or $null if all attempts fail.

	.PARAMETER RoleId
		GUID (templateId or definition Id) representing the directory role to resolve.

	.OUTPUTS
		String (role display name) or $null.

	.NOTES
		Uses v1.0 endpoints; silent failures yield $null to keep calling paths resilient.

	.EXAMPLE
		Resolve-DirectoryRoleName -RoleId '62e90394-69f5-4237-9190-012177145e10'
	#>
	[CmdletBinding()] 
	param([Parameter(Mandatory)][string]$RoleId)
	
	# Try unified role definitions by templateId first
	try {
		$templateIdFilter = [uri]::EscapeDataString("templateId eq '$RoleId'")
		$roleDefinitionResponse = Invoke-MgGraphRequest -Method GET -Uri ("https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?`$filter=$templateIdFilter&`$select=id,displayName,templateId") -ErrorAction Stop
		
		if ($roleDefinitionResponse.value -and $roleDefinitionResponse.value.Count -gt 0 -and $roleDefinitionResponse.value[0].displayName) { 
			return $roleDefinitionResponse.value[0].displayName 
		}
	}
	catch { 
		# Silent failure - continue to next method
	}
	
	# Fallback: roleDefinitions by id (some tenants surface guid as definition id)
	try {
		$roleDefinitionById = Invoke-MgGraphRequest -Method GET -Uri ("https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions/$RoleId?`$select=id,displayName") -ErrorAction Stop
		
		if ($roleDefinitionById.id -and $roleDefinitionById.displayName) { 
			return $roleDefinitionById.displayName 
		}
	}
	catch { 
		# Silent failure - continue to next method
	}
	
	# Fallback: directory role templates by id
	try {
		$roleTemplate = Invoke-MgGraphRequest -Method GET -Uri ("https://graph.microsoft.com/v1.0/directoryRoleTemplates/$RoleId?`$select=id,displayName") -ErrorAction Stop
		
		if ($roleTemplate.id -and $roleTemplate.displayName) { 
			return $roleTemplate.displayName 
		}
	}
	catch { 
		# Silent failure - continue to next method
	}
	
	# Fallback: active directoryRoles by roleTemplateId
	try {
		$roleTemplateIdFilter = [uri]::EscapeDataString("roleTemplateId eq '$RoleId'")
		$directoryRoleResponse = Invoke-MgGraphRequest -Method GET -Uri ("https://graph.microsoft.com/v1.0/directoryRoles?`$filter=$roleTemplateIdFilter&`$select=id,displayName") -ErrorAction Stop
		
		if ($directoryRoleResponse.value -and $directoryRoleResponse.value.Count -gt 0 -and $directoryRoleResponse.value[0].displayName) { 
			return $directoryRoleResponse.value[0].displayName 
		}
	}
	catch { 
		# Silent failure - return null
	}
	
	return $null
}
