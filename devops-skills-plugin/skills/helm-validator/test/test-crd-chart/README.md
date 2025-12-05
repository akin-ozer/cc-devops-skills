# test-crd-chart

A test Helm chart demonstrating Custom Resource Definition (CRD) usage with cert-manager Certificates and Prometheus ServiceMonitors.

## Prerequisites

Before installing this chart, ensure the following are installed in your cluster:

1. **cert-manager** (for Certificate resources)
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

2. **Prometheus Operator** (for ServiceMonitor resources)
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install prometheus prometheus-community/kube-prometheus-stack
   ```

3. **ClusterIssuer** named `letsencrypt-prod` for certificate issuance

## Installation

```bash
helm install my-release ./test-crd-chart
```

## Configuration

The following table lists the configurable parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `certManager.enabled` | Enable cert-manager Certificate | `true` |
| `certManager.certificate.dnsNames` | DNS names for the certificate | `["example.com"]` |
| `prometheus.enabled` | Enable Prometheus ServiceMonitor | `true` |

## Values

```yaml
certManager:
  enabled: true
  certificate:
    dnsNames:
      - example.com

prometheus:
  enabled: true
```

## Resources Created

When installed with default values, this chart creates:

- **Certificate** (`cert-manager.io/v1`) - TLS certificate managed by cert-manager
- **ServiceMonitor** (`monitoring.coreos.com/v1`) - Prometheus scrape configuration

## Uninstallation

```bash
helm uninstall my-release
```

## Testing

Validate the chart before installation:

```bash
helm lint ./test-crd-chart
helm template test-release ./test-crd-chart
```