# Interface
class IDefenderContainerScan {
  [void] SetSubscriptionContext([string] $SubscriptionId) {
    Throw "Method Not Implemented"
  }

  [void] InstallResourceGraphModule() {
    Throw "Method Not Implemented"
  }

  [object] GetRegistry([string] $RegistryName, [string] $ResourceGroupName) {
    Throw "Method Not Implemented"
  }

  [string] GetRegistryTag([string] $RegistryName, [string] $RepositoryName) {
    Throw "Method Not Implemented"
  }

  [string] GenerateARGQuery([string] $RegistryName, [string] $RepositoryName, [string] $ImageDigest) {
    Throw "Method Not Implemented"
  }

  [object] InvokeRegistryQuarantine([string] $RegistryName, [string] $ResourceGroupName, [string] $QuarantineMode) {
    Throw "Method Not Implemented"
  }

  [object] DeleteContainerRepository([string] $RegistryName, [string] $RepositoryName) {
    Throw "Method Not Implemented"
  }
}

# Helper extends to interface
class DefenderContainerScan : IDefenderContainerScan {
  [string] $SubscriptionId
  [string] $RegistryName
  [string] $RepositoryName
  [string] $ResourceGroupName
  [string] $Tag
  [string] $ImageDigest
  [string] $QuarantineMode

  DefenderContainerScan() { }

  # Method: Sets the subscription context
  [void] SetSubscriptionContext([string] $SubscriptionId) {
    $this.SubscriptionId = $SubscriptionId

    try {
      $null = Set-AzContext $this.SubscriptionId -Scope Process -ErrorAction Stop
    } catch {
      Write-Error "$($_.Exception.Message)" -ErrorAction Stop
    }
  }

  # Method: Get the container registry
  [object] GetRegistry([string] $RegistryName, [string] $ResourceGroupName) {
    $this.RegistryName = $RegistryName
    $this.ResourceGroupName = $ResourceGroupName

    return Get-AzContainerRegistry -Name $this.RegistryName -ResourceGroupName $this.ResourceGroupName -ErrorAction Stop
  }

  # Method: Get the container registry tags
  [object] GetRegistryTag([string] $RegistryName, [string] $RepositoryName) {
    $this.RegistryName = $RegistryName
    $this.RepositoryName = $RepositoryName

    return (Get-AzContainerRegistryTag -RegistryName $this.RegistryName -RepositoryName $this.RepositoryName -ErrorAction Stop | Select-Object -ExpandProperty Tags | Select-Object -First 1)
  }

  # Install Resource Graph module
  [void] InstallResourceGraphModule() {
    try {
      $module = Get-InstalledModule -Name "Az.ResourceGraph" -ErrorAction SilentlyContinue
      if (-not $module) {
        $checkModule = Install-Module -Name "Az.ResourceGraph" -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
        if ($checkModule) {
          Write-Host "Resource Graph module installed successfully"
        } else {
          Write-Error "Resource Graph module installation failed"
        }
      } else {
        Write-Host "Resource Graph module already installed"
      }
    } catch {
      Write-Error "$($_.Exception.Message)" -ErrorAction Stop
    }
  }

  # Method: Get the container scan results
  [string] GenerateARGQuery([string] $RegistryName, [string] $RepositoryName, [string] $ImageDigest) {
    $this.RegistryName = $RegistryName
    $this.RepositoryName = $RepositoryName
    $this.ImageDigest = $ImageDigest

    $query = "securityresources
    | where type == 'microsoft.security/assessments/subassessments'
    | where id matches regex '(.+?)/providers/Microsoft.ContainerRegistry/registries/(.+)/providers/Microsoft.Security/assessments/dbd0cb49-b563-45e7-9724-889e799fa648/'
    | extend registryResourceId = tostring(split(id, '/providers/Microsoft.Security/assessments/')[0])
    | extend registryResourceName = tostring(split(registryResourceId, '/providers/Microsoft.ContainerRegistry/registries/')[1])
    | extend imageDigest = tostring(properties.additionalData.imageDigest)
    | extend repository = tostring(properties.additionalData.repositoryName)
    | extend scanFindingSeverity = tostring(properties.status.severity), scanStatus = tostring(properties.status.code)
    | summarize scanFindingSeverityCount = count() by scanFindingSeverity, scanStatus, registryResourceId, registryResourceName, repository, imageDigest
    | summarize  severitySummary = make_bag(pack(scanFindingSeverity, scanFindingSeverityCount)) by registryResourceId, registryResourceName, repository, imageDigest, scanStatus"

    # Add filter to get scan summary for specific provided image
    $filter = "| where imageDigest =~ '$($this.ImageDigest)' and repository =~ '$($this.RepositoryName)' and registryResourceName =~ '$($this.RegistryName)'"
    $query = @($query, $filter) | Out-String

    return $query
  }

