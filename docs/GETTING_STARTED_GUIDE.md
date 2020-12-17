<!--
Copyright (c) 2020 Dell Inc., or its subsidiaries. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
-->

# Getting Started Guide

This project captures telemetry data about storage usage and performance and pushes it to the [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector), so it can be processed, and exported in a format consumable by Prometheus.  Prometheus can then be configured to scrape the OpenTelemetry Collector exporter endpoint to provide metrics so they can be visualized in Grafana.  

This document steps through the deployment and configuration of this application using Helm.

## Kubernetes

First and foremost, the services require a Kubernetes cluster that aligns with the supported versions listed below.

| Version   |
| --------- |
| 1.17-1.19 |

## Openshift

For Openshift, the services requires the cluster to align with these supported versions.

| Version |
| ------- |
| 4.5,4.6 |

## Supported Dell EMC Products

The topology service currently supports the following versions of Dell EMC storage systems.

| Dell EMC Storage Product      |
| ----------------------------- |
| Dell EMC PowerFlex v3.0, v3.5 |

## CSI Driver for Dell EMC PowerFlex

This project captures telemetry data about Kubernetes storage usage and performance as it relates the CSI (Container Storage Interface) Driver for Dell EMC PowerFlex. The metrics service requires that the CSI Driver for Dell EMC PowerFlex is deployed in the Kubernetes cluster.

