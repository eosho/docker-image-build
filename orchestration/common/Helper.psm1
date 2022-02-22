function Test-IsLoggedIn() {
  [CmdletBinding()]

  $context = Get-AzContext
  return ($null -ne $context)
}

function ConvertTo-HashTable() {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $false)]
    $InputObject
  )

  if ($InputObject) {
    # Convert to string prior to converting to hashtable
    $objectString = ConvertTo-Json -InputObject $InputObject `
      -Depth 100

    # Convert string to hashtable and return it
    return ConvertFrom-Json -InputObject $objectString -AsHashtable
  } else {
    return $null
  }
}

Function Get-AzureApiUrl() {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string] $AzureEnvironment = "AzureCloud",

    [Parameter(Mandatory = $true)]
    [string] $AzureDiscoveryUrl
  )

  return ( Invoke-RestMethod -Uri $AzureDiscoveryUrl -Method Get -ContentType "application/json" ) | Where-Object { $_.name -eq $AzureEnvironment }
}

<#
.SYNOPSIS
  Example deployment script to deploy policies to a preferred subscription or management group started with name or filter.

.DESCRIPTION
  Example deployment script to deploy policies to a preferred subscription or management group started with name or filter.

.PARAMETER ModuleName
  Name of the module to install

.EXAMPLE
  Invoke-ModuleInstall -ModuleName "Az"

.INPUTS
  <none>

.OUTPUTS
  <none>

.NOTES
#>
function Invoke-ModuleInstall {
  [CmdletBinding()]
  param (
    [Parameter()]
    [string] $ModuleName
  )

  # If module is imported say that and do nothing
  if (Get-Module | Where-Object { $_.Name -eq $ModuleName }) {
    Write-Output "Module: [$($ModuleName)] is already imported."
  } else {

    # If module is not imported, but available on disk then import
    if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $ModuleName }) {
      Write-Output "Importing module: [$($ModuleName)]..."
      Import-Module $ModuleName
    } else {

      # If module is not imported, not available on disk, but is in online gallery then install and import
      if (Find-Module -Name $ModuleName | Where-Object { $_.Name -eq $ModuleName }) {
        Write-Output "Installing module: [$($ModuleName)]..."
        Install-Module -Name $ModuleName -Force -Scope CurrentUser
        Import-Module $ModuleName
      } else {

        # If module is not imported, not available and not in online gallery then abort
        Write-Output "Module: [$($ModuleName)] not imported, not available and not in online gallery, exiting."
      }
    }
  }
}
