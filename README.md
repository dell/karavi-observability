<!--
Copyright (c) 2021 Dell Inc., or its subsidiaries. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
-->

# Dell EMC Container Storage Modules (CSM) for Observability

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](docs/CODE_OF_CONDUCT.md)
[![License](https://img.shields.io/github/license/dell/karavi-observability)](LICENSE)
[![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/dell/karavi-observability?include_prereleases&label=latest&style=flat-square)](https://github.com/dell/karavi-observability/releases/latest)

CSM for Observability is part of the [CSM (Container Storage Modules)](https://github.com/dell/csm) open-source suite of Kubernetes storage enablers for Dell EMC products.

It is an OpenTelemetry agent that collects array-level metrics for Dell EMC storage so they can be scraped into a Prometheus database. With CSM for Observability, you will gain visibility not only on the capacity of the volumes/file shares you manage with Dell EMC CSI (Container Storage Interface) drivers but also their performance in terms of bandwidth, IOPS, and response time.

Thanks to pre-packaged Grafana dashboards, you will be able to go through these metrics history and see the topology between a Kubernetes PV (Persistent Volume) and its translation as a LUN or file share in the backend array. This module also allows Kubernetes admins to collect array level metrics to check the overall capacity and performance directly from the Prometheus/Grafana tools rather than interfacing directly with the storage system itself.

For documentation, please visit [Container Storage Modules documentation](https://dell.github.io/csm-docs/).

## Table of Contents

- [Code of Conduct](https://github.com/dell/csm/blob/main/docs/CODE_OF_CONDUCT.md)
- [Maintainer Guide](https://github.com/dell/csm/blob/main/docs/MAINTAINER_GUIDE.md)
- [Committer Guide](https://github.com/dell/csm/blob/main/docs/COMMITTER_GUIDE.md)
- [Contributing Guide](https://github.com/dell/csm/blob/main/docs/CONTRIBUTING.md)
- [Branching Strategy](https://github.com/dell/csm/blob/main/docs/BRANCHING.md)
- [List of Adopters](https://github.com/dell/csm/blob/main/ADOPTERS.md)
- [Maintainers](https://github.com/dell/csm/blob/main/docs/MAINTAINERS.md)
- [Support](https://github.com/dell/csm/blob/main/docs/SUPPORT.md)
- [Security](https://github.com/dell/csm/blob/main/docs/SECURITY.md)
- [About](#about)

## Versioning

This project is adhering to [Semantic Versioning](https://semver.org/).

## About

Dell EMC Container Storage Modules (CSM) is 100% open source and community-driven. All components are available
under [Apache 2 License](https://www.apache.org/licenses/LICENSE-2.0.html) on
GitHub.
