function Get-AccessPackageResourceTypeLabel {
    <#!
    .SYNOPSIS
        Returns a user-friendly resource type label for an access package resource.

    .DESCRIPTION
        Maps Graph entitlementManagement resource metadata (originSystem/resourceType)
        to a small set of labels used in the Access Package Documentor report.

    .PARAMETER Resource
        A resource object (typically accessPackageResource) from entitlementManagement.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][ValidateNotNull()]$Resource
    )

    $origin = if ($Resource.originSystem) { $Resource.originSystem.ToString().ToLower() } else { '' }
    $type = if ($Resource.resourceType) { $Resource.resourceType.ToString().ToLower() } else { '' }

    if ($origin -like '*group*') { return 'Group' }
    if ($origin -like '*oauth*') { return 'API Permission' }
    if ($origin -like '*aadapplication*' -or $origin -like '*serviceprincipal*') { return 'App' }
    if ($origin -like '*aadrole*' -or $origin -like '*directoryrole*' -or $type -like '*role*') { return 'Entra role' }
    if ($origin -like '*sharepoint*' -or $origin -like '*spo*' -or $type -like '*sharepoint*') { return 'SharePoint Site' }

    return 'Custom Data'
}