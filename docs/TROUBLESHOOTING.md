# Troubleshooting

## Table of Contents
- [TLS handshake error](#karavi-topology-module-reports-tls-handshake-error)

### karavi-topology module reports TLS handshake error

This situation may occur when the client making a request to `karavi-topology` server does not recognized the topology server certificate. For example, when topology module is installed as usual (no custom certificate plain cert-manager) and exposed as a `NodePort`, if you visit the full http part for the topology service on any browser, you'll get a TLS handskahe error as the browser is not aware of your self-signed certificate.

```
$ kubectl  logs  -n powerflex karavi-topology-5d4669d6dd-trzxw
2021/04/27 09:38:28 Set DriverNames to [csi-vxflexos.dellemc.com]
2021/04/28 07:15:05 http: TLS handshake error from 10.42.0.0:58450: local error: tls: bad record MAC
2021/04/28 07:16:14 http: TLS handshake error from 10.42.0.0:55311: local error: tls: bad record MAC
```

#### Resolution

To resolve this issue, we need to configure the client to be aware of  the karavi-topology certificate (this includes all custom SSL certificate that are not issued from a trusted Certificate Authority (CA))

1. Get a copy of the certificate used by karavi-topology. If we supplied a custom certificate during installing karavi-topology, we can simply open the `.crt` and copy the text. However, if it was assigned by cert-manager, you can get a copy of the certificate by running the following kubectl command on the clusters.

```
kubectl -n <namespace> get secret karavi-topology-tls -o jsonpath='{.data.tls\.crt}' | base64 -d
```

By now we will have a certificate that looks 

```

-----BEGIN CERTIFICATE-----
RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
RaNDOMcErTifCATe..RaNDOMcErTifCATeRaNDOMcErTifCATe
RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
RaNDOMcErTifCATe..RaNDOMcErTifCATeRaNDOMcErTifCATe
RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
RaNDOMcErTifCATe..RaNDOMcErTifCATeRaNDOMcErTifCATe
RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
-----END CERTIFICATE-----
```

2. Look up the several ways to configure your client to accept the above certificate. For the case of demonstration, below are possible two ways to configure Grafana to use the above certificate for karavi-topology DataSource:

<details>
   <summary>Deploy New Grafana</summary>

- Attach the certificate to your `grafana-values.yaml`. The file should look like:

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
        tlsAuthWithCACert: true
      secureJsonData:
       tlsCaCert: |
      -----BEGIN CERTIFICATE-----
      RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
      RaNDOMcErTifCATe..RaNDOMcErTifCATeRaNDOMcErTifCATe
      RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
      RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
      RaNDOMcErTifCATe..RaNDOMcErTifCATeRaNDOMcErTifCATe
      RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
      RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
      RaNDOMcErTifCATe..RaNDOMcErTifCATeRaNDOMcErTifCATe
      RaNDOMcErTifCATeRaNDOMcErTifCATe..RaNDOMcErTifCATe
      -----END CERTIFICATE-----
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

## Additional grafana server ConfigMap mounts
## Defines additional mounts with ConfigMap. ConfigMap must be manually created in the namespace.
extraConfigmapMounts: []
```

</details>

<details>
   <summary>Add to existing Grafana</summary>

-  This only happens if you configure jsonData to not skip tls verification. If this is the case, you'll  need to re-deploy grafana as shown above or, form Grafana UI, edit Karavi-Topology datasource to use the certificate. To do the latter
1. visit your Grafana UI on a browser
2. navigate to setting and go to Data Sources
3. click on `Karavi-Topology`
4. ensure that `Skip TLS Verify` is already off
5. switch on `With CA Cert`
6. Copy the above certificate into the `TLS Auth Details` text box that appears
7. click `Save & Test` and validate that eveyrthing is working fine when a green bar showing `Data source is working` appears

</details>
