<#
  .SYNOPSIS
  Run a template deployment using a given parameter file, cleans up rgs, resource locks.

  .DESCRIPTION
  Run a template deployment using a given parameter file. Works on a resource group, subscription level

  .PARAMETER SubscriptionId
  Optional. Id of the subscription to deploy into. Mandatory if deploying into a subscription (subscription level) using a Management groups service connection

  .PARAMETER ResourceGroupName
  Optional. Name of the resource group to deploy into. Mandatory if deploying into a resource group (resource group level)

  .PARAMETER DeploymentTemplate
  Mandatory. The path to the ARM template json file for deployment

  .PARAMETER DeploymentParameters
  Optional. Path to the ARM template json parameters file.

  .PARAMETER DeploymentParamObject
  Optional. Object of parameters to be used in deployment.

  .PARAMETER Location
  Mandatory. Location to test in. E.g. EastUS

  .PARAMETER Validate
  Optional. Set to 'true' validate deployment against the ARM engine.

  .PARAMETER TearDownEnvironment
  Optional. Set to 'true' to Delete the deployment RG for clean up purposes.

  .EXAMPLE
  $paramArgs = @{
    SubscriptionId        = $(Get-AzContext).Subscription.Id
    DeploymentTemplate    = '.\aks\bicep\main.json'
    DeploymentParameter   = '.\aks\bicep\main.parameters.json'
    Location              = "eastus2"
  }
  New-ARMDeployment @paramArgs

  Deploy the ARM template with the parameter file 'parameters.json'

  .EXAMPLE
  $paramArgs = @{
    SubscriptionId        = $(Get-AzContext).Subscription.Id
    DeploymentTemplate    = '.\aks\bicep\main.json'
    DeploymentParamObject = @{
      prefix          = 'demo'
      environmentName = 'dev'
    }
    Location              = "eastus2"
  }
  New-ARMDeployment @paramArgs

  Deploy the ARM template with the deployment parameter object (hashtable)

  .EXAMPLE
  $paramArgs = @{
    SubscriptionId        = $(Get-AzContext).Subscription.Id
    DeploymentTemplate    = '.\aks\bicep\main.json'
    DeploymentParamObject = @{
      prefix          = 'demo'
      environmentName = 'dev'
    }
    Location              = "eastus2"
  }
  New-ARMDeployment -Validate

  Runs the ARM template validation

  .EXAMPLE
  New-ARMDeployment -SubscriptionId 'xxxx' -ResourceGroupName 'some-rg' -TearDownEnvironment

  Cleans up the resources by cleaning the RG
#>
function New-ARMDeployment {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string] $SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string] $DeploymentTemplate,

    [Parameter(Mandatory = $false)]
    [string] $DeploymentParameters,

    [Parameter(Mandatory = $false)]
    [hashtable] $DeploymentParamObject,

    [Parameter(Mandatory = $false)]
    [string] $Location,

    [Parameter(Mandatory = $false)]
    [switch] $Validate,

    [Parameter(Mandatory = $false)]
    [switch] $TearDownEnvironment
  )

  begin {
    Write-Debug ("{0} entered" -f $MyInvocation.MyCommand)
  }

  process {

    try {

      $deploymentService = [ARMDeploymentService]::new()

      if (-not($TearDownEnvironment.IsPresent)) {
        if ($Validate.IsPresent) {
          Write-Verbose "Validating the template" -Verbose
          return $deploymentService.ExecuteValidation(
            $SubscriptionId,
            $ResourceGroupName,
            $DeploymentTemplate,
            $DeploymentParameters,
            $DeploymentParamObject,
            $Location
          )
        } else {
          Write-Verbose "Deploying the template" -Verbose
          return $deploymentService.ExecuteDeployment(
            $SubscriptionId,
            $ResourceGroupName,
            $DeploymentTemplate,
            $DeploymentParameters,
            $DeploymentParamObject,
            $Location
          )
        }
      }
      # Lets tear down the RG if needed
      elseif ($TearDownEnvironment.IsPresent) {
        Write-Verbose "Deleting the resource group" -Verbose
        $resourceGroupFound = $deploymentService.GetResourceGroup(
          $SubscriptionId,
          $ResourceGroupName
        )

        # Let's check if the resource group exists and the resource group name & its not in a deleting state
        if ($null -ne $resourceGroupFound -and ($resourceGroupFound.ProvisioningState -ne "Deleting")) {
          # Start deleting the resource group locks (if any) and resource group
          Write-Verbose "Deleting all resource locks" -Verbose
          $deploymentService.RemoveResourceGroupLock(
            $SubscriptionId,
            $ResourceGroupName
          )

          Write-Verbose "Deleting resource group: $ResourceGroupName" -Verbose
          $deploymentService.RemoveResourceGroup(
            $SubscriptionId,
            $ResourceGroupName
          )
        } else {
          # Continue
          # Find a way to monitor existing deletion status maybe
        }
      } else {
        # Doing nothing
      }
    } catch {
      Write-Error "An error ocurred while running New-ARMDeployment. Details: $($_.Exception.Message)" -ErrorAction Stop
    }
  }

  end {
    Write-Debug ("{0} exited" -f $MyInvocation.MyCommand)
  }
}
