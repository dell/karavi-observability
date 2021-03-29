<!--
Copyright (c) 2020 Dell Inc., or its subsidiaries. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
-->

# Karavi Observability Install Scripts

This `installer` directory contains scripts to perform installation of Karavi Observability in the following environments:

- [Online Karavi Observability Helm Chart Installer](#online-karavi-observability-helm-chart-installer) - Installation environment has access to the internet to download Docker images, helm charts, and other dependencies.
- [Offline Karavi Observability Helm Chart Installer](#offline-karavi-observability-helm-chart-installer) - Installation environment does not have access to the internet.

# Online Karavi Observability Helm Chart Installer

The following instructions can be followed to install Karavi Observability in an environment that has an internet connection and is capable of downloading the required helm chart and Docker images.

## Dependencies

A Linux based system, with internet access, will be used to execute the script to install Karavi Observability into a Kubernetes/Openshift enviornment that also has internet access.

| Dependency            | Usage |
| --------------------- | ----- |
| `kubectl`   | `kubectl` will be used to verify the Kubernetes/OpenShift environment|
| `helm`   | `helm` will be used to install the Karavi Observability helm chart|
| `jq`     | `jq` will be used to parse the Karavi Authorization configuration file during installation|

## Installation script
The installation script is located at https://github.com/dell/karavi-observability/blob/main/installer/karavi-observability-install.sh. The script performs the current steps during installation of Karavi Observability:

- Verify that Karavi Observability is not yet installed
- Verify the Kubernetes/Openshift versions are supported
- Verify helm version is supported
- Add the Dell helm chart repository
- Refresh the helm chart repositories to download any recent changes
- Create the Karavi Observability namespace (if not already created)
- Copy the vxflexos-config Secret from the CSI PowerFlex namespace into the Karavi Observability namespace (if not already copied)
- Install the CertManager CRDs (if not already installed)
- Install the Karavi Observability helm chart
- Wait for the Karavi Observability pods to become ready

If Karavi Authorization is enabled for the CSI drivers installed in the same Kubernetes cluster, the installation script will perform the current steps to enable Karavi Observability to use the same Karavi Authorization instance:
- Verify the `karavictl` binary is available.
- Verify the appropriate Secret exists in the CSI driver namespace.
- Query the CSI driver environment to get references to the Karavi Authorization sidecar-proxy Docker image and URL of the proxy server.
- Updates the Karavi Observability deployment to use the existing Karavi Authorization instance.

### Usage of the script is as follows:
```
[user@system /home/user/karavi-observability/installer]# ./karavi-observability-install.sh --help

Help for ./karavi-observability-install.sh

Usage: ./karavi-observability-install.sh mode options...
Mode:
  install                                                     Installs Karavi Observability and enables Karavi Authorization if already installed
  enable-authorization                                        Updates existing installation of Karavi Observability with Karavi Authorization
Options:
  Required
  --namespace[=]<namespace>                                   Namespace where Karavi Observability will be installed
  Optional
  --auth-image-addr                                           Docker registry location of the Karavi Authorization sidecar proxy image
  --auth-proxy-host                                           Host address of the Karavi Authorization proxy server
  --csi-powerflex-namespace[=]<csi powerflex namespace>       Namespace where CSI PowerFlex is installed, default is 'vxflexos'
  --set-file                                                  Set values from files used during helm installation (can be specified multiple times)
  --skip-verify                                               Skip verification of the environment
  --values[=]<values.yaml>                                    Values file, which defines configuration values
  --verbose                                                   Display verbose logging
  --version[=]<helm chart version>                            Helm chart version to install, default value will be latest
  --help                                                      Help
```

## Workflow

To perform an online installation of Karavi Observability, the following steps should be performed:

1. Clone the GitHub repository to be able to execute the scripts.
2. Execute the installation script.

### Clone the GitHub repository

1. Clone the GitHub repository:
```
[user@system /home/user]# git clone https://github.com/dell/karavi-observability.git
```

### Execute the installation script

1. Change to the installer directory:
```
[user@system /home/user]# cd karavi-observability/installer
```

2. Execute the installation script.
The following example will install Karavi Observability into the `karavi` namespace.
```
[user@system /home/user/karavi-observability/installer]# ./karavi-observability-install.sh install --namespace karavi --values myvalues.yaml
---------------------------------------------------------------------------------
> Installing Karavi Observability in namespace karavi on 1.19
---------------------------------------------------------------------------------
|
|- Karavi Observability is not installed                            Success
|
|- Karavi Authorization will be enabled during installation
|
|- Verifying Kubernetes versions
  |
  |--> Verifying minimum Kubernetes version                         Success
  |
  |--> Verifying maximum Kubernetes version                         Success
|
|- Verifying helm version                                           Success
|
|- Configure helm chart repository
  |
  |--> Adding helm repository https://dell.github.io/helm-charts    Success
  |
  |--> Updating helm repositories                                   Success
|
|- Creating namespace karavi                                        Success
|
|- Copying Secret from vxflexos to karavi                           Success
|
|- Installing CertManager CRDs                                      Success
|
|- Installing Karavi Observability helm chart                       Success
|
|- Waiting for pods in namespace karavi to be ready                 Success
|
|- Copying Secret from vxflexos to karavi                           Success
|
|- Enabling Karavi Authorization for Karavi Observability           Success
|
|- Waiting for pods in namespace karavi to be ready                 Success
```

# Offline Karavi Observability Helm Chart Installer

The following instructions can be followed when a Helm chart will be installed in an environment that does not have an internet connection and will be unable to download the Helm chart and related Docker images.

## Dependencies

Multiple Linux based systems may be required to create and process an offline bundle for use.

* One Linux based system, with internet access, will be used to create the bundle. This involves the user invoking a script that utilizes `docker` to pull and save container images to file.
* One Linux based system, with access to an image registry, to invoke a script that uses `docker` to restore container images from file and push them to a registry

If one Linux system has both internet access and access to an internal registry, that system can be used for both steps.

Preparing an offline bundle requires the following utilities:

| Dependency            | Usage |
| --------------------- | ----- |
| `docker`   | `docker` will be used to pull images from public image registries, tag them, and push them to a private registry.<br>Required on both the system building the offline bundle as well as the system preparing for installation. <br>Tested version is `docker` 18.09+

## Workflow

To perform an offline installation of a helm chart, the following steps should be performed:

1. Build an offline bundle.
2. Unpack the offline bundle and prepare for installation.
3. Perform a Helm installation.

### Build the Offline Bundle

1. Copy the `offline-installer.sh` script to a local Linux system using `curl` or `wget`:

```
[user@anothersystem /home/user]# curl https://raw.githubusercontent.com/dell/helm-charts/main/charts/karavi-observability/installer/offline-installer.sh --output offline-installer.sh
```

or

```
[user@anothersystem /home/user]# wget -O offline-installer.sh https://raw.githubusercontent.com/dell/helm-charts/main/charts/karavi-observability/installer/offline-installer.sh
```

2. Set the file as executable.

```
[user@anothersystem /home/user]# chmod +x offline-installer.sh
```

3. Build the bundle by providing the Helm chart name as the argument:

```
[user@anothersystem /home/user]# ./offline-installer.sh -c dell/karavi-observability

*
* Adding Helm repository https://github.com/dell/helm-charts


*
* Downloading Helm chart dell/karavi-observability to directory /home/user/offline-karavi-observability-bundle/helm-original


*
* Downloading and saving Docker images

   dellemc/karavi-metrics-powerflex:0.1.0
   dellemc/karavi-topology:0.1.0

*
* Compressing offline-karavi-observability-bundle.tar.gz
```

### Unpack the Offline Bundle

1. Copy the bundle file to another Linux system that has access to the internal Docker registry and that can install the Helm chart. From that Linux system, unpack the bundle.

```
[user@anothersystem /home/user]# tar -xzf offline-karavi-observability-bundle.tar.gz
```

2. Change directory into the new directory created from unpacking the bundle:

```
[user@anothersystem /home/user]# cd offline-karavi-observability-bundle
```

3. Prepare the bundle by providing the internal Docker registry URL.

```
[user@anothersystem /home/user/offline-karavi-observability-bundle]# ./offline-installer.sh -p my-registry:5000

*
* Loading, tagging, and pushing Docker images to registry my-registry:5000/

   dellemc/karavi-metrics-powerflex:0.1.0 -> my-registry:5000/karavi-metrics-powerflex:0.1.0
   dellemc/karavi-topology:0.1.0 -> my-registry:5000/karavi-topology:0.1.0
```

### Perform Helm installation

1. Change directory to `helm` which contains the updated Helm chart directory:
```
[user@anothersystem /home/user/offline-karavi-observability-bundle]# cd helm
```

2. Install necessary cert-manager CustomResourceDefinitions provided:
```
[user@anothersystem /home/user/offline-karavi-observability-bundle/helm]# kubectl apply --validate=false -f cert-manager.crds.yaml
```

3. The vxflexos-config Secret from the namespace where CSI Driver for Dell EMC PowerFlex is installed must be copied to the namespace where Karavi Observability is to be installed.

Example command to copy the Secret from the vxflexos namespace to the karavi namespace.
```
[user@anothersystem /home/user/offline-karavi-observability-bundle/helm]# kubectl get secret vxflexos-config -n vxflexos -o yaml | sed 's/namespace: vxflexos/namespace: karavi/' | kubectl create -f -
```

4. Now that the required images have been made available and the Helm chart's configuration updated with references to the internal registry location, installation can proceed by following the instructions that are documented within the Helm chart's repository.

```
[user@anothersystem /home/user/offline-karavi-observability-bundle/helm]# helm install -n install-namespace app-name karavi-observability

NAME: app-name
LAST DEPLOYED: Fri Nov  6 08:48:13 2020
NAMESPACE: install-namespace
STATUS: deployed
REVISION: 1
TEST SUITE: None

```

5. (Optional) The following steps can be performed to enable Karavi Observability to use an existing instance of Karavi Authorization for accessing the REST API for the given storage systems.

Copy the proxy Secret into the Karavi Observability namespace:
```
[user@anothersystem /home/user/offline-karavi-observability-bundle/helm]# kubectl get secret proxy-authz-tokens -n vxflexos -o yaml | sed 's/namespace: vxflexos/namespace: karavi/' | kubectl create -f -
```

Use `karavictl` to update the Karavi Observability deployment to use Karavi Authorization. Required parameters are the location of the sidecar-proxy Docker image and URL of the Karavi Authorization proxy. If Karavi Authorization was installed using certificates, the flags `--insecure=false` and `--root-certificate <location-of-root-certificate>` must be also be provided. If certificates were not provided during installation, the flag `--insecure=true` must be provided.
```
[user@anothersystem /home/user/offline-karavi-observability-bundle/helm]# kubectl get secrets,deployments -n karavi -o yaml | karavictl inject --insecure=false --root-certificate <location-of-root-certificate> --image-addr <sidecar-proxy-image-location> --proxy-host <proxy-host> | kubectl apply -f -
```
