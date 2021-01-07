<!--
Copyright (c) 2020 Dell Inc., or its subsidiaries. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
-->

# Getting Started Guide

This project provides Kubernetes administrators insight into CSI (Container Storage Interface) Driver persistent storage topology, usage and performance. Metrics data is collected and pushed to the [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector), so it can be processed, and exported in a format consumable by Prometheus. Topology data related to containerized volumes that are provisioned by a CSI (Container Storage Interface) Driver is also captured. The metrics and topology data are visualized through Grafana dashboards.

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
| Kubernetes | 1.17, 1,18, 1.19 |
| Openshift | 4.5, 4.6 |

## CSI Drivers

Karavi Observability supports the following CSI drivers and versions.

| Storage Array | CSI Driver | Supported Versions |
| ------------- | ---------- | ------------------ |
| PowerFlex | [csi-powerflex](https://github.com/dell/csi-powerflex) | v1.1.5, 1.2.0, 1.2.1 |

## Deploying Karavi Observability

This project is deployed using Helm. The supported version of Helm is listed below.

| Component       | Version   | Additional Information |
| --------------- | --------- | ---------------------- |
| Helm            | v.3.3.0   | [Helm installation](https://helm.sh/docs/intro/install/) |

## Installing the Chart

```console
$ helm repo add dell https://dell.github.io/helm-charts
$ helm install karavi-observability dell/karavi-observability -n karavi --create-namespace
```

The command deploys Karavi Observability on the Kubernetes cluster in the default configuration. The [configuration](##Configuration) section below lists all the parameters that can be configured during installation.

## Uninstalling the Chart

```console
$ helm delete karavi-observability --namespace karavi
```

The command removes all the Kubernetes components associated with the chart.

### Configuration

| Parameter                                 | Description                                   | Default                                                 |
|-------------------------------------------|-----------------------------------------------|---------------------------------------------------------|
| `karaviTopology.image`                   | Location of the karavi-topology Docker image                                                                                                        | `dellemc/karavi-topology:0.1.0-pre-release`|
| `karaviTopology.provisionerNames`       | Provisioner Names used to filter the Persistent Volumes created on the Kubernetes cluster (must be a comma-separated list)    | ` csi-vxflexos.dellemc.com`                                                   |
| `karaviTopology.service.type`            | Kubernetes service type	    | `ClusterIP`                                                   |
| `karaviTopology.certificateFile`      | Required valid public certificate file that will be used to deploy the Topology service. Must use domain name 'karavi-topology'.            | ` `                                                   |
| `karaviTopology.privateKeyFile`      | Required public certificate's associated private key file that will be used to deploy the Topology service. Must use domain name 'karavi-topology'.            | ` `|
| `otelCollector.certificateFile`      | Required valid public certificate file that will be used to deploy the OpenTelemetry Collector. Must use domain name 'otel-collector'.            | ` `                                                   |
| `otelCollector.privateKeyFile`      | Required public certificate's associated private key file that will be used to deploy the OpenTelemetry Collector. Must use domain name 'otel-collector'.            | ` `|                                                   
| `karaviMetricsPowerflex.powerflexEndpoint`      | PowerFlex Gateway URL            | ` `                                                   |
| `karaviMetricsPowerflex.powerflexUser`                      | PowerFlex Gateway administrator username(in base64)                           | ` `                           |
| `karaviMetricsPowerflex.powerflexPassword`                           | PowerFlex Gateway administrator password(in base64)                      | ` ` |
| `karaviMetricsPowerflex.image`                          |  Karavi Metrics for PowerFlex Service image                      | `dellemc/karavi-metrics-powerflex:0.1.0-pre-release`|
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

Specify each parameter using the '--set key=value[,key=value]' and/or '--set-file key=value[,key=value] arguments to 'helm install'. For example:

```console
$ helm install karavi-observability dell/karavi-observability -n karavi --create-namespace \
    --set-file karaviTopology.certificateFile=<location-of-karavi-topology-certificate-file> \
    --set-file karaviTopology.privateKeyFile=<location-of-karavi-topology-private-key-file> \
    --set-file otelCollector.certificateFile=<location-of-otel-collector-certificate-file> \
    --set-file otelCollector.privateKeyFile=<location-of-otel-collector-private-key-file> \
    --set karaviMetricsPowerflex.powerflexPassword=<base64-encoded-password> \
    --set karaviMetricsPowerflex.powerflexUser=<base64-encoded-username> \
    --set karaviMetricsPowerflex.powerflexEndpoint=https://<powerflex-endpoint>
```

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example:

```console
$ helm install karavi-observability dell/karavi-observability -n karavi --create-namespace -f values.yaml
 ```

 A sample values.yaml file is located [here](https://github.com/dell/helm-charts/blob/main/charts/karavi-observability/values.yaml).

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
          - targets: ['otel-collector:443']
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
| Data Table plugin      | [Data Table plugin](https://grafana.com/grafana/plugins/briangann-datatable-panel/installation) |
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
| URL                 | Access Karavi Topology at https://karavi-topology.*namespace*.svc.cluster.local |
| Skip TLS Verify     | Enabled (If not using CA certificate) |
| With CA Cert        | Enabled (If using CA certificate) |


#### Sample Grafana Deployment

If a new Grafana instance is needed, one way to deploy it into your system is summarized below:

<details>
   <summary>Create ConfigMap</summary>

Create a Config file named `grafana-configmap.yaml` The file should look like:

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
</details>
<details>
   <summary>Create Value file</summary>

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
# Administrator credentials when not using an existing secret (see below)
adminUser: admin
adminPassword: admin
plugins:
  - grafana-simple-json-datasource
  - briangann-datatable-panel
  - grafana-piechart-panel
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Karavi-Topology
      type: grafana-simple-json-datasource
      access: proxy
      url: 'https://karavi-topology.karavi.svc.cluster.local/'
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
extraConfigmapMounts:
  - name: certs-configmap
    mountPath: /etc/ssl/certs/ca-certificates.crt
    subPath: ca-certificates.crt
    configMap: certs-configmap
    readOnly: true
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
kubectl create -f grafana-configmap.yaml
helm install grafana grafana/grafana -n karavi -f grafana-values.yaml
```

</details>


#### Importing the Karavi Observability Dashboards

Once Grafana is properly configured, you can import the pre-built observability dashboards. Log into Grafana and click the + icon in the side menu. Then click Import. From here you can upload the JSON files or paste the JSON text directly into the text area.  Below are the locations of the dashboards that can be imported:

| Dashboard           | Description |
| ------------------- | --------------------------------- |
| [Storage System I/O Performance By Kubernetes Node](https://github.com/dell/karavi-metrics-powerflex/blob/main/grafana/dashboards/powerflex/sdc_io_metrics.json) | Provides visibility into the I/O performance metrics (IOPS, bandwidth, latency) by Kubernetes node |
| [CSI Driver Provisioned Volume I/O Performance](https://github.com/dell/karavi-metrics-powerflex/blob/main/grafana/dashboards/powerflex/volume_io_metrics.json) | Provides visibility into the I/O performance metrics (IOPS, bandwidth, latency) by volume |
| [Storage Pool Consumption By CSI Driver](https://github.com/dell/karavi-metrics-powerflex/blob/main/grafana/dashboards/powerflex/storage_consumption.json) | Provides visibility into the total, used, and available capacity for a storage class and associated underlying storage construct. |
| [CSI Driver Provisioned Volume Topology](https://github.com/dell/karavi-topology/blob/main/grafana/dashboards/topology.json) | Provides visibility into Dell EMC CSI (Container Storage Interface) driver provisioned volume characteristics in Kubernetes correlated with volumes on the storage system. |
