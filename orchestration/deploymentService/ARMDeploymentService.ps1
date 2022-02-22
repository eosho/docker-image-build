Import-Module ".\orchestration\common\Helper.psm1" -Force

# Interface
Class IDeploymentService {
  [hashtable] ExecuteDeployment(
    [string] $SubscriptionId,
    [string] $ResourceGroupName,
    [string] $DeploymentTemplate,
    [string] $DeploymentParameters,
    [hashtable] $DeploymentParamObject,
    [string] $Location
  ) {
    Throw "Method Not Implemented"
  }

  [void] CreateResourceGroup([string] $ResourceGroupName, [string] $Location) {
    Throw "Method Not Implemented"
  }

  [void] SetSubscriptionContext([string] $SubscriptionId) {
    Throw "Method Not Implemented"
  }

  [void] RemoveResourceGroupLock([string] $SubscriptionId, [string] $ResourceGroupName) {
    Throw "Method Not Implemented"
  }

  [void] RemoveResourceGroup([string] $SubscriptionId, [string] $ResourceGroupName) {
    Throw "Method Not Implemented"
  }

  [object] GetResourceGroup([string] $SubscriptionId, [string] $ResourceGroupName) {
    Throw "Method Not Implemented"
  }
}

# A class that extends an interface
Class ARMDeploymentService: IDeploymentService {
  # Performs the deployment execution against the custom ARM deployment
  [hashtable] ExecuteDeployment(
    [string] $SubscriptionId,
    [string] $ResourceGroupName,
    [string] $DeploymentTemplate,
    [string] $DeploymentParameters,
    [hashtable] $DeploymentParamObject,
    [string] $Location
  ) {

    try {

      # call custom arm deployment
      $deployment = $this.InvokeARMOperation(
        $SubscriptionId,
        $ResourceGroupName,
        $DeploymentTemplate,
        $DeploymentParameters,
        $DeploymentParamObject,
        $Location,
        "deploy"
      )

      return $deployment

    } catch {
      throw "$($_.Exception.Message)"
    }
  }

  # Performs a validation against the ARM API, returns template validation output
  [void] ExecuteValidation(
    [string] $SubscriptionId,
    [string] $ValidationResourceGroupName,
    [string] $DeploymentTemplate,
    [string] $DeploymentParameters,
    [hashtable] $DeploymentParamObject,
    [string] $Location
  ) {

    try {

      # call arm validation
      $validation = $this.InvokeARMOperation(
        $SubscriptionId,
        $ValidationResourceGroupName,
        $DeploymentTemplate,
        $DeploymentParameters,
        $DeploymentParamObject,
        $Location,
        "validate"
      )

      # Did the validation succeed?
      if ($validation.error.code -eq "InvalidTemplateDeployment") {
        # Throw an exception and pass the exception message from the
        # ARM validation
        Throw ("Validation failed with the error below: {0}" -f (ConvertTo-Json $validation -Depth 50))
      } else {
        Write-Output "Validation Passed"
      }
    } catch {
      throw "$($_.Exception.Message)"
    }
  }

  # Generate a unique deployment name every time a deployment is triggered
  hidden [string] GenerateUniqueDeploymentName() {
    # generate a new guid
    return [Guid]::NewGuid()
  }

  # Invoke the custom ARM resource deployment
  hidden [object] InvokeARMOperation(
    [string] $SubscriptionId,
    [string] $ResourceGroupName,
    [string] $DeploymentTemplate,
    [string] $DeploymentParameters,
    [hashtable] $DeploymentParamObject,
    [string] $Location,
    [string] $Operation
  ) {

    $deployment = $null

    # Generate the deployment name
    $uniqueDeploymentName = $this.GenerateUniqueDeploymentName()

    # Check for invariant
    if ([string]::IsNullOrEmpty($DeploymentTemplate)) {
      throw "Deployment template contents cannot be empty"
    } else {
      $deploymentInputs = @{}
      $scope = $null
      $ErrorMessages = $null

      # If deployment parameter file exists, then let us know
      if ($DeploymentParameters) {
        $DeploymentParamObject = $null
        Write-Verbose "Detected a parameter file as part of your deployment." -Verbose
        # Test template parameter file path
        if (Test-Path -Path $DeploymentParameters) {
          Write-Output "$DeploymentParameters"
          $DeploymentInputs += @{
            TemplateParameterFile = $DeploymentParameters
          }
        }
      }
      else {
        $DeploymentParameters = $null
        Write-Verbose "Analyzing template parameter object for deployment" -Verbose
        foreach ($key in $DeploymentParamObject.Keys) {
          $deploymentInputs += @{
            $key = $DeploymentParamObject.Item($key)
          }
        }
      }

      # Deployment argument to be passed to Cmdlets
      $deploymentInputs += @{
        TemplateFile = $DeploymentTemplate
        Name         = $uniqueDeploymentName
        Verbose      = $true
        ErrorAction  = 'Stop'
      }

      # Let's check if we are in a subscription or resource group level deployment by inspecting the schema
      $deploymentSchema = (ConvertFrom-Json (Get-Content -Raw -Path $DeploymentTemplate)).'$schema'
      switch -regex ($deploymentSchema) {
        '\/DeploymentTemplate.json#$' {
          $scope = "resourceGroup"
        }
        '\/subscriptionDeploymentTemplate.json#$' {
          $scope = "subscription"
        }
        default {
          throw "[$deploymentSchema] is a non-supported schema"
        }
      }

      # Run validation only if needed, else perform the actual deployment process
      if ($Operation -eq "validate") {
        switch ($scope) {
          resourceGroup {
            Test-AzResourceGroupDeployment @deploymentInputs -ResourceGroupName $ResourceGroupName
          }
          subscription {
            Test-AzDeployment @deploymentInputs -Location $Location
          }
          Default {
            throw "Unsupported validation scope"
          }
        }
      } else {
        switch ($scope) {
          resourceGroup {
            $deployment = New-AzResourceGroupDeployment @deploymentInputs -ResourceGroupName $ResourceGroupName -ErrorVariable ErrorMessages
          }
          subscription {
            $deployment = New-AzSubscriptionDeployment @deploymentInputs -Location $Location -ErrorVariable ErrorMessages
          }
          Default {
            throw "Unsupported deployment scope"
          }
        }

        $ErrorActionPreference = 'Stop'
        if ($ErrorMessages) {
          Write-Output '', 'Template deployment returned the following errors:', '', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message })
          Write-Error "Deployment failed."
        }
      }

      $deploymentOutput = (ConvertTo-Hashtable $deployment)

      return $deploymentOutput
    }
  }

  # Create the actual resource group
  [void] CreateResourceGroup(
    [string] $ResourceGroupName,
    [string] $Location,
    [object] $Tags
  ) {

    try {
      $resourceGroupFound = Get-AzResourceGroup $ResourceGroupName -ErrorAction SilentlyContinue

      # Convert the object to hashtable
      $tags = ConvertTo-HashTable -InputObject $Tags

      if ($null -eq $resourceGroupFound) {
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag $Tags -Force
      }
    } catch {
      Write-Output "An error ocurred while running CreateResourceGroup"
      Write-Output $_
      throw $_
    }
  }

  # Set the current subscription context
  [void] SetSubscriptionContext([string] $SubscriptionId) {

    try {
      Get-AzSubscription -SubscriptionId $SubscriptionId | Set-AzContext
    } catch {
      Write-Output "An error ocurred while running SetSubscriptionContext"
      Write-Output $_
      throw $_
    }
  }

  # If there is any resource lock on the existing resource group, we need it cleaned up
  # Resource lock will be applied during redeployment of rg
  [void] RemoveResourceGroupLock([string] $SubscriptionId, [string] $ResourceGroupName) {

    try {
      $scope = "/subscriptions/{0}/resourceGroups/{1}" -f @($SubscriptionId, $ResourceGroupName)
      $allLocks = Get-AzResourceLock -Scope $scope -ErrorAction SilentlyContinue | Where-Object "ProvisioningState" -ne "Deleting"

      if ($null -ne $allLocks) {
        $allLocks | ForEach-Object {
          Remove-AzResourceLock -LockId $_.ResourceId -Force -ErrorAction SilentlyContinue
        }
      }
    } catch {
      Write-Output "An error ocurred while running RemoveResourceGroupLock"
      Write-Output $_
      throw $_
    }
  }

  # Remove an existing resource group - used for clean up purposes
  [void] RemoveResourceGroup([string] $SubscriptionId, [string] $ResourceGroupName) {

    try {
      $id = "/subscriptions/{0}/resourceGroups/{1}" -f @($SubscriptionId, $ResourceGroupName)
      $resourceGroup = $this.GetResourceGroup($SubscriptionId, $ResourceGroupName)
      if ($null -ne $resourceGroup) {
        Remove-AzResourceGroup -Id $id -Force -ErrorAction SilentlyContinue -AsJob
      }
    } catch {
      Write-Output "An error ocurred while running RemoveResourceGroup"
      Write-Output $_
      throw $_
    }
  }

  # Validate existence of a resource group, returns resource group properties
  [object] GetResourceGroup([string] $SubscriptionId, [string] $ResourceGroupName) {

    try {
      $resourceId = "/subscriptions/{0}/resourceGroups/{1}" -f ($SubscriptionId, $ResourceGroupName)
      return Get-AzResourceGroup -Id $resourceId -ErrorAction SilentlyContinue
    } catch {
      Write-Output "An error ocurred while running GetResourceGroup"
      Write-Output $_
      throw $_
    }
  }
}
