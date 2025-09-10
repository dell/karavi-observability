<!--
Copyright (c) 2021-2025 Dell Inc., or its subsidiaries. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
-->

# :lock: **Important Notice**
Starting with the release of **Container Storage Modules v1.16.0**, this repository will no longer be maintained as an open source project. Future development will continue under a closed source model. This change reflects our commitment to delivering even greater value to our customers by enabling faster innovation and more deeply integrated features with the Dell storage portfolio.<br>
For existing customers using Dell’s Container Storage Modules, you will continue to receive:
* **Ongoing Support & Community Engagement**<br>
       You will continue to receive high-quality support through Dell Support and our community channels. Your experience of engaging with the Dell community remains unchanged.
* **Streamlined Deployment & Updates**<br>
        Deployment and update processes will remain consistent, ensuring a smooth and familiar experience.
* **Access to Documentation & Resources**<br>
       All documentation and related materials will remain publicly accessible, providing transparency and technical guidance.
* **Continued Access to Current Open Source Version**<br>
       The current open-source version will remain available under its existing license for those who rely on it.

Moving to a Enterprise model allows Dell’s development team to accelerate feature delivery and enhance integration across our Enterprise Kubernetes Storage solutions ultimately providing a more seamless and robust experience.<br>
We deeply appreciate the contributions of the open source community and remain committed to supporting our customers through this transition.<br>

For questions or access requests, please contact the maintainers via [Dell Support](https://www.dell.com/support/kbdoc/en-in/000188046/container-storage-interface-csi-drivers-and-container-storage-modules-csm-how-to-get-support).

# Dell Container Storage Modules (CSM) for Observability

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](docs/CODE_OF_CONDUCT.md)
[![License](https://img.shields.io/github/license/dell/karavi-observability)](LICENSE)
[![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/dell/karavi-observability?include_prereleases&label=latest&style=flat-square)](https://github.com/dell/karavi-observability/releases/latest)

CSM for Observability is part of the [CSM (Container Storage Modules)](https://github.com/dell/csm) open-source suite of Kubernetes storage enablers for Dell products.

It is an OpenTelemetry agent that collects array-level metrics for Dell storage so they can be scraped into a Prometheus database. With CSM for Observability, you will gain visibility not only on the capacity of the volumes/file shares you manage with Dell CSI (Container Storage Interface) drivers but also their performance in terms of bandwidth, IOPS, and response time.

Thanks to pre-packaged Grafana dashboards, you will be able to go through these metrics history and see the topology between a Kubernetes PV (Persistent Volume) and its translation as a LUN or file share in the backend array. This module also allows Kubernetes admins to collect array level metrics to check the overall capacity and performance directly from the Prometheus/Grafana tools rather than interfacing directly with the storage system itself.

For documentation, please visit [Container Storage Modules documentation](https://dell.github.io/csm-docs/).

## Table of Contents

- [Code of Conduct](https://github.com/dell/csm/blob/main/docs/CODE_OF_CONDUCT.md)
- [Maintainer Guide](https://github.com/dell/csm/blob/main/docs/MAINTAINER_GUIDE.md)
- [Committer Guide](https://github.com/dell/csm/blob/main/docs/COMMITTER_GUIDE.md)
- [Contributing Guide](https://github.com/dell/csm/blob/main/docs/CONTRIBUTING.md)
- [List of Adopters](https://github.com/dell/csm/blob/main/docs/ADOPTERS.md)
- [Dell support](https://www.dell.com/support/incidents-online/en-us/contactus/product/container-storage-modules)
- [Security](https://github.com/dell/csm/blob/main/docs/SECURITY.md)
- [About](#about)

## Versioning

This project is adhering to [Semantic Versioning](https://semver.org/).

## About

Dell Container Storage Modules (CSM) is 100% open source and community-driven. All components are available
under [Apache 2 License](https://www.apache.org/licenses/LICENSE-2.0.html) on
GitHub.
