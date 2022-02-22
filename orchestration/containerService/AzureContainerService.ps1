# Interface
Class IContainerService {
  [hashtable] CreateContainerInstance(
    [string] $ResourceGroupName,
    [string] $ContainerRegistryName,
    [string] $ImageName,
    [string] $ImageVersion,
    [string] $RegistryUserName,
    [string] $RegistryPassword
  ) {
    Throw "Method Not Implemented"
  }

  [void] GetContainerRegistry([string] $ResourceGroupName) {
    Throw "Method Not Implemented"
  }

  [void] BuildRegistry(
    [string] $ContainerRegistryName,
    [string] $ImageName,
    [string] $ImageVersion
  ) {
    Throw "Method Not Implemented"
  }

  [void] DeleteContainerRegistry(
    [string] $ContainerRegistryName,
    [string] $ResourceGroupName
  ) {
    Throw "Method Not Implemented"
  }
}

# A class that extends an interface
Class AzureContainerService: IContainerService {

  # Build, test and push a new container image
  [void] CreateContainerImage(
    [string] $ContainerRegistryName,
    [string] $ImageName,
    [string] $ImageVersion,
    [string] $YamlFilePath
  ) {

    # If no image version is provided, it would default to the version latest.
    # Its recommended to only use version 'latest' for production ready images,
    # Test images can use version '{{.Run.ID}}' or any preferred versioning format.
    if ([string]::IsNullOrEmpty($ImageVersion)) {
      $ImageVersion = "latest"
    }

    if ([string]::IsNullOrEmpty($ImageName)) {
      $ImageName = $null
    }

    try {
      if ($YamlFilePath) {
        az acr run --registry $ContainerRegistryName -f $YamlFilePath .
      } else {
        throw "Unsupported scenario. Use YAML to orchestrate your image creation"
        #az acr build --registry $ContainerRegistryName --image "baseimage/$($ImageName):$($ImageVersion)" .
      }
    } catch {
      Write-Host "An error ocurred while running CreateContainerImage"
      Write-Host $_
      throw $_
    }
  }

  # Create a new container
  [void] CreateContainerInstance(
    [string] $ResourceGroupName,
    [string] $ContainerRegistryName,
    [string] $ImageName,
    [string] $ImageVersion,
    [string] $RegistryUserName,
    [string] $RegistryPassword
  ) {
    try {
      az container create --resource-group $ResourceGroupName --name acr-tasks --image "$ContainerRegistryName.azurecr.io/baseimage/alpine/$($ImageName):$($ImageVersion)" `
        --registry-login-server "$ContainerRegistryName.azurecr.io" --registry-username $RegistryUserName --registry-password $RegistryPassword `
        --dns-name-label "acr-tasks-$ContainerRegistryName" --query "{FQDN:ipAddress.fqdn}" --output table
    } catch {

    }
  }

  # Generate a new image version #not used right now
  hidden [string] GenerateImageVersion() {
    # generate a version Id
    return [Guid]::NewGuid()
  }

  [void] ValidateRegistryContainer([string] $ContainerRegistryName) {
    try {
      az acr task run --registry $ContainerRegistryName --name taskBaseImage --debug --verbose
    } catch {

    }
  }

  # Create registry task to automate build, push and update process
  [void] CreateRegistryTask(
    [string] $AzureDevOpsGitUrl,
    [string] $AzureDevOpsToken,
    [string] $ContainerRegistryName,
    [string] $ImageName,
    [string] $YamlFilePath
  ) {
    try {
      az acr task create --registry $ContainerRegistryName --name "taskBaseImage" --image "baseimage/alpine/$($ImageName):{{.Run.ID}}" `
        --context $AzureDevOpsGitUrl --file $YamlFilePath --git-access-token $AzureDevOpsToken --debug
    } catch {

    }
  }

  # Delete a task before creating a new one
  [void] DeleteRegistryTask(
    [string] $ContainerRegistryName,
    [string] $ResourceGroupName
  ) {
    try {
      az acr task delete --registry $ContainerRegistryName --name "taskBaseImage" --resource-group $ResourceGroupName --yes
    } catch {

    }
  }

  # Get the properties of an existing container registry
  [object] GetContainerRegistry([string] $ResourceGroupName) {

    try {
      return az acr list --resource-group $ResourceGroupName
    } catch {
      Write-Host "An error ocurred while running GetContainerRegistry"
      Write-Host $_
      throw $_
    }
  }

  # Delete a container registry from its rg
  [void] DeleteContainerRegistry(
    [string] $ContainerRegistryName,
    [string] $ResourceGroupName
  ) {

    try {
      az acr delete --name $ContainerRegistryName --resource-group $ResourceGroupName --yes
    } catch {
      Write-Output "An error ocurred while running DeleteContainerRegistry"
      Write-Output $_
      throw $_
    }
  }
}
