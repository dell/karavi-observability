<!--
Copyright (c) 2020 Dell Inc., or its subsidiaries. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
-->

# Getting Started Guide

This project provides Kubernetes administrators insight into CSI (Container Storage Interface) Driver persistent storage topology, usage and performance. Metrics data is collected and pushed to the [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector), so it can be processed, and exported in a format consumable by Prometheus. Topology data related to containerized volumes that are provisioned by a CSI (Container Storage Interface) Driver is also captured. The metrics and topology data are visualized through Grafana dashboards. SSL certificates for TLS between nodes are handled by [cert-manager](https://github.com/jetstack/cert-manager).

## Karavi Observability Capabilities

| Feature | PowerFlex |
| -------- | --------- |
| Storage Pool Consumption By CSI Driver | Yes |
| Storage System I/O Performance By Kubernetes Node | Yes |
| CSI Driver Provisioned Volume I/O Performance | Yes |
| CSI Driver Provisioned Volume Topology | Yes |

## Supported Platforms

The following matrix provides a list of all supported versions for each Dell EMC Storage product.

| Platforms | PowerFlex |
| -------- | --------- |
| Storage Array | v3.0, v3.5 |
| Kubernetes | 1.18, 1.19, 1.20 |
| Openshift | 4.5, 4.6 |

## Releases and Supported CSI Drivers

The table below lists the Karavi Observability release versions.  Shown for each release version are the associated service versions, Helm chart version, and supported CSI drivers/versions.  The Helm chart version can be used to select the appropriate Helm chart version you wish to install depending on the Karavi Observability release.

| Karavi Observability | Karavi Metrics PowerFlex | Karavi Topology | Helm Chart | Supported CSI Drivers |
| - | - | - | - | - |
| 0.3.0 | 0.3.0 | 0.3.0 | 0.3.0 | [csi-powerflex](https://github.com/dell/csi-powerflex) [1.4.0] |
| 0.2.1-pre-release | 0.2.0-pre-release | 0.2.0-pre-release | 0.2.1 | [csi-powerflex](https://github.com/dell/csi-powerflex) [1.2.0, 1.2.1, 1.3.0] |
| 0.2.0-pre-release | 0.2.0-pre-release | 0.2.0-pre-release | 0.2.0 | [csi-powerflex](https://github.com/dell/csi-powerflex) [1.2.0, 1.2.1, 1.3.0] |
| 0.1.0-pre-release | 0.1.0-pre-release | 0.1.0-pre-release | 0.1.0 | [csi-powerflex](https://github.com/dell/csi-powerflex) [1.2.0, 1.2.1, 1.3.0] |

## TLS Encryption

The Karavi Observability helm deployment relies on [cert-manager](https://github.com/jetstack/cert-manager) to manage SSL certificates that are used to encrypt communication between various components. When installing using the karavi-observability helm chart, cert-manager is installed and configured automatically.
The cert-manager components listed below will be installed alongside karavi-observability.

| Component |
| --------- |
| cert-manager |
| cert-manager-cainjector |
| cert-manager-webhook |

If desired you may provide your own certificate key pair to be used inside the cluster by providing the path to the certificate and key in the helm chart config. If you do not provide a certificate, one will be generated for you on install.
__NOTE__: The certificate provided must be a CA certificate. This is to facilitate automated certificate rotation for karavi-observability services.

## Deploying Karavi Observability

This project is deployed using Helm. The supported version of Helm is listed below.

| Component       | Version   | Additional Information |
| --------------- | --------- | ---------------------- |
| Helm            | v.3.3.0   | [Helm installation](https://helm.sh/docs/intro/install/) |

## Installing the Chart

There are several options for installing the Karavi Observability Helm chart including online and offline installer scripts and manual steps for installing the Helm chart.

### Online Installation

In situations where an online installation of Karavi Observability is required, please visit [Online Karavi Observability Helm Chart Installer](../installer/README.md#online-karavi-observability-helm-chart-installer) for more details.

### Offline Installation

In situations where an offline installation of Karavi Observability is required, please visit [Offline Karavi Observability Helm Chart Installer](../installer/README.md#offline-karavi-observability-helm-chart-installer) for more details.

### Manual Installation

Before installing the karavi-observability chart, you must first install the cert-manager CustomResourceDefinition resources with the command below.

```console
$ kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.crds.yaml
```

Copy the vxflexos-config Secret from the CSI Driver for Dell EMC PowerFlex namespace into the namespace where Karavi Observability is deployed.
Note: The target namespace must exist before executing this command.

*Example command to copy the Secret from the vxflexos namespace to the karavi namespace.*

```console
$ kubectl get secret vxflexos-config -n vxflexos -o yaml | sed 's/namespace: vxflexos/namespace: karavi/' | kubectl create -f -
```

The command below deploys Karavi Observability on the Kubernetes cluster in the default configuration. The [configuration](#Configuration) section below lists all the parameters that can be configured during installation.

```console
$ helm repo add dell https://dell.github.io/helm-charts
$ helm install --version <helm chart version> karavi-observability dell/karavi-observability -n karavi --create-namespace
```
**Note**: The `<helm chart version>` argument should align with one of the [Helm chart versions](#Releases-and-supported-CSI-Drivers) listed above.  If the `--version` argument is omitted, the latest released Helm chart version will be deployed.

## Updating Storage System Credentials

If the storage system credentials have changed and been updated in the relevant CSI Driver, Karavi Observability can be updated with new credentials as follows:

### PowerFlex

#### If using Karavi Observability with Karavi Authorization

##### Update Karavi Authorization Token
1. Delete the current `proxy-authz-tokens` Secret from the Karavi Observability namespace.
2. Copy the `proxy-authz-tokens` Secret from the CSI Driver for Dell EMC PowerFlex namespace to the Karavi Observability namespace.

*Example command to copy the Secret from the vxflexos namespace to the karavi namespace:*

```console
$ kubectl delete secret proxy-authz-tokens -n karavi
$ kubectl get secret proxy-authz-tokens -n vxflexos -o yaml | sed 's/namespace: vxflexos/namespace: karavi/' | kubectl create -f -
```

##### Update Storage Systems
If the list of storage systems managed by the CSI Driver for Dell EMC PowerFlex has changed, the following steps can be performed to update Karavi Observability to reference the updated systems:

1. Delete the current `karavi-authorization-config` Secret from the Karavi Observability namespace.
2. Copy the `karavi-authorization-config` Secret from the CSI Driver for Dell EMC PowerFlex namespace to the Karavi Observability namespace.

*Example command to copy the Secret from the vxflexos namespace to the karavi namespace:*

```console
$ kubectl delete secret karavi-authorization-config -n karavi
$ kubectl get secret karavi-authorization-config -n vxflexos -o yaml | sed 's/namespace: vxflexos/namespace: karavi/' | kubectl create -f -
```

#### If not using Karavi Observability with Karavi Authorization

1. Delete the current `vxflexos-config` Secret from the Karavi Observability namespace.
2. Copy the `vxflexos-config` Secret from the CSI Driver for Dell EMC PowerFlex namespace to the Karavi Observability namespace.

*Example command to copy the Secret from the vxflexos namespace to the karavi namespace:*

```console
$ kubectl delete secret vxflexos-config -n karavi
$ kubectl get secret vxflexos-config -n vxflexos -o yaml | sed 's/namespace: vxflexos/namespace: karavi/' | kubectl create -f -
```

## Viewing Logs

Logs can be viewed by using the `kubectl logs` CLI command to output logs for a specific Pod or Deployment.

For example, the following script will capture logs of all Pods in the `karavi` namespace and save the output to one file per Pod.

```
#!/bin/bash

namespace=karavi
for pod in $(kubectl get pods -n $namespace -o name); do
  logFileName=$(echo $pod | tr / -).txt
  kubectl logs -n $namespace $pod --all-containers > $logFileName
done
```

## Uninstalling the Chart

The command below removes all the Kubernetes components associated with the chart.

```console
$ helm delete karavi-observability --namespace karavi
```
You may also want to uninstall the CRDs created for cert-manager.

```console
$ kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.crds.yaml
```

## Configuration

| Parameter                                 | Description                                   | Default                                                 |
|-------------------------------------------|-----------------------------------------------|---------------------------------------------------------|
| `karaviTopology.image`                   | Location of the karavi-topology Docker image                                                                                                        | `dellemc/csm-topology:v0.3.0`|
| `karaviTopology.enabled`       | Enable Karavi Topology service    | `true`                                                   |
| `karaviTopology.provisionerNames`       | Provisioner Names used to filter the Persistent Volumes created on the Kubernetes cluster (must be a comma-separated list)    | ` csi-vxflexos.dellemc.com`                                                   |
| `karaviTopology.service.type`            | Kubernetes service type	    | `ClusterIP`                                                   |
| `karaviTopology.certificateFile`      | Optional valid CA public certificate file that will be used to deploy the Topology service. Must use domain name 'karavi-topology'.            | ` `                                                   |
| `karaviTopology.privateKeyFile`      | Optional public certificate's associated private key file that will be used to deploy the Topology service. Must use domain name 'karavi-topology'.            | ` `|
| `karaviTopology.logLevel`      | *As of Release 0.4.0:* Output logs that are at or above the given log level severity (Valid values: TRACE, DEBUG, INFO, WARN, ERROR, FATAL, PANIC)           | `INFO`|
| `karaviTopology.logFormat`      | *As of Release 0.4.0:* Output logs in the specified format (Valid values: text, json)            | `text`|
| `otelCollector.certificateFile`      | Optional valid CA public certificate file that will be used to deploy the OpenTelemetry Collector. Must use domain name 'otel-collector'.            | ` `                                                   |
| `otelCollector.privateKeyFile`      | Optional public certificate's associated private key file that will be used to deploy the OpenTelemetry Collector. Must use domain name 'otel-collector'.            | ` `|                                                   
| `otelCollector.service.type`            | Kubernetes service type	    | `ClusterIP`                                                   |
| `karaviMetricsPowerflex.image`                          |  Karavi Metrics for PowerFlex Service image                      | `dellemc/csm-metrics-powerflex:v0.3.0`|
| `karaviMetricsPowerflex.enabled`                          |  Enable Karavi Metrics for PowerFlex service                      | `true`|
| `karaviMetricsPowerflex.collectorAddr`                         | Metrics Collector accessible from the Kubernetes cluster                    | `otel-collector:55680`  |
| `karaviMetricsPowerflex.provisionerNames`                       | Provisioner Names used to filter for determining PowerFlex SDC nodes( Must be a Comma-separated list)          | ` csi-vxflexos.dellemc.com`                                                   |
| `karaviMetricsPowerflex.sdcPollFrequencySeconds`                        | The polling frequency (in seconds) to gather SDC metrics                         | `10`                                       |
| `karaviMetricsPowerflex.volumePollFrequencySeconds`                        | The polling frequency (in seconds) to gather volume metrics | `10`                         |
| `karaviMetricsPowerflex.storageClassPoolPollFrequencySeconds`                        | The polling frequency (in seconds) to gather storage class/pool metrics                         |  `10`                                       |
| `karaviMetricsPowerflex.concurrentPowerflexQueries`                        | The number of simultaneous metrics queries to make to Powerflex(MUST be less than 10; otherwise, several request errors from Powerflex will ensue.)                       |  `10`                                       |
| `karaviMetricsPowerflex.sdcMetricsEnabled`                        | Enable PowerFlex SDC Metrics Collection                         | `true`                                       |
| `karaviMetricsPowerflex.volumeMetricsEnabled`                        | Enable PowerFlex Volume Metrics Collection                         | `true`                                       |
| `karaviMetricsPowerflex.storageClassPoolMetricsEnabled`                        | Enable PowerFlex  Storage Class/Pool Metrics Collection                         | `true`                                       |
| `karaviMetricsPowerflex.endpoint`                        | Endpoint for pod leader election                       | `karavi-metrics-powerflex`                                       |
| `karaviMetricsPowerflex.service.type`            | Kubernetes service type	    | `ClusterIP`                                                   |
| `karaviMetricsPowerflex.logLevel`      | *As of Release 0.4.0:* Output logs that are at or above the given log level severity (Valid values: TRACE, DEBUG, INFO, WARN, ERROR, FATAL, PANIC)           | `INFO`|
| `karaviMetricsPowerflex.logFormat`      | *As of Release 0.4.0:* Output logs in the specified format (Valid values: text, json)            | `text`|
| `karaviMetricsPowerstore.image`                          |  *As of Release 0.4.0:* Karavi Metrics for PowerStore Service image                      | `dellemc/csm-metrics-powerstore:v0.1.0`|
| `karaviMetricsPowerstore.enabled`                          |  *As of Release 0.4.0:* Enable Karavi Metrics for PowerStore service                      | `true`|
| `karaviMetricsPowerstore.collectorAddr`                         | *As of Release 0.4.0:* Metrics Collector accessible from the Kubernetes cluster                    | `otel-collector:55680`  |
| `karaviMetricsPowerstore.provisionerNames`                       | *As of Release 0.4.0:* Provisioner Names used to filter for determining PowerStore volumes (must be a Comma-separated list)          | ` csi-powerstore.dellemc.com`                                                   |
| `karaviMetricsPowerstore.volumePollFrequencySeconds`                        | *As of Release 0.4.0:* The polling frequency (in seconds) to gather volume metrics | `10`                         |
| `karaviMetricsPowerstore.concurrentPowerflexQueries`                        | *As of Release 0.4.0:* The number of simultaneous metrics queries to make to PowerStore (must be less than 10; otherwise, several request errors from PowerStore will ensue.)                       |  `10`                                       |
| `karaviMetricsPowerstore.volumeMetricsEnabled`                        | *As of Release 0.4.0:* Enable PowerStore Volume Metrics Collection                         | `true`                                       |
| `karaviMetricsPowerstore.endpoint`                        | *As of Release 0.4.0:* Endpoint for pod leader election                       | `karavi-metrics-powerstore`                                       |
| `karaviMetricsPowerstore.service.type`            | *As of Release 0.4.0:* Kubernetes service type	    | `ClusterIP`                                                   |
| `karaviMetricsPowerstore.logLevel`      | *As of Release 0.4.0:* Output logs that are at or above the given log level severity (Valid values: TRACE, DEBUG, INFO, WARN, ERROR, FATAL, PANIC)           | `INFO`|
| `karaviMetricsPowerstore.logFormat`      | *As of Release 0.4.0:* Output logs in the specified format (Valid values: text, json)            | `text`|

Specify each parameter using the '--set key=value[,key=value]' and/or '--set-file key=value[,key=value] arguments to 'helm install'. For example:

```console
$ helm install karavi-observability dell/karavi-observability -n karavi --create-namespace \
    --set-file karaviTopology.certificateFile=<location-of-karavi-topology-certificate-file> \
    --set-file karaviTopology.privateKeyFile=<location-of-karavi-topology-private-key-file> \
    --set-file otelCollector.certificateFile=<location-of-otel-collector-certificate-file> \
    --set-file otelCollector.privateKeyFile=<location-of-otel-collector-private-key-file>
```

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example:

```console
$ helm install karavi-observability dell/karavi-observability -n karavi --create-namespace -f values.yaml
 ```

 A sample values.yaml file is located [here](https://github.com/dell/helm-charts/blob/main/charts/karavi-observability/values.yaml).

**PowerFlex System Details**
- Karavi Observability will use the same vxflexos-config Secret that is used by release 1.4 of the CSI Driver for Dell EMC PowerFlex. If a 'default' storage system is specified, metrics will only be gathered for that system. If no 'default' storage system is specified, the first system in the configuration will be used.

**PowerStore System Details**
- Karavi Observability will use the same powerstore-config Secret that is used by release 1.3 of the CSI Driver for Dell EMC PowerStore. Metrics will be gathered for all storage systems specified in the Secret.

**Configuration Settings**
- Some parameters can be configured during runtime without restarting the Karavi Observability services. These parameters will be stored in ConfigMaps that can be updated on the Kubernetes cluster. This will automatically change the settings on the services.

Karavi-metrics-powerflex parameters that can be updated:

* COLLECTOR_ADDR
* PROVISIONER_NAMES
* POWERFLEX_SDC_METRICS_ENABLED
* POWERFLEX_SDC_IO_POLL_FREQUENCY
* POWERFLEX_VOLUME_IO_POLL_FREQUENCY
* POWERFLEX_VOLUME_METRICS_ENABLED
* POWERFLEX_STORAGE_POOL_METRICS_ENABLED
* POWERFLEX_STORAGE_POOL_POLL_FREQUENCY
* POWERFLEX_MAX_CONCURRENT_QUERIES
>As of Release 0.4.0:
>* LOG_LEVEL
>* LOG_FORMAT

To update the karavi-metrics-powerflex settings during runtime, run the below command on the Kubernetes cluster and save the updated configmap data.

```console
kubectl edit configmap karavi-metrics-powerflex-configmap -n karavi
```

>As of Release 0.4.0:
>Karavi-metrics-powerstore parameters that can be updated:
>
>* COLLECTOR_ADDR
>* PROVISIONER_NAMES
>* POWERSTORE_VOLUME_IO_POLL_FREQUENCY
>* POWERSTORE_VOLUME_METRICS_ENABLED
>* POWERSTORE_MAX_CONCURRENT_QUERIES
>* LOG_LEVEL
>* LOG_FORMAT
>
> To update the karavi-metrics-powerstore settings during runtime, run the below command on the Kubernetes cluster and save the updated configmap data.
>
>```console
>kubectl edit configmap karavi-metrics-powerstore-configmap -n karavi
>```

Karavi-topology parameters that can be updated:

* PROVISIONER_NAMES
>As of Release 0.4.0:
>* LOG_LEVEL
>* LOG_FORMAT

To update the karavi-topology settings during runtime, run the below command on the Kubernetes cluster and save the updated configmap data.

```console
kubectl edit configmap karavi-topology-configmap -n karavi
```

## Required Components

The following third party components are required to be deployed in the same Kubernetes cluster as the karavi-metrics-powerflex service:

* Prometheus
* Grafana

It is the user's responsibility to deploy these components in the same Kubernetes cluster as the metrics service.  These components must be deployed according to the specifications defined below.

**Note**: Karavi Observability must be deployed first.  Once Karavi Observability has been deployed, you can proceed to deploying/configuring the required components.

### Prometheus

The Prometheus service should be running on the same Kubernetes cluster as the Karavi Observability services. As part of the Karavi Observability deployment, the OpenTelemetry Collector gets deployed.  The OpenTelemetry Collector is what the Karavi metrics services use to push metrics to that can be consumed by Prometheus.  This means that Prometheus must be configured to scrape the metrics data from the OpenTelemetry Collector.

| Supported Version | Image                   | Helm Chart                                                   |
| ----------------- | ----------------------- | ------------------------------------------------------------ |
| 2.22.0           | prom/prometheus:v2.22.0 | [Prometheus Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus) |

**Note**: It is the user's responsibility to provide persistent storage for Prometheus if they want to preserve historical data.

Here is a sample minimal configuration for Prometheus. Please note that the configuration below uses insecure skip verify. If you wish to properly configure TLS, you will need to provide a ca_file in the Prometheus configuration. The certificate provided as part of Karavi Observability deployment should be signed by this same CA. For more information about Prometheus configuration, see [Prometheus configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#configuration).

#### Sample Prometheus Deployment

While there are several ways to install Prometheus with Helm, below are simple steps to deploy [prometheus-community/prometheus](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus):
<details>
   <summary>Create values file</summary>

Create a values file named `prometheus-values.yaml`. The file should look like:

```yaml
# prometheus-values.yaml
alertmanager:
  enabled: false
nodeExporter:
  enabled: false
pushgateway:
  enabled: false
kubeStateMetrics:
  enabled: false
configmapReload:
  prometheus:
    enabled: false
server:
  enabled: true
  image:
    repository: quay.io/prometheus/prometheus
    tag: v2.22.0
    pullPolicy: IfNotPresent
  persistentVolume:
    enabled: false
  service:
    type: NodePort
    servicePort: 9090
serverFiles:
  prometheus.yml:
    scrape_configs:
      - job_name: 'karavi-metrics-powerflex'
        scrape_interval: 5s
        scheme: https
        static_configs:
          - targets: ['otel-collector:8443']
        tls_config:
          insecure_skip_verify: true
```

</details>
<details>
   <summary>Get Prometheus repository information</summary>

On your terminal, run each of the commands below:

```terminal
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

</details>
<details>
   <summary>Helm install</summary>

On your terminal, run the command below:

```terminal
helm install prometheus prometheus-community/prometheus -n karavi --create-namespace -f prometheus-values.yaml
```

</details>

### Grafana

The Grafana dashboards require Grafana to be deployed in the same Kubernetes cluster as the Karavi Observability services.  Below are the configuration details required to properly setup Grafana to work with Karavi Observability.

| Supported Version | Helm Chart                                                |
| ----------------- | --------------------------------------------------------- |
| 7.3.0-7.3.2       | [Grafana Helm chart](https://github.com/grafana/helm-charts/tree/main/charts/grafana) |

Grafana must be configured with the following data sources/plugins:

| Name                   | Additional Information                                                     |
| ---------------------- | -------------------------------------------------------------------------- |
| Prometheus data source | [Prometheus data source](https://grafana.com/docs/grafana/latest/features/datasources/prometheus/)   |
| Data Table plugin      | [Data Table plugin](https://grafana.com/grafana/plugins/briangann-datatable-panel) |
| Pie Chart plugin       | [Pie Chart plugin](https://grafana.com/grafana/plugins/grafana-piechart-panel)                 |
| SimpleJson data source | [SimpleJson data source](https://grafana.com/grafana/plugins/grafana-simple-json-datasource)                 |

Settings for the Grafana Prometheus data source:

| Setting | Value                     | Additional Information                          |
| ------- | ------------------------- | ----------------------------------------------- |
| Name    | Prometheus                |                                                 |
| Type    | prometheus                |                                                 |
| URL     | http://PROMETHEUS_IP:PORT | The IP/PORT of your running Prometheus instance |
| Access  | Proxy                     |                                                 |

Settings for the Grafana SimpleJson data source:

| Setting             | Value                             |
| ------------------- | --------------------------------- |
| Name                | Karavi-Topology |
| URL                 | Access Karavi Topology at https://karavi-topology.*namespace*.svc.cluster.local:8443 |
| Skip TLS Verify     | Enabled (If not using CA certificate) |
| With CA Cert        | Enabled (If using CA certificate) |


#### Sample Grafana Deployment

If a new Grafana instance is needed, one way to deploy it into your system is summarized below:

<details>
   <summary>Create ConfigMap</summary>

When using a network that requires decryption certificate, Grafana server MUST be configure with the necessary certificate. To do this, follow the steps below, otherwise skip to `Create Value file`

* Create a Config file named `grafana-configmap.yaml` The file should look like:

```yaml
# grafana-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: certs-configmap
  namespace: karavi
  labels:
    certs-configmap: "1"
data:
  ca-certificates.crt: |-
    -----BEGIN CERTIFICATE-----
   ReplaceMeWithActualCaCERT=
    -----END CERTIFICATE-----
```

NOTE: you need an actual CA Cert for it to work

* On your terminal, run the commands below:

```terminal
kubectl create -f grafana-configmap.yaml
```

</details>
<details>
   <summary>Create values file</summary>

Create a value file named `grafana-values.yaml`. The file should look like:

```yaml
# grafana-values.yaml 
image:
  repository: grafana/grafana
  tag: 7.3.0
  sha: ""
  pullPolicy: IfNotPresent
service:
  type: NodePort

## Administrator credentials when not using an existing Secret
adminUser: admin
adminPassword: admin

## Pass the plugins you want installed as a list.
##
plugins:
  - grafana-simple-json-datasource
  - briangann-datatable-panel
  - grafana-piechart-panel

## Configure grafana datasources
## ref: http://docs.grafana.org/administration/provisioning/#datasources
##
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Karavi-Topology
      type: grafana-simple-json-datasource
      access: proxy
      url: 'https://karavi-topology:8443'
      isDefault: null
      version: 1
      editable: true
      jsonData:
        tlsSkipVerify: true
    - name: Prometheus
      type: prometheus
      access: proxy
      url: 'http://prometheus:9090'
      isDefault: null
      version: 1
      editable: true
testFramework:
  enabled: false
sidecar:
  datasources:
    enabled: true
  dashboards:
    enabled: true

## Additional grafana server CofigMap mounts
## Defines additional mounts with CofigMap. CofigMap must be manually created in the namespace.
extraConfigmapMounts: [] # If you created a ConfigMap on the previous step, delete [] and uncomment the lines below 
# - name: certs-configmap
#   mountPath: /etc/ssl/certs/ca-certificates.crt
#   subPath: ca-certificates.crt
#   configMap: certs-configmap
#   readOnly: true
```

</details>
<details>
   <summary>Get Grafana repository information</summary>

On your terminal, run each of the commands below:

```terminal
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

</details>
<details>
   <summary>Helm install</summary>

On your terminal, run the commands below:

```terminal
helm install grafana grafana/grafana -n karavi -f grafana-values.yaml
```

</details>


#### Importing the Karavi Observability Dashboards

Once Grafana is properly configured, you can import the pre-built observability dashboards. Log into Grafana and click the + icon in the side menu. Then click Import. From here you can upload the JSON files or paste the JSON text directly into the text area.  Below are the locations of the dashboards that can be imported:

| Dashboard           | Description |
| ------------------- | --------------------------------- |
| [Storage System I/O Performance By Kubernetes Node](https://github.com/dell/karavi-observability/blob/main/grafana/dashboards/powerflex/sdc_io_metrics.json) | Provides visibility into the I/O performance metrics (IOPS, bandwidth, latency) by Kubernetes node |
| [CSI Driver Provisioned Volume I/O Performance](https://github.com/dell/karavi-observability/blob/main/grafana/dashboards/powerflex/volume_io_metrics.json) | Provides visibility into the I/O performance metrics (IOPS, bandwidth, latency) by volume |
| [Storage Pool Consumption By CSI Driver](https://github.com/dell/karavi-observability/blob/main/grafana/dashboards/powerflex/storage_consumption.json) | Provides visibility into the total, used, and available capacity for a storage class and associated underlying storage construct. |
| [CSI Driver Provisioned Volume Topology](https://github.com/dell/karavi-observability/blob/main/grafana/dashboards/topology/topology.json) | Provides visibility into Dell EMC CSI (Container Storage Interface) driver provisioned volume characteristics in Kubernetes correlated with volumes on the storage system. |
