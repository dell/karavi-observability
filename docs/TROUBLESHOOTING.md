# Troubleshooting

# Table of Contents
- [Frequently Asked Questions](#frequently-asked-questions)
    1. [Why do I see a certificate problem when accessing the topology service outside of my Kubernetes cluster?](#why-do-i-see-a-certificate-problem-when-accessing-the-topology-service-outside-of-my-kubernetes-cluster)

## Frequently Asked Questions

### Why do I see a certificate problem when accessing the topology service outside of my Kubernetes cluster?

This issue can arise when the topology service manifest is updated to expose the service as NodePort and a client makes a request to the service. Karavi-toplogy is configured with a self-signed or custom certificate and when a client does not recognize a server's certificate, it shows an error and pings the server(karavi-topology) with the error.  You would see the issue when accessing the service through a browser or curl:

#### Browser experience

A user who tries to connect to `karavi-topology` on any browser may receive an error/warning message about the certificate. The message may vary depending on the browser. For instance, in Internet Explorer, you'll see:

```console
There is a problem with this website's security certificate. 
The security certificate presented by this website was not
issued by a trusted certificate authority
```

While this certificate problem may indicate an attempt to fool you or intercept data you send to the server, see [resolution](#resolution) on how to fix it

#### Curl experience

A user who tries to connect to `karavi-topology` by using `curl` may receive the following warning or error message:

```console
[root@:~]$ curl -v https://<karavi-topology-cluster-IP>:<port?/query
*   Trying ***********...
* TCP_NODELAY set
* Connected to *********** (***********) port 31433 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/ssl/certs/ca-certificates.crt
  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS Unknown, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Unknown (8):
* TLSv1.3 (IN), TLS Unknown, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (OUT), TLS alert, Server hello (2):
* SSL certificate problem: unable to get local issuer certificate
* stopped the pause stream!
* Closing connection 0
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.haxx.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```

#### Kubernetes Admin experience

Due to the error above, the client pings the topology server with a **TLS handshake error** which is logged in `karavi-topology` pod. For instance,

```console
[root@:~]$ kubectl  logs  -n powerflex karavi-topology-5d4669d6dd-trzxw
2021/04/27 09:38:28 Set DriverNames to [csi-vxflexos.dellemc.com]
2021/04/28 07:15:05 http: TLS handshake error from 10.42.0.0:58450: local error: tls: bad record MAC
2021/04/28 07:16:14 http: TLS handshake error from 10.42.0.0:55311: local error: tls: bad record MAC
```

#### Resolution

To resolve this issue, we need to configure the client to be aware of the karavi-topology certificate (this includes all custom SSL certificate that are not issued from a trusted Certificate Authority (CA))

##### Get a copy of the certificate used by karavi-topology

If we supplied a custom certificate during installing karavi-topology, we can simply open the `.crt` and copy the text. However, if it was assigned by cert-manager, you can get a copy of the certificate by running the following `kubectl` command on the clusters.

```console
[root@:~]$ kubectl -n <namespace> get secret karavi-topology-tls -o jsonpath='{.data.tls\.crt}' | base64 -d
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

##### Configure your client to accept the above certificate

A workaround on most browsers is to accept the `karavi-topology` by clicking **Continue to this website (not recommended)**. This will make all other successive communication to not cause any certificate error. Anyhow, you will need to read the documentation for your specific client to configure the above certificate. For Grafana, here are two ways to configure the karavi-topology datasource to use the above certificate:

  <details>
   <summary>Deploy certificate with new Grafana instance</summary>
 Please folow the steps in <a href="https://github.com/dell/karavi-observability/blob/main/docs/GETTING_STARTED_GUIDE.md#sample-grafana-deployment">Sample Grafana Deployment</a> but attach the certificate to your `grafana-values.yaml` before deploying. The file should look like:

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

## Additional grafana server CofigMap mounts
## Defines additional mounts with CofigMap. CofigMap must be manually created in the namespace.
extraConfigmapMounts: []
```
  </details>

<details>
   <summary>Add certificate to an existing Grafana instance</summary>
-  This only happens if you configure jsonData to not skip tls verification. If this is the case, you'll  need to re-deploy grafana as shown above or, form Grafana UI, edit Karavi-Topology datasource to use the certificate. To do the latter

1. visit your Grafana UI on a browser
2. navigate to setting and go to Data Sources
3. click on `Karavi-Topology`
4. ensure that `Skip TLS Verify` is already off
5. switch on `With CA Cert`
6. Copy the above certificate into the `TLS Auth Details` text box that appears
7. click `Save & Test` and validate that eveyrthing is working fine when a green bar showing `Data source is working` appears

</details>
