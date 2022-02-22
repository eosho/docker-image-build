[[_TOC_]]

# WBA - Docker Base Image Automation

This repository showcases scenarios for Azure Container Registry Tasks for automating the lifecycle of Docker base images. [ACR Tasks](https://docs.microsoft.com/azure/container-registry/container-registry-tasks-overview) is a suite of features within [Azure Container Registry](https://azure.microsoft.com/services/container-registry/) for performing Docker container builds on Azure, as well as automated OS and framework patching for Docker containers.

This project includes the following Dockerfiles:

The WBA defined base images are located in the `base` folder of the repository root.

- _Dockerfile-alpine_ - Non-parameterized Dockerfile for building the initial base images. References a base image in Docker Hub.
- _Dockerfile-alpine-glibc_ - Dockerfile for building glibc, References a base image in ACR & it is based off the `Dockerfile-alpine` image.
- _Dockerfile-alpine-jdk11_ - Dockerfile for building jdk11. References a base image in ACR & it is based off the `Dockerfile-alpine-gilbc` image.
- _Dockerfile-alpine-jdk14_ - Dockerfile for building jdk14 References a base image in ACR & it is based off the `Dockerfile-alpine-gilbc` image.
- _Dockerfile-alpine-node12_ - Dockerfile for building node12 References a base image in ACR & it is based off the `Dockerfile-alpine` image.
- _Dockerfile-alpine-node14_ - Dockerfile for building node14 References a base image in ACR & it is based off the `Dockerfile-alpine` image.

# Design Approach

The following details the design approach for orchestrating the image build, test, and deploy process.

## Building images - Multi-step

Multi-step tasks is being used to extend the single image build-and-push capability of ACR Tasks with multi-step, multi-container-based workflows. Use multi-step tasks to build, test and push several images, in series or in parallel. Then run those images as commands within a single task run. Each step defines a container image build or push operation, and can also define the execution of a container. Each step in a multi-step task uses a container as its execution environment.

### Multi-step task scenario

Multi-step tasks enable scenarios like the following logic:

- Build, tag, and push one or more container images, in series or in parallel.
- Run and capture unit test and code coverage results.
- Run and capture functional tests. ACR Tasks supports running more than one container, executing a series of requests between them.
- Perform task-based execution, including pre/post steps of a container image build.
- Deploy one or more containers with your favorite deployment engine to your target environment.

A multi-step task in ACR Tasks is defined as a series of steps within a YAML file. Each step can specify dependencies on the successful completion of one or more previous steps. The following task step types are available:

#### Example (simple - build and push):

```yaml
version: v1.1.0
steps:
  - build: -t $Registry/baseimages/alpine/current:$ID -f Dockerfile-alpine .
  - push: ["$Registry/baseimages/alpine/current:$ID"]
```

#### Example (complex - build, test, push)

```yaml
version: v1.1.0
steps:
  - id: build
    build: -t $Registry/baseimages/eotechtest:$ID -f Dockerfile .
  - cmd: -t $Registry/baseimages/eotechtest:$ID
    id: test
    detach: true
    ports:
    - 80
  - cmd: docker stop test
  - id: push
    push:
    - "$Registry/baseimages/eotechtest:$ID
    when:
    - build
    - test
```

### Example (more complex)

A more complex example can be found [here](build-push.wba.yml) - **Current Method**

### Run locally

In order to deploy this locally, run the following command:

```bash
az acr run --registry <acrName> -f build-push.wba.yaml .
```

## Resources

- [Azure Container Registry](https://azure.microsoft.com/services/container-registry/)
- [Azure Container Registry documentation](https://docs.microsoft.com/azure/container-registry/)
- [Automate image builds](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tutorial-build-task)
- [Base image updates](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tutorial-base-image-update)

<!-- LINKS - External -->

[build-quick]: https://docs.microsoft.com/azure/container-registry/container-registry-tutorial-quick-build
[build-task]: https://docs.microsoft.com/azure/container-registry/container-registry-tutorial-build-task
[build-base]: https://docs.microsoft.com/azure/container-registry/container-registry-tutorial-base-image-update

## Next Steps

Learn more about the orchestration process developed for automating the base image build, test and patching process:

- [Orchestration via PowerShell](.docs\01_Orchestration.md)
- [Multi-stage YAML Pipeline](.docs\02_ADOPipelineDesign.md)
- [Image Testing](.docs\03_Testing.md)
- [Security Scanning via ASC](.docs\04_ImgeScanning.md)
