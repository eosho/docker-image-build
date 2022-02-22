[[_TOC_]]

# Pipeline Design - (IaCS)

## Overview

The objective of this project built on Azure DevOps multi-stage YAML pipeline is to provide an approach of orchestrated solution for building docker images in the cloud using Infrastructure as Code Source.

Azure DevOps multi-stage YAML pipeline has a concept of [Stages]() in which you can have a collection of jobs, such as "Build", "Test" or "Deploy". In this orchestrated solution, we are using the following stages:

### Pipeline Stages

- **PreReq**: Compiling Azure bicep files and crating an ADO artifact for consumption.
- **Deploy_Bicep**: Deploys all infrastructure resources in your Azure subscription.
- **Build_Push_Image**: Builds all images, performs tests, and pushes images to the container registry.
- **Automate_ACR_task**: Optional. If set to `true` this will enable you to natively build images in the cloud when you commit changes to your git repository. All images and dependencies will be build, tagged and patched.
- **ASC_Image_Scan**: Optional. If set to `true`, it will run a PowerShell script to obtain any vulnerability scan reports from Azure Security Center.
- **Teardown_Env**: Optional. If set to `true`, it will tear down the entire environment.

> ![stages](./images/pipeline_stages.png =1000x)

### Multi-Stage YAML Pipeline Example

Consider the below sample hello-world pipeline for understanding the concept of multi-stage pipelines.

```yaml
stages:
– stage: Build
  jobs:
  – job: Build
    pool:
      vmImage: 'ubuntu-latest'
    continueOnError: true
    steps:
    – script: echo "hello to my first Build"
– stage: dev_deploy
  jobs:
  – deployment: dev_deploy
    pool:
      vmImage: 'ubuntu-latest'
    environment: 'dev-hello'
    strategy:
      runOnce:
        deploy:
          steps:
          – script: echo "hello, dev world !!!"
– stage: qa_deploy
  jobs:
  – deployment: qa_deploy
    pool:
      vmImage: 'ubuntu-latest'
    environment: 'qa-hello'
    strategy:
      runOnce:
        deploy:
          steps:
          – script: echo "hello, qa world !!!"
```

In this example, there a 3 stages:
- Build stage: when run, prints "hello to my first build"
- dev_deploy: when run, prints "hello, dev world !!!"
- qa_deploy: when run, prints "hello, qa world !!!"

Each stage performs various steps.

---

## How to Deploy

In order to operate this solution, you need to be aware of how the pipeline works. Inside the `.config` root folder of the repository are various `global.<environmentName>.yaml` configuration files. In this file we are able to define custom properties for each deployment environment, eg: dev or prod.

## Environment Config file
```yaml
# Environment specific variables
# Update these values to be specific to your environment.

variables:
  serviceConnection: some-spn-with-perm
  environmentName: dev
  subscriptionId: xxxxxxx-b21c-4794-xxxx-f508c89d08c2
  region: eastus2
  prefix: eotech
  resourceGroupName: ${{ variables.environmentName }}-${{ variables.prefix }}-acr-rg-${{ variables.region }}-01
  keyVaultName: ${{ variables.environmentName }}-${{ variables.prefix }}-kv-01
  containerRegistryName: ${{ variables.environmentName }}${{ variables.prefix }}acr01
  yamlBuildTaskFile: .\build-push.wba.yml
```

In the above sample config file, we have the following environment variables that gets injected into the pipeline at runtime.

| Variable Name | Description | Default Value |
|:-----------:|:-----------:|:-----------:|
| `serviceConnection` | Your Service connection resource in ADO. Must be configured to your subscription |  |
| `environmentName` | The deployment environment name. Take only `dev` or `prod` | `dev` |
| `subscriptionId` | Your environment subscription ID value |  |
| `region` | The Azure deployment region where your resources will live | `eastus2` |
| `prefix` | The deployment prefix for your Azure infrastructure |  |
| `resourceGroupName` | The name of your resource group | `${{ variables.environmentName }}-${{ variables.prefix }}-acr-rg-${{ variables.region }}-01` |
| `keyVaultName` | The name of your Azure key vault for storing SPN ID and Client Secret | `${{ variables.environmentName }}-${{ variables.prefix }}-kv-01` |
| `containerRegistryName` | The name of your container registry | `${{ variables.environmentName }}${{ variables.prefix }}acr01` |
| `yamlBuildTaskFile` | The path to your YAML file definition. This describes how your images are built, tested and deployed in ACR | `.\build-push.wba.yml` |

>**NOTE**: You can customize the naming convention of the Azure infrastructure being deployed at your own discretion.

---

## Pipeline

The pipeline is located in `.azdo` root folder of your repository. It consists of the following folder structure:

```text
.
|
|- .azdo/  ______________________________________ # Root folder for all pipeline templates
|  |- templates/  _______________________________ # Subfolder for a all pipeline stages
|     |- pipeline.jobs.asc-scan.yaml ____________ # Azure Security Scan pipeline stage
|     |- pipeline.jobs.automate.yaml ____________ # Manages ACR task for automated cloud build/deploy process pipeline stage
|     |- pipeline.jobs.build.yaml _______________ # Builds your image using the `yamlBuildTaskFile`
|     |- pipeline.jobs.deploy.yaml ______________ # Deploys/Validate Bicep file for your infrastructure deployment
|     |- pipeline.jobs.pre.yaml _________________ # Compiles all bicep modules for deployment
|     |- pipeline.jobs.teardown.yaml ____________ # Tears down the entire environment (Deletes RG)
|  |- pipeline.variables.yaml  __________________ # Pipeline variable file
|  |- pipeline.yaml  ____________________________ # Master pipeline file - orchestrates all templates above.
|
```

### How to run the pipeline

The pipeline has the following inline parameters input before it can run:

> ![params](./images/pipeline_params.png =500x)

#### Steps

1. Select the appropriate branch
1. Select the deployment environment
    - dev, or
    - prod
1. Leave `Use YAML` **checked**.
1. Optional. If you would like to configure ACR task, check the box `Automate Build via repo push`
1. Optional. If you would like to perform a vulnerability scan via ASC, check the box `Vulnerability Scan via ASC`
    - This parameter also requires the list of images to scan:
      - current
      - glibc
      - jdk11
      - jdk14
      - node12
      - node14
1. Optional. If you would like to perform a bicep validation, check the box `Validate Bicep`
1. Optional. If you would like to perform a clean up of the entire environment (Delete RG), check the box `Delete RG (clean up)`
