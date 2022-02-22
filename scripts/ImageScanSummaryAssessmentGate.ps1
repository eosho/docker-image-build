<#
.SYNOPSIS
  Automation script to include ASC vulnerability assessment scan summary for provided image as a gate.
  Check result and assess whether to pass security gate by findings severity.

.DESCRIPTION
  Azure security center (ASC) scan Azure container registry (ACR) images for known vulnerabilities on multiple scenarios including image push.
 (https://docs.microsoft.com/en-us/azure/security-center/defender-for-container-registries-introduction#when-are-images-scanned)
  Using this tool you can have a security gate as part of image release(push) or
  deployment to cluster to check if for image there is existent scan in ASC (for example part following push) - retry ,
  And assess it's findings by configurable thresholds to decide whether to fail the gate - i.e the release/deployment.
  Script extracts provided ACR image digest, try to extract ASC scan summary using Azure resource graph AZ CLI module and check if result is healthy or not.
  If Healthy, will exit gate successfully, otherwise if unhealthy,
  Check for any high findings or medium findings count suppress their thresholds to fail the gate, otherwise will set gate in warning mode.
  In case there's a major vulnerability in image, gate(script) will fail to allow exit in CI/CD pipelines.

.PARAMETER registryName
  [mandatory]
  Azure container registry resource name image is stored.
.PARAMETER repository
  [mandatory]
  It can be any EXISTING resource group, using the ASC default "DefaultResourceGroup-XXX" is one option.
  Note: Since the ASC VA solution is not an Azure resource it will not be listed under the resource group, but still it is attached to it.
.PARAMETER tag
  [mandatory]
  The name of the new solution
.PARAMETER scanExtractionRetryCount
  [optional]
  Max retries to get image scan summary from ASC. (Useful for waiting for scan result to finish following image push).
.PARAMETER mediumFindingsCountFailThreshold
  [optional]
  Threshold to fail gate on Medium severity findings count in scan (default is 5)
  ** In the case of High severity finding gate will always fail.**
.PARAMETER lowFindingsCountFailThreshold
  [optional]
  Threshold to fail gate on Low severity findings count in scan (default is 15)
  ** In the case of High severity finding gate will always fail.**

.EXAMPLE
	.\ImageScanSummaryAssessmentGate.ps1 -RegistryName <registryResourceName> -Repository <repository> -tag <tag>

.NOTES
   AUTHOR: Tomer Weinberger - Software Engineer at Microsoft Azure Security Center
#>

# Prerequisites
# Azure CLI installed
# Optional: Azure CLI Resource Graph extension installed (installed as part of script)
Param(
  # Image registry name
  [Parameter(Mandatory = $true)]
  [string] $RegistryName,

  # Image repository name in registry
  [Parameter(Mandatory = $true)]
  [string] $Repository,

  # Max retries to get image scan summary from ASC.
  $scanExtractionRetryCount = 5,

  # Medium severity findings failure threshold
  $mediumFindingsCountFailThreshold = 5,

  # Low severity findings failure threshold
  $lowFindingsCountFailThreshold = 15
)

az extension add --name resource-graph -y

# Grab the latest tag always
$tag = az acr repository show-tags --name $RegistryName --repository $Repository --top 1 -o tsv

$imageDigest = az acr repository show -n $registryName --image "$($repository):$($tag)" -o tsv --query digest
if (!$imageDigest) {
  Write-Error "Image '$($repository):$($tag)' was not found! (Registry: $registryName)"
  exit 1
}

Write-Output "Image Digest: $imageDigest"

# All images scan summary ARG query.
$query = "securityResources
 | where type == 'Microsoft.Security/assessments/subAssessments'
 | where id matches regex  '(.+?)/providers/Microsoft.ContainerRegistry/registries/(.+)/providers/Microsoft.Security/assessments/dbd0cb49-b563-45e7-9724-889e799fa648/'
 | extend registryResourceId = tostring(split(id, '/providers/Microsoft.Security/assessments/')[0])
 | extend registryResourceName = tostring(split(registryResourceId, '/providers/Microsoft.ContainerRegistry/registries/')[1])
 | extend imageDigest = tostring(properties.additionalData.imageDigest)
 | extend repository = tostring(properties.additionalData.repositoryName)
 | extend scanFindingSeverity = tostring(properties.status.severity), ScanStatus = tostring(properties.status.code)
 | summarize scanFindingSeverityCount = count() by scanFindingSeverity, ScanStatus, registryResourceId, registryResourceName, repository, imageDigest
 | summarize  SecuritySummary = make_bag(pack(scanFindingSeverity, scanFindingSeverityCount)) by registryResourceId, registryResourceName, repository, imageDigest, ScanStatus"

# Add filter to get scan summary for specific provided image
$filter = "| where imageDigest =~ '$imageDigest' and repository =~ '$Repository' and registryResourceName =~ '$registryName'"
$query = @($query, $filter) | out-string

Write-Output "Query: $query"

# Remove query's new line to use ARG CLI
$query = $query -replace [Environment]::NewLine, "" -replace "`r`n", "" -replace "`n", ""

# Get result wit retry policy
$i = 0
while (($result = az graph query -q $query -o json | ConvertFrom-Json).count -eq 0 -and ($i = $i + 1) -lt $scanExtractionRetryCount) {
  Write-Output "No results for image $($repository):$($tag) yet - retry [$i/$scanExtractionRetryCount]..."
  Start-Sleep -s 20
}

if (!$result -or $result.count -eq 0) {
  Write-Output "No results were found for digest: $imageDigest after [$scanExtractionRetryCount] retries!"
} else {
  # Extract scan summary from result
  $scanSummary = $result.data[0]
  Write-Output "Scan summary: $($scanSummary | out-string)"

  if ($scanSummary.ScanStatus -eq "healthy") {
    Write-Output "Healthy scan result, no major vulnerabilities found in image"
  } elseif ($scanSummary.ScanStatus -eq "unhealthy") {
    # Check if there are major vulnerabilities  found - customize by parameters
    if ($scanSummary.SecuritySummary.high -gt 0 -or $scanSummary.SecuritySummary.medium -gt $mediumFindingsCountFailThreshold -or $scanSummary.SecuritySummary.low -gt $lowFindingsCountFailThreshold) {
      Write-Error "Unhealthy scan result, major vulnerabilities found in image summary"
    } else {
      Write-Warning "Unhealthy scan result, some vulnerabilities found in image"
    }
  } else {
    Write-Error "Unknown scan result returned"
  }
}
