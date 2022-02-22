[[_TOC_]]

# Container Image Scan Vulnerability Assessment

[Azure Security Center scan](https://docs.microsoft.com/en-us/azure/security-center/defender-for-container-registries-introduction) for container registry images for vulnerabilities and provide classified assessments with full remediation steps and analysis. With the help of Azure Defender for container registries, any image pushed to your container registry will be scanned immediately for vulnerabilities. In addition, any image pulled within a 30 day period will also be scanned.

![asc](./images/acr-asc-scan.png =600x)

Keep in mind, Azure Defender will need to be enabled before you can reap the benefits of this implementation. Additional automation can also be developed to notify owners when vulnerabilities are found during the scanning.

> **NOTE**: The current implementation does not account for the notification process.

## Image Scan script

Automation script located in `scripts\ImageScanSummaryAssessment.ps1` is used to extract summary results, enrich you CI/CD with container image scan results and more.

## Image Scan Pipeline

As part of the ADO pipeline design, the container image scan stage performs all checks to make sure your deployed images are compliant and following the best practices from the field.

```yaml
parameters:
  serviceConnection: ''
  containerRegistryName: ''
  buildImages: []

jobs:
  - job: 'WaitFor_ASC_ScanResult'
    pool: Server
    steps:
      - task: Delay@1
        displayName: Wait for scan result
        inputs:
          delayForMinutes: '5'

  - job: 'Image_Scan_Gate'
    dependsOn: 'WaitFor_ASC_ScanResult'
    pool:
      vmImage: ubuntu-latest
    steps:
      - checkout: self

      - ${{ each image in parameters.buildImages }}:
        - task: AzureCLI@2
          displayName: 'Image Scan security gate - ${{ image }}'
          inputs:
            azureSubscription: "$(serviceConnection)"
            scriptType: pscore
            scriptLocation: 'scriptPath'
            scriptPath: '$(System.DefaultWorkingDirectory)/scripts/ImageScanSummaryAssessmentGate.ps1'
            arguments: '-RegistryName $(containerRegistryName) -Repository "baseimages/alpine/${{ image }}"'

```
