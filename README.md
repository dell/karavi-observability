<!--
Copyright (c) 2020 Dell Inc., or its subsidiaries. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
-->

# Karavi Observability

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](docs/CODE_OF_CONDUCT.md)
[![License](https://img.shields.io/github/license/dell/karavi-metrics-powerflex)](LICENSE)

Karavi Observability is part of the Karavi open source suite of Kubernetes storage enablers for Dell EMC products, providing standardized approaches for storage observability.
It currently has the following services:

| Karavi Observability Service | Description | Repository |
| --------- | --------- | --------- |
| Karavi Metrics for PowerFlex | Karavi Metrics for PowerFlex captures telemetry data about Kubernetes storage usage and performance obtained through the CSI (Container Storage Interface) Driver for Dell EMC PowerFlex. The metrics service pushes it to the OpenTelemetry Collector, so it can be processed, and exported in a format consumable by Prometheus. Prometheus can then be configured to scrape the OpenTelemetry Collector exporter endpoint to provide metrics so they can be visualized in Grafana. Please visit the repository for more information. | [Karavi Metrics for PowerFlex](https://github.com/dell/karavi-metrics-powerflex) |
| Karavi Topology | Karavi Topology provides Kubernetes administrators with the topology data related to containerized storage that are provisioned by a CSI (Container Storage Interface) Driver for Dell EMC storage products. Please visit the repository for more information. | [Karavi Topology](https://github.com/dell/karavi-topology) |

Please see [Getting Started Guide](./docs/GETTING_STARTED_GUIDE.md) for information on requirements, deployment, and usage.

## Table of Contents

- [Code of Conduct](./docs/CODE_OF_CONDUCT.md)
- [Getting Started Guide](./docs/GETTING_STARTED_GUIDE.md)
- [Maintainers](./docs/MAINTAINERS.md)
- [About](#about)

## Support

Don’t hesitate to ask! Contact the team and community on [our support](./docs/SUPPORT.md).
Open an issue if you found a bug on [Github Issues](https://github.com/dell/karavi-observability/issues).

## Versioning

This project is adhering to [Semantic Versioning](https://semver.org/).

## About

Karavi Observability is 100% open source and community-driven. All components are available
under [Apache 2 License](https://www.apache.org/licenses/LICENSE-2.0.html) on
GitHub.