| CSI Driver |
| ---------- |
| [CSI Driver for Dell EMC PowerFlex v1.1.5, 1.2.0, 1.2.1](https://github.com/dell/csi-vxflexos) |

## Deploying Karavi Observability

This project is deployed using Helm. To install the helm chart:

```console
$ helm repo add dell https://dell.github.io/helm-charts
$ helm install karavi-observability dell/karavi-observability -n karavi --create-namespace \
    --set-file karaviTopology.certificateFile=<location-of-karavi-topology-certificate-file> \
    --set-file karaviTopology.privateKeyFile=<location-of-karavi-topology-private-key-file> \
    --set-file otelCollector.certificateFile=<location-of-otel-collector-certificate-file> \
    --set-file otelCollector.privateKeyFile=<location-of-otel-collector-private-key-file> \
    --set karaviMetricsPowerflex.powerflexPassword=<base64-encoded-password> \
    --set karaviMetricsPowerflex.powerflexUser=<base64-encoded-username> \
    --set karaviMetricsPowerflex.powerflexEndpoint=https://<powerflex-endpoint>
```

If you built the Docker image and pushed it to a local registry, you can deploy it using the same Helm chart above.  You simply need to override the helm chart value pointing to where the image lives. The table below shows all the configuration options for the installation.

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

## Required Components

The following third party components are required to be deployed in the same Kubernetes cluster as the karavi-metrics-powerflex service:

* Prometheus
* Grafana

It is the user's responsibility to deploy these components in the same Kubernetes cluster as the metrics service.  These components must be deployed according to the specifications defined below.

**Note**: Karavi Observability must be deployed first.  Once Karavi Observability has been deployed, you can proceed to deploying/configuring the required components.

### Prometheus

The Prometheus service should be running on the same Kubernetes cluster as the Karavi metrics services. As part of the Karavi Observability deployment, the OpenTelemetry Collector gets deployed.  The OpenTelemetry Collector is what the Karavi metrics services use to push metrics to that can be consumed by Prometheus.  This means that Prometheus must be configured to scrape the metrics data from the OpenTelemetry Collector.

| Supported Version | Image                   | Helm Chart                                                   |
| ----------------- | ----------------------- | ------------------------------------------------------------ |
| 2.22.0           | prom/prometheus:v2.22.0 | [Prometheus Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus) |

**Note**: It is the user's responsibility to provide persistent storage for Prometheus if they want to preserve historical data.

Here is a sample minimal configuration for Prometheus. Please note that the configuration below uses insecure skip verify. If you wish to properly configure TLS, you will need to provide a ca_file in the Prometheus configuration. The certificate provided as part of Karavi Observability deployment should be signed by this same CA. For more information about Prometheus configuration, see [Prometheus configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#configuration).

```yaml
scrape_configs:
    - job_name: 'karavi-metrics-powerflex'
      scrape_interval: 5s
      scheme: https
      static_configs:
        - targets: ['otel-collector:8443']
      tls_config:
        insecure_skip_verify: true
```

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

#### Importing the Karavi Observability Dashboards

Once Grafana is properly configured, you can import the pre-built observability dashboards. Log into Grafana and click the + icon in the side menu. Then click Import. From here you can upload the JSON files or paste the JSON text directly into the text area.  Below are the locations of the dashboards that can be imported:

| Dashboard           | Description |
| ------------------- | --------------------------------- |
| [I/O Performance by node dashboard](https://github.com/dell/karavi-metrics-powerflex/blob/main/grafana/dashboards/powerflex/sdc_io_metrics.json) | Provides visibility into the I/O performance metrics (IOPS, bandwidth, latency) by Kubernetes node |
| [I/O Performance by volume dashboard](https://github.com/dell/karavi-metrics-powerflex/blob/main/grafana/dashboards/powerflex/volume_io_metrics.json) | Provides visibility into the I/O performance metrics (IOPS, bandwidth, latency) by volume |
| [Storage consumption dashboard](https://github.com/dell/karavi-metrics-powerflex/blob/main/grafana/dashboards/powerflex/storage_consumption.json) | Provides visibility into the total, used, and available capacity for a storage class and associated underlying storage construct. |
| [Topology dashboard](https://github.com/dell/karavi-topology/blob/main/grafana/dashboards/topology.json) | Provides visibility into Dell EMC CSI (Container Storage Interface) driver provisioned volume characteristics in Kubernetes correlated with volumes on the storage system. |

### OpenTelemetry Collector

The OpenTelemetry Collector is deployed and configured as part of this project's deployment.  It is configured to require all communication happen using TLS.  The deployment options listed below will require a signed certificate file and a signed certificate private key file.

The metrics service requires the OpenTelemetry Collector so that metrics can be pushed and later consumed by a backend. The [Karavi Observability Helm chart](https://github.com/dell/helm-charts/tree/main/charts/karavi-observability) takes care of deploying the OpenTelemetry Collector and securing communication between the metrics service and the OpenTelemetry Collector using TLS 1.2 via the user-provided certificate and key files.

**Note**: Although the OpenTelemetry Collector can provide metrics for different backends, we currently only support Prometheus.

The OpenTelemetry Collector endpoint is to be scraped by Prometheus, which must be running within the same Kubernetes cluster.                   |                                                 |

## Building the Services

If you wish to clone and build any of the the Karavi Observability services, a Linux host is required with the following installed:

| Component       | Version   | Additional Information                                                                                                                     |
| --------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Docker          | v19+      | [Docker installation](https://docs.docker.com/engine/install/)                                                                                                    |
| Docker Registry |           | Access to a local/corporate [Docker registry](https://docs.docker.com/registry/)                                                           |
| Golang          | v1.14+    | [Golang installation](https://github.com/travis-ci/gimme)                                                                                                         |
| gosec           |           | [gosec](https://github.com/securego/gosec)                                                                                                          |
| gomock          | v.1.4.3   | [Go Mock](https://github.com/golang/mock)                                                                                                             |
| git             | latest    | [Git installation](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)                                                                              |
| gcc             |           | Run ```sudo apt install build-essential```                                                                                                 |
| kubectl         | 1.16-1.17 | Ensure you copy the kubeconfig file from the Kubernetes cluster to the linux host. [kubectl installation](https://kubernetes.io/docs/tasks/tools/install-kubectl/) |
| Helm            | v.3.3.0   | [Helm installation](https://helm.sh/docs/intro/install/)                                                                                                        |

Once all prerequisites are on the Linux host, follow the steps below to clone and build the metrics service:

1. Clone the repository: `git clone https://github.com/dell/karavi-metrics-powerflex.git`
1. Set the DOCKER_REPO environment variable to point to the local Docker repository, example: `export DOCKER_REPO=<ip-address>:<port>`
1. In the karavi-metrics-powerflex directory, run the following to build the Docker image called karavi-metrics-powerflex: `make clean build docker`
1. To tag (with the "latest" tag) and push the image to the local Docker repository run the following: `make tag push`

__Note:__ Linux support only. If you are using a local insecure docker registry, ensure you configure the insecure registries on each of the Kubernetes worker nodes to allow access to the local docker repository

## Testing Karavi Observability

From the root directory where the repo was cloned, the unit tests can be executed as follows:

```console
make test
```

This will also provide code coverage statistics for the various Go packages.

## Uninstalling the Chart

To uninstall/delete the deployment:

```console
$ helm delete karavi-observability --namespace karavi
```

The command removes all the Kubernetes components associated with the chart and deletes the release.
