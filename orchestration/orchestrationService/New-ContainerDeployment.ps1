<#
  .SYNOPSIS
  Runs the orchestration of your docker base images.

  .DESCRIPTION
  Runs the orchestration of your docker base images from build, test and deployment.

  .PARAMETER ResourceGroupName
  Optional. Name of the resource group to deploy container image

  .PARAMETER AzureDevOpsGitUrl
  Optional. The url of your Azure DevOps repository

  .PARAMETER AzureDevOpsToken
  Optional. The personal access token for your repository. You need to generate one - https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page

  .PARAMETER RegistryUserName
  Optional. Username of the Container registry - use your SPN Client ID.

  .PARAMETER RegistryPassword
  Mandatory. Password for your container registry - use your SPN Client Secret.

  .PARAMETER AutomateImageBuild
  Optional. Set to 'true' if you want to build your images when code is pushed to your repo (automated).

  .PARAMETER BuildContainerImage
  Optional. Set to 'true' to build and deploy your container image.

  .PARAMETER Validate
  Optional. Set to 'true' to validate the existence of your container registry.

  .PARAMETER ContainerRegistryName
  Optional. Name of your container registry.

  .PARAMETER ImageName
  Optional. Name of your docker image.

  .PARAMETER ImageVersion
  Optional. Version of your docker image.

  .PARAMETER YamlFilePath
  Optional. Run the ACR build task using a yaml definition to build, test and push images to the registry.
#>
function New-ContainerDeployment {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string] $AzureDevOpsGitUrl,

    [Parameter(Mandatory = $false)]
    [string] $AzureDevOpsToken,

    [Parameter(Mandatory = $false)]
    [string] $RegistryUserName,

    [Parameter(Mandatory = $false)]
    [string] $RegistryPassword,

    [Parameter(Mandatory = $false)]
    [switch] $AutomateImageBuild,

    [Parameter(Mandatory = $false)]
    [switch] $BuildContainerImage,

    [Parameter(Mandatory = $false)]
    [switch] $Validate,

    [Parameter(Mandatory = $false)]
    [string] $ContainerRegistryName,

    [Parameter(Mandatory = $false)]
    [string] $ImageName,

    [Parameter(Mandatory = $false)]
    [string] $ImageVersion,

    [Parameter(Mandatory = $false)]
    [string] $YamlFilePath
  )

  begin {
    Write-Debug ("{0} entered" -f $MyInvocation.MyCommand)
  }

  process {

    # Replace token value
    $AzureDevOpsGitUrl = $AzureDevOpsGitUrl -Replace "://", ("://{0}@" -f $AzureDevOpsToken)

    try {

      # Initialization
      $containerService = [AzureContainerService]::new()

      if ($Validate.IsPresent) {
        Write-Verbose "Validating the existence of the container registry" -Verbose

        return $containerService.GetContainerRegistry(
          $ResourceGroupName
        )
      }

      if ($BuildContainerImage.IsPresent) {

        Write-Verbose "Building container image" -Verbose

        if ($YamlFilePath) {
          Write-Output "Running image build via Yaml file definition"
        }
        else {
          Write-Output "Running image build via Dockerfile definition"
        }
        return $containerService.CreateContainerImage(
          $ContainerRegistryName,
          $ImageName,
          $ImageVersion,
          $YamlFilePath
        )
      }

      if ($AutomateImageBuild.IsPresent) {
        Write-Verbose "Deploying container instance - acr task" -Verbose

        $containerService.CreateContainerInstance(
          $ResourceGroupName,
          $ContainerRegistryName,
          $ImageName,
          $ImageVersion,
          $RegistryUserName,
          $RegistryPassword
        )

        Write-Verbose "Deleting existing ACR task..." -Verbose

        $containerService.DeleteRegistryTask(
          $ContainerRegistryName,
          $ResourceGroupName
        )

        Write-Verbose "Creating a new ACR task for automating image build process via git push/commit to the registry" -Verbose

        $containerService.CreateRegistryTask(
          $AzureDevOpsGitUrl,
          $AzureDevOpsToken,
          $ContainerRegistryName,
          $ImageName,
          $YamlFilePath
        )

        <#
          Write-Verbose "Testing build task" -Verbose

          $containerService.ValidateRegistryContainer(
            $ContainerRegistryName
          )
          #>
      }
    } catch {
      Write-Error "An error ocurred while running New-ContainerDeployment. Details: $($_.Exception.Message)" -ErrorAction Stop
    }
  }

  end {
    Write-Debug ("{0} exited" -f $MyInvocation.MyCommand)
  }
}