  # Method: Quarantine the registry before vulnerability scan
  [object] InvokeRegistryQuarantine([string] $RegistryName, [string] $ResourceGroupName, [string] $QuarantineMode) {
    $this.RegistryName = $RegistryName
    $this.ResourceGroupName = $ResourceGroupName
    $this.QuarantineMode = $QuarantineMode.ToLower()

    if ($this.QuarantineMode -eq "disable") {
      $this.QuarantineMode = "disabled"
    } else {
      $this.QuarantineMode = "enabled"
    }

    $resourceId = $this.GetRegistry($this.RegistryName, $this.ResourceGroupName)

    $resource = Get-AzResource -ResourceId $resourceId.Id -ErrorAction Stop
    $resource.Properties.policies.quarantinePolicy.status = "$($this.QuarantineMode)"
    $resource | Set-AzResource -Force -ErrorAction Stop
    return $resource.Properties.policies.quarantinePolicy.status
  }

  # Method: Deletes the entire container repository if required
  [object] DeleteContainerRepository([string] $RegistryName, [string] $RepositoryName) {
    $this.RegistryName = $RegistryName
    $this.RepositoryName = $RepositoryName

    return Remove-AzContainerRegistryRepository -Name $this.RepositoryName -RegistryName $this.RegistryName -ErrorAction Stop
  }
}

