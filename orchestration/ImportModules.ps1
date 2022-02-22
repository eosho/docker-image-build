$rootPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

$modulePath = Join-Path "$rootPath" -ChildPath '' -AdditionalChildPath @('containerService', 'AzureContainerService.ps1')
. $modulePath

$modulePath = Join-Path "$rootPath" -ChildPath '' -AdditionalChildPath @('deploymentService', 'ARMDeploymentService.ps1')
. $modulePath

$modulePath = Join-Path "$rootPath" -ChildPath '' -AdditionalChildPath @('orchestrationService', 'New-ARMDeployment.ps1')
. $modulePath

$modulePath = Join-Path "$rootPath" -ChildPath '' -AdditionalChildPath @('orchestrationService', 'New-ContainerDeployment.ps1')
. $modulePath

$modulePath = Join-Path "$rootPath" -ChildPath '' -AdditionalChildPath @('enums', 'EnumGlobal.ps1')
. $modulePath
