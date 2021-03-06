<!--
Copyright (c) 2021 Dell Inc., or its subsidiaries. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
-->

# Karavi Observability

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](docs/CODE_OF_CONDUCT.md)
[![License](https://img.shields.io/github/license/dell/karavi-observability)](LICENSE)
[![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/dell/karavi-observability?include_prereleases&label=latest&style=flat-square)](https://github.com/dell/karavi-observability/releases/latest)

Karavi Observability is part of the [Karavi](https://github.com/dell/karavi) open source suite of Kubernetes storage enablers for Dell EMC products. It provides standardized approaches for storage observability. Karavi Observability consists of several services, each of which is contained in a separate repository. This repository will be the hub for all things concerning Karavi Observability. [Issues](https://github.com/dell/karavi-observability/issues) against any of the Karavi Observability services need to be created here.

Several services compose Karavi Observability, each living in their own GitHub repository. Contributions can be made to this repository or any of the Karavi Observability repositories listed below. New releases of Karavi Observability are made available when any of these services are released. Each new release will contain notes detailing the changes and updates made to each service since the previous release.

| Name | Repository | Description |
| ---- | ---------  | ----------- |
| Performance Metrics for PowerFlex | [Karavi Metrics for PowerFlex](https://github.com/dell/karavi-metrics-powerflex) | Performance Metrics for PowerFlex captures telemetry data about Kubernetes storage usage and performance obtained through the CSI (Container Storage Interface) Driver for Dell EMC PowerFlex. The metrics service pushes it to the OpenTelemetry Collector, so it can be processed, and exported in a format consumable by Prometheus. Prometheus can then be configured to scrape the OpenTelemetry Collector exporter endpoint to provide metrics so they can be visualized in Grafana. Please visit the repository for more information. |
| Performance Metrics for PowerStore | [Karavi Metrics for PowerStore](https://github.com/dell/csm-metrics-powerstore) | *As of Release 0.4.0:* Performance Metrics for PowerStore captures telemetry data about Kubernetes storage usage and performance obtained through the CSI (Container Storage Interface) Driver for Dell EMC PowerStore. The metrics service pushes it to the OpenTelemetry Collector, so it can be processed, and exported in a format consumable by Prometheus. Prometheus can then be configured to scrape the OpenTelemetry Collector exporter endpoint to provide metrics so they can be visualized in Grafana. Please visit the repository for more information. |
| Volume Topology | [Karavi Topology](https://github.com/dell/karavi-topology) | Topology provides Kubernetes administrators with the topology data related to containerized storage that is provisioned by a CSI (Container Storage Interface) Driver for Dell EMC storage products. Please visit the repository for more information. |
| Helm Chart | [Karavi Observability Helm Chart](https://github.com/dell/helm-charts/tree/main/charts/karavi-observability) | The Karavi Observability Helm chart facilitates the deploying of the observability solution. |

Please see [Getting Started Guide](./docs/GETTING_STARTED_GUIDE.md) for information on requirements, deployment, and usage.

## Table of Contents

- [Code of Conduct](./docs/CODE_OF_CONDUCT.md)
- [Getting Started Guide](./docs/GETTING_STARTED_GUIDE.md)
- [Branching Strategy](./docs/BRANCHING.md)
- [Contributing Guide](./docs/CONTRIBUTING.md)
- [Maintainers](./docs/MAINTAINERS.md)
- [About](#about)

## Support

Don’t hesitate to ask! Contact the team and community on our [support](./docs/SUPPORT.md) page.
Open an issue if you found a bug on [Github Issues](https://github.com/dell/karavi-observability/issues).

## Versioning

This project is adhering to [Semantic Versioning](https://semver.org/).

## About

Karavi Observability is 100% open source and community-driven. All components are available
under [Apache 2 License](https://www.apache.org/licenses/LICENSE-2.0.html) on
GitHub.