function Invoke-AzDefenderImageScan {
  <#
  .SYNOPSIS
    Automation script to include ASC vulnerability assessment scan summary for provided image as a gate.
    Check result and assess whether to pass security gate by findings severity.

  .DESCRIPTION
    Microsoft Defender for Cloud scan Azure container registry (ACR) images for known vulnerabilities on multiple scenarios including image push.
    (https://docs.microsoft.com/en-us/azure/security-center/defender-for-container-registries-introduction#when-are-images-scanned)
    Using this tool you can have a security gate as part of image release(push). In case there's a major vulnerability in image, gate(script) will fail to allow exit in CI/CD pipelines.

  .PARAMETER SubscriptionId
    Azure subscription Id where your container registry is located. This is an optional parameter.

  .PARAMETER RegistryName
    Azure container registry resource name image is stored. This is a required parameter.

  .PARAMETER RepositoryName
    The name of the repository where the image is stored. This is a required parameter.

  .EXAMPLE
    PS C:\> Invoke-AzDefenderImageScan -SubscriptionId $SubscriptionId -RegistryName $RegistryName -RepositoryName $RepositoryName

    Sets subscription context and invokes the script to find vulnerabilities in provided image.

  .EXAMPLE
    PS C:\> Invoke-AzDefenderImageScan -RegistryName $RegistryName -RepositoryName $RepositoryName

    Invokes the script to find vulnerabilities in provided image.

  .INPUTS
    Inputs (if any)

  .OUTPUTS
    Output (if any)

  .NOTES
    General notes
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [string] $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string] $RegistryName,

    [Parameter(Mandatory = $true)]
    [string] $RepositoryName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Enable", "Disable")]
    [string] $QuarantineMode,

    [Parameter(Mandatory = $false)]
    [switch] $DeleteContainerRepository
  )

  [int] $scanExtractionRetryCount = 5
  [int] $mediumFindingsCountFailThreshold = 5
  [int] $lowFindingsCountFailThreshold = 15

  # Get the running script name
  $scriptName = $($MyInvocation.MyCommand | Select-Object -ExpandProperty Name)

  # Initialize the class
  $initializeClass = [DefenderContainerScan]::new()

  # Set subscription context
  if (-not [string]::IsNullOrEmpty($SubscriptionId)) {
    Write-Output "[$scriptName] - Setting subscription context"
    $initializeClass.SetSubscriptionContext($SubscriptionId)
  }

  # Delete container repository
  if ($DeleteContainerRepository.IsPresent) {
    Write-Output "[$scriptName] - Deleting container repository -  $RepositoryName"
    $initializeClass.DeleteContainerRepository($RegistryName, $RepositoryName)
  } else {
    # Install Resource Graph module - optional
    # $initializeClass.InstallResourceGraphModule()

    # Get tag
    $tag = $initializeClass.GetRegistryTag($RegistryName, $RepositoryName)
    if (-not [string]::IsNullOrEmpty($tag)) {
      Write-Output "[$scriptName] - Image tag version: $($tag.Name)"

      $imageDigest = $tag.Digest
      if ([string]::IsNullOrEmpty($imageDigest)) {
        Write-Error "[$scriptName] - Image '$($Repository):$($tag.Name)' was not found! (Registry: $RegistryName)" -ErrorAction Stop
      } else {
        Write-Output "[$scriptName] - Image digest: $imageDigest"
      }

      # Generate ARG query
      $query = $initializeClass.GenerateARGQuery($RegistryName, $RepositoryName, $imageDigest)

      # Get result with retry policy incase ASG is not ready
      $i = 0
      while (($result = Search-AzGraph -Query $query).Count -eq 0 -and ($i = $i + 1) -lt $scanExtractionRetryCount) {
        Write-Output "[$scriptName] - No results for image $($RepositoryName):$($tag.Name) yet - retry [$i/$($scanExtractionRetryCount)]..."
        Start-Sleep -s 20
      }

      if ((-not $result) -or ($result.Count -eq 0)) {
        Write-Output "[$scriptName] - No results were found for digest: $imageDigest after [$scanExtractionRetryCount] retries!"
      } else {
        # Extract scan summary from result
        $scanSummary = $result
        Write-Output "[$scriptName] - Scan summary: $($scanSummary | Out-String)"

        if ($scanSummary.ScanStatus -eq "healthy") {
          Write-Output "[$scriptName] - Healthy scan result, no major vulnerabilities found in image"
        } elseif ($scanSummary.ScanStatus -eq "unhealthy") {
          # Check if there are major vulnerabilities  found - customize by parameters
          if (($scanSummary.severitySummary.high -gt 0) -or ($scanSummary.severitySummary.medium -gt $mediumFindingsCountFailThreshold) -or ($scanSummary.severitySummary.low -gt $lowFindingsCountFailThreshold)) {
            Write-Error "[$scriptName] - Unhealthy scan result, major vulnerabilities found in image summary"
          } else {
            Write-Warning "[$scriptName] - Unhealthy scan result, some vulnerabilities found in image"

            # TODO: Print the high, medium and low vulnerabilities found

            # Enable or disable quarantine on the container registry
            # We should probably quarantine all registries by default so no one can pull from them yet until ASC scans the image and vulnerabilities are fixed
            try {
              $quarantineStatus = $initializeClass.InvokeRegistryQuarantine($RegistryName, $RepositoryName, $QuarantineMode)
              if ($quarantineStatus) {
                Write-Output "[$scriptName] - Registry $($RegistryName) quarantine mode: $($quarantineStatus)"
              } else {
                Write-Output "[$scriptName] - Registry $($RegistryName) was not quarantined"
              }
            } catch {
              Write-Error "[$scriptName] - Failed to quarantine registry $($RegistryName). Details: $($_.Exception.Message)"
            }
          }
        } else {
          Write-Error "[$scriptName] - Unknown scan result returned" -ErrorAction Stop
        }
      }
    } else {
      Write-Error "[$scriptName] - No tag found for image $($RepositoryName):$($tag.Name)" -ErrorAction Stop
    }
  }
}
