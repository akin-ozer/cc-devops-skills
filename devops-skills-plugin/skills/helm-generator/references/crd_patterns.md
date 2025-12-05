# CRD Patterns and Examples

Common Custom Resource Definition patterns and examples for Helm charts.

## Table of Contents

- [cert-manager](#cert-manager)
- [Prometheus Operator](#prometheus-operator)
- [Istio](#istio)
- [ArgoCD](#argocd)
- [Sealed Secrets](#sealed-secrets)
- [External Secrets Operator](#external-secrets-operator)
- [Gateway API](#gateway-api)
- [KEDA](#keda)
- [VerticalPodAutoscaler (VPA)](#verticalpodautoscaler-vpa)

---

## cert-manager

### Certificate Resource

**File:** `templates/certificate.yaml`

```yaml
{{- if .Values.certificate.enabled }}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ include "mychart.fullname" . }}-tls
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  secretName: {{ include "mychart.fullname" . }}-tls
  issuerRef:
    name: {{ .Values.certificate.issuer.name }}
    kind: {{ .Values.certificate.issuer.kind | default "ClusterIssuer" }}
    {{- with .Values.certificate.issuer.group }}
    group: {{ . }}
    {{- end }}
  commonName: {{ .Values.certificate.commonName | default (first .Values.certificate.dnsNames) }}
  dnsNames:
    {{- range .Values.certificate.dnsNames }}
    - {{ . | quote }}
    {{- end }}
  {{- with .Values.certificate.ipAddresses }}
  ipAddresses:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.certificate.uris }}
  uris:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.certificate.duration }}
  duration: {{ . }}
  {{- end }}
  {{- with .Values.certificate.renewBefore }}
  renewBefore: {{ . }}
  {{- end }}
  {{- with .Values.certificate.usages }}
  usages:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.certificate.privateKey }}
  privateKey:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.certificate.keystores }}
  keystores:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
certificate:
  enabled: false
  issuer:
    name: letsencrypt-prod
    kind: ClusterIssuer
    group: cert-manager.io
  commonName: ""
  dnsNames:
    - example.com
    - www.example.com
  ipAddresses: []
  uris: []
  duration: 2160h  # 90 days
  renewBefore: 360h  # 15 days
  usages:
    - digital signature
    - key encipherment
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
    rotationPolicy: Never
  keystores: {}
  # keystores:
  #   jks:
  #     create: true
  #     passwordSecretRef:
  #       name: jks-password
  #       key: password
```

### ClusterIssuer Resource

**File:** `templates/clusterissuer.yaml`

```yaml
{{- if .Values.certManager.clusterIssuer.create }}
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: {{ .Values.certManager.clusterIssuer.name }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  {{- if eq .Values.certManager.clusterIssuer.type "acme" }}
  acme:
    server: {{ .Values.certManager.clusterIssuer.acme.server }}
    email: {{ required "certManager.clusterIssuer.acme.email is required!" .Values.certManager.clusterIssuer.acme.email }}
    privateKeySecretRef:
      name: {{ .Values.certManager.clusterIssuer.acme.privateKeySecretName }}
    solvers:
    {{- range .Values.certManager.clusterIssuer.acme.solvers }}
    - {{ toYaml . | nindent 6 }}
    {{- end }}
  {{- else if eq .Values.certManager.clusterIssuer.type "ca" }}
  ca:
    secretName: {{ .Values.certManager.clusterIssuer.ca.secretName }}
  {{- else if eq .Values.certManager.clusterIssuer.type "selfSigned" }}
  selfSigned: {}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
certManager:
  clusterIssuer:
    create: false
    name: letsencrypt-prod
    type: acme  # acme, ca, selfSigned, vault, venafi
    acme:
      server: https://acme-v02.api.letsencrypt.org/directory
      email: admin@example.com
      privateKeySecretName: letsencrypt-prod-account-key
      solvers:
        - http01:
            ingress:
              class: nginx
        # - dns01:
        #     cloudflare:
        #       email: admin@example.com
        #       apiTokenSecretRef:
        #         name: cloudflare-api-token
        #         key: api-token
    ca:
      secretName: ca-key-pair
```

---

## Prometheus Operator

### ServiceMonitor Resource

**File:** `templates/servicemonitor.yaml`

```yaml
{{- if .Values.metrics.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
    {{- with .Values.metrics.serviceMonitor.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.metrics.serviceMonitor.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  selector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
  endpoints:
  - port: {{ .Values.metrics.serviceMonitor.port | default "metrics" }}
    {{- with .Values.metrics.serviceMonitor.interval }}
    interval: {{ . }}
    {{- end }}
    {{- with .Values.metrics.serviceMonitor.scrapeTimeout }}
    scrapeTimeout: {{ . }}
    {{- end }}
    {{- with .Values.metrics.serviceMonitor.path }}
    path: {{ . }}
    {{- end }}
    {{- with .Values.metrics.serviceMonitor.scheme }}
    scheme: {{ . }}
    {{- end }}
    {{- with .Values.metrics.serviceMonitor.tlsConfig }}
    tlsConfig:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.metrics.serviceMonitor.relabelings }}
    relabelings:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.metrics.serviceMonitor.metricRelabelings }}
    metricRelabelings:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- with .Values.metrics.serviceMonitor.namespaceSelector }}
  namespaceSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
metrics:
  enabled: true
  port: 9090
  serviceMonitor:
    enabled: false
    labels: {}
    annotations: {}
    port: metrics
    interval: 30s
    scrapeTimeout: 10s
    path: /metrics
    scheme: http
    tlsConfig: {}
    relabelings: []
    metricRelabelings: []
    namespaceSelector: {}
```

### PrometheusRule Resource

**File:** `templates/prometheusrule.yaml`

```yaml
{{- if .Values.metrics.prometheusRule.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
    {{- with .Values.metrics.prometheusRule.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  groups:
  {{- range .Values.metrics.prometheusRule.groups }}
  - name: {{ .name }}
    {{- with .interval }}
    interval: {{ . }}
    {{- end }}
    rules:
    {{- range .rules }}
    - alert: {{ .alert }}
      expr: {{ .expr }}
      {{- with .for }}
      for: {{ . }}
      {{- end }}
      {{- with .labels }}
      labels:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      annotations:
        {{- range $key, $value := .annotations }}
        {{ $key }}: {{ $value | quote }}
        {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
metrics:
  prometheusRule:
    enabled: false
    labels: {}
    groups:
      - name: mychart-alerts
        interval: 30s
        rules:
          - alert: HighErrorRate
            expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "High error rate detected"
              description: "Error rate is {{ $value }} errors per second"
          - alert: PodDown
            expr: up{job="mychart"} == 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Pod is down"
              description: "Pod {{ $labels.pod }} is down"
```

---

## Istio

### VirtualService Resource

**File:** `templates/virtualservice.yaml`

```yaml
{{- if .Values.istio.virtualService.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  hosts:
  {{- range .Values.istio.virtualService.hosts }}
    - {{ . | quote }}
  {{- end }}
  {{- with .Values.istio.virtualService.gateways }}
  gateways:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.istio.virtualService.http }}
  http:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.istio.virtualService.tcp }}
  tcp:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.istio.virtualService.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
istio:
  virtualService:
    enabled: false
    hosts:
      - example.com
    gateways:
      - istio-system/gateway
    http:
      - match:
          - uri:
              prefix: /api
        route:
          - destination:
              host: mychart-svc
              port:
                number: 80
            weight: 90
          - destination:
              host: mychart-svc-canary
              port:
                number: 80
            weight: 10
        timeout: 30s
        retries:
          attempts: 3
          perTryTimeout: 10s
    tcp: []
    tls: []
```

### Gateway Resource

**File:** `templates/gateway.yaml`

```yaml
{{- if .Values.istio.gateway.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  selector:
    {{- toYaml .Values.istio.gateway.selector | nindent 4 }}
  servers:
  {{- range .Values.istio.gateway.servers }}
  - port:
      number: {{ .port.number }}
      name: {{ .port.name }}
      protocol: {{ .port.protocol }}
    hosts:
    {{- range .hosts }}
      - {{ . | quote }}
    {{- end }}
    {{- with .tls }}
    tls:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
istio:
  gateway:
    enabled: false
    selector:
      istio: ingressgateway
    servers:
      - port:
          number: 80
          name: http
          protocol: HTTP
        hosts:
          - example.com
      - port:
          number: 443
          name: https
          protocol: HTTPS
        hosts:
          - example.com
        tls:
          mode: SIMPLE
          credentialName: example-com-tls
```

### DestinationRule Resource

**File:** `templates/destinationrule.yaml`

```yaml
{{- if .Values.istio.destinationRule.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  host: {{ .Values.istio.destinationRule.host | default (include "mychart.fullname" .) }}
  {{- with .Values.istio.destinationRule.trafficPolicy }}
  trafficPolicy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.istio.destinationRule.subsets }}
  subsets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
istio:
  destinationRule:
    enabled: false
    host: mychart-svc
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 100
        http:
          http1MaxPendingRequests: 50
          http2MaxRequests: 100
      loadBalancer:
        simple: LEAST_REQUEST
      outlierDetection:
        consecutiveErrors: 5
        interval: 30s
        baseEjectionTime: 30s
        maxEjectionPercent: 50
    subsets:
      - name: v1
        labels:
          version: v1
      - name: v2
        labels:
          version: v2
        trafficPolicy:
          loadBalancer:
            simple: ROUND_ROBIN
```

---

## ArgoCD

### Application Resource

**File:** `templates/argocd-application.yaml`

```yaml
{{- if .Values.argocd.application.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ include "mychart.fullname" . }}
  namespace: {{ .Values.argocd.application.namespace | default "argocd" }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.argocd.application.finalizers }}
  finalizers:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  project: {{ .Values.argocd.application.project | default "default" }}
  source:
    repoURL: {{ required "argocd.application.source.repoURL is required!" .Values.argocd.application.source.repoURL }}
    targetRevision: {{ .Values.argocd.application.source.targetRevision | default "HEAD" }}
    path: {{ .Values.argocd.application.source.path }}
    {{- with .Values.argocd.application.source.helm }}
    helm:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  destination:
    server: {{ .Values.argocd.application.destination.server | default "https://kubernetes.default.svc" }}
    namespace: {{ .Values.argocd.application.destination.namespace | default .Release.Namespace }}
  syncPolicy:
    {{- with .Values.argocd.application.syncPolicy }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.argocd.application.ignoreDifferences }}
  ignoreDifferences:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
argocd:
  application:
    enabled: false
    namespace: argocd
    project: default
    finalizers:
      - resources-finalizer.argocd.argoproj.io
    source:
      repoURL: https://github.com/example/repo
      targetRevision: main
      path: charts/mychart
      helm:
        releaseName: mychart
        valueFiles:
          - values.yaml
        values: ""
    destination:
      server: https://kubernetes.default.svc
      namespace: default
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
        allowEmpty: false
      syncOptions:
        - CreateNamespace=true
        - PruneLast=true
      retry:
        limit: 5
        backoff:
          duration: 5s
          factor: 2
          maxDuration: 3m
    ignoreDifferences: []
```

### AppProject Resource

**File:** `templates/argocd-appproject.yaml`

```yaml
{{- if .Values.argocd.appProject.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: {{ .Values.argocd.appProject.name }}
  namespace: {{ .Values.argocd.appProject.namespace | default "argocd" }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.argocd.appProject.finalizers }}
  finalizers:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  description: {{ .Values.argocd.appProject.description }}
  sourceRepos:
  {{- range .Values.argocd.appProject.sourceRepos }}
    - {{ . | quote }}
  {{- end }}
  destinations:
  {{- range .Values.argocd.appProject.destinations }}
  - namespace: {{ .namespace }}
    server: {{ .server }}
  {{- end }}
  {{- with .Values.argocd.appProject.clusterResourceWhitelist }}
  clusterResourceWhitelist:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.argocd.appProject.namespaceResourceWhitelist }}
  namespaceResourceWhitelist:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
argocd:
  appProject:
    enabled: false
    name: myproject
    namespace: argocd
    description: "My ArgoCD Project"
    finalizers:
      - resources-finalizer.argocd.argoproj.io
    sourceRepos:
      - '*'
    destinations:
      - namespace: '*'
        server: https://kubernetes.default.svc
    clusterResourceWhitelist:
      - group: '*'
        kind: '*'
    namespaceResourceWhitelist: []
```

---

## Sealed Secrets

### SealedSecret Resource

**File:** `templates/sealedsecret.yaml`

```yaml
{{- if .Values.sealedSecret.enabled }}
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  encryptedData:
    {{- range $key, $value := .Values.sealedSecret.encryptedData }}
    {{ $key }}: {{ $value }}
    {{- end }}
  template:
    metadata:
      name: {{ include "mychart.fullname" . }}
      labels:
        {{- include "mychart.labels" . | nindent 8 }}
    type: {{ .Values.sealedSecret.type | default "Opaque" }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
sealedSecret:
  enabled: false
  type: Opaque
  encryptedData: {}
    # API_KEY: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEq...
    # DATABASE_PASSWORD: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEq...
```

---

## External Secrets Operator

### ExternalSecret Resource

**File:** `templates/externalsecret.yaml`

```yaml
{{- if .Values.externalSecret.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  secretStoreRef:
    name: {{ .Values.externalSecret.secretStoreRef.name }}
    kind: {{ .Values.externalSecret.secretStoreRef.kind | default "SecretStore" }}
  target:
    name: {{ include "mychart.fullname" . }}
    {{- with .Values.externalSecret.target.creationPolicy }}
    creationPolicy: {{ . }}
    {{- end }}
    {{- with .Values.externalSecret.target.template }}
    template:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- with .Values.externalSecret.refreshInterval }}
  refreshInterval: {{ . }}
  {{- end }}
  {{- if .Values.externalSecret.data }}
  data:
  {{- range .Values.externalSecret.data }}
  - secretKey: {{ .secretKey }}
    remoteRef:
      key: {{ .remoteRef.key }}
      {{- with .remoteRef.property }}
      property: {{ . }}
      {{- end }}
      {{- with .remoteRef.version }}
      version: {{ . }}
      {{- end }}
  {{- end }}
  {{- end }}
  {{- if .Values.externalSecret.dataFrom }}
  dataFrom:
  {{- range .Values.externalSecret.dataFrom }}
  - extract:
      key: {{ .extract.key }}
      {{- with .extract.property }}
      property: {{ . }}
      {{- end }}
  {{- end }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
externalSecret:
  enabled: false
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    creationPolicy: Owner
    template:
      type: Opaque
  refreshInterval: 1h
  data:
    - secretKey: API_KEY
      remoteRef:
        key: secret/data/myapp
        property: api_key
    - secretKey: DATABASE_PASSWORD
      remoteRef:
        key: secret/data/myapp
        property: db_password
  dataFrom: []
  # dataFrom:
  #   - extract:
  #       key: secret/data/myapp
```

### SecretStore Resource

**File:** `templates/secretstore.yaml`

```yaml
{{- if .Values.externalSecret.secretStore.create }}
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: {{ .Values.externalSecret.secretStore.name }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  provider:
    {{- if .Values.externalSecret.secretStore.provider.vault }}
    vault:
      server: {{ .Values.externalSecret.secretStore.provider.vault.server }}
      path: {{ .Values.externalSecret.secretStore.provider.vault.path }}
      version: {{ .Values.externalSecret.secretStore.provider.vault.version | default "v2" }}
      auth:
        {{- toYaml .Values.externalSecret.secretStore.provider.vault.auth | nindent 8 }}
    {{- else if .Values.externalSecret.secretStore.provider.aws }}
    aws:
      service: {{ .Values.externalSecret.secretStore.provider.aws.service }}
      region: {{ .Values.externalSecret.secretStore.provider.aws.region }}
      {{- with .Values.externalSecret.secretStore.provider.aws.auth }}
      auth:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    {{- else if .Values.externalSecret.secretStore.provider.gcpsm }}
    gcpsm:
      projectID: {{ .Values.externalSecret.secretStore.provider.gcpsm.projectID }}
      {{- with .Values.externalSecret.secretStore.provider.gcpsm.auth }}
      auth:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
externalSecret:
  secretStore:
    create: false
    name: vault-backend
    provider:
      vault:
        server: https://vault.example.com
        path: secret
        version: v2
        auth:
          kubernetes:
            mountPath: kubernetes
            role: myapp
            serviceAccountRef:
              name: mychart
      # aws:
      #   service: SecretsManager
      #   region: us-east-1
      #   auth:
      #     jwt:
      #       serviceAccountRef:
      #         name: mychart
      # gcpsm:
      #   projectID: my-project
      #   auth:
      #     workloadIdentity:
      #       clusterLocation: us-central1
      #       clusterName: my-cluster
      #       serviceAccountRef:
      #         name: mychart
```

---

## Gateway API

The Gateway API is the evolution of Kubernetes Ingress, providing more expressive and extensible routing capabilities. It's becoming the standard for north-south traffic management in Kubernetes.

### GatewayClass Resource

**File:** `templates/gatewayclass.yaml`

```yaml
{{- if .Values.gatewayAPI.gatewayClass.create }}
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: {{ .Values.gatewayAPI.gatewayClass.name }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.gatewayAPI.gatewayClass.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  controllerName: {{ required "gatewayAPI.gatewayClass.controllerName is required!" .Values.gatewayAPI.gatewayClass.controllerName }}
  {{- with .Values.gatewayAPI.gatewayClass.parametersRef }}
  parametersRef:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.gatewayAPI.gatewayClass.description }}
  description: {{ . | quote }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
gatewayAPI:
  gatewayClass:
    create: false
    name: my-gateway-class
    # Controller implementations:
    # - gateway.nginx.org/nginx-gateway-controller (NGINX Gateway Fabric)
    # - gateway.envoyproxy.io/gatewayclass-controller (Envoy Gateway)
    # - istio.io/gateway-controller (Istio)
    # - projectcontour.io/gateway-controller (Contour)
    # - traefik.io/gateway-controller (Traefik)
    controllerName: gateway.nginx.org/nginx-gateway-controller
    annotations: {}
    description: "Production gateway class"
    parametersRef: {}
    # parametersRef:
    #   group: gateway.nginx.org
    #   kind: NginxProxy
    #   name: nginx-proxy-config
```

### Gateway Resource

**File:** `templates/gateway.yaml`

```yaml
{{- if .Values.gatewayAPI.gateway.enabled }}
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: {{ include "mychart.fullname" . }}
  namespace: {{ .Values.gatewayAPI.gateway.namespace | default .Release.Namespace }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.gatewayAPI.gateway.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  gatewayClassName: {{ required "gatewayAPI.gateway.gatewayClassName is required!" .Values.gatewayAPI.gateway.gatewayClassName }}
  {{- with .Values.gatewayAPI.gateway.addresses }}
  addresses:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  listeners:
  {{- range .Values.gatewayAPI.gateway.listeners }}
  - name: {{ .name }}
    hostname: {{ .hostname | quote }}
    port: {{ .port }}
    protocol: {{ .protocol }}
    {{- with .tls }}
    tls:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .allowedRoutes }}
    allowedRoutes:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- end }}
  {{- with .Values.gatewayAPI.gateway.infrastructure }}
  infrastructure:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
gatewayAPI:
  gateway:
    enabled: false
    namespace: ""  # defaults to release namespace
    gatewayClassName: my-gateway-class
    annotations: {}
    addresses: []
    # addresses:
    #   - type: IPAddress
    #     value: 10.0.0.1
    listeners:
      - name: http
        hostname: "*.example.com"
        port: 80
        protocol: HTTP
        allowedRoutes:
          namespaces:
            from: Same
          kinds:
            - kind: HTTPRoute
      - name: https
        hostname: "*.example.com"
        port: 443
        protocol: HTTPS
        tls:
          mode: Terminate
          certificateRefs:
            - name: example-com-tls
              kind: Secret
        allowedRoutes:
          namespaces:
            from: Same
          kinds:
            - kind: HTTPRoute
    infrastructure: {}
    # infrastructure:
    #   labels:
    #     app: my-gateway
    #   annotations:
    #     service.beta.kubernetes.io/aws-load-balancer-type: nlb
```

### HTTPRoute Resource

**File:** `templates/httproute.yaml`

```yaml
{{- if .Values.gatewayAPI.httpRoute.enabled }}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "mychart.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.gatewayAPI.httpRoute.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with .Values.gatewayAPI.httpRoute.parentRefs }}
  parentRefs:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.gatewayAPI.httpRoute.hostnames }}
  hostnames:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
  {{- range .Values.gatewayAPI.httpRoute.rules }}
  - {{- with .matches }}
    matches:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .filters }}
    filters:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    backendRefs:
    {{- range .backendRefs }}
    - name: {{ .name | default (include "mychart.fullname" $) }}
      port: {{ .port | default $.Values.service.port }}
      {{- with .weight }}
      weight: {{ . }}
      {{- end }}
      {{- with .kind }}
      kind: {{ . }}
      {{- end }}
      {{- with .namespace }}
      namespace: {{ . }}
      {{- end }}
    {{- end }}
    {{- with .timeouts }}
    timeouts:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
gatewayAPI:
  httpRoute:
    enabled: false
    annotations: {}
    parentRefs:
      - name: my-gateway
        namespace: default
        sectionName: https
    hostnames:
      - app.example.com
    rules:
      # Simple routing to backend service
      - matches:
          - path:
              type: PathPrefix
              value: /
        backendRefs:
          - name: ""  # defaults to chart fullname
            port: 0   # defaults to service.port
            weight: 100

      # Path-based routing with multiple backends
      - matches:
          - path:
              type: PathPrefix
              value: /api
          - path:
              type: PathPrefix
              value: /v1
        backendRefs:
          - name: api-service
            port: 8080
            weight: 90
          - name: api-service-canary
            port: 8080
            weight: 10

      # Header-based routing
      - matches:
          - headers:
              - name: X-Version
                value: beta
        backendRefs:
          - name: beta-service
            port: 8080

      # Method-based routing
      - matches:
          - method: POST
            path:
              type: Exact
              value: /webhook
        backendRefs:
          - name: webhook-service
            port: 8080
        timeouts:
          request: 30s
```

### HTTPRoute with Filters

**File:** `templates/httproute-advanced.yaml`

```yaml
{{- if .Values.gatewayAPI.httpRouteAdvanced.enabled }}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "mychart.fullname" . }}-advanced
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  parentRefs:
    - name: {{ .Values.gatewayAPI.httpRouteAdvanced.gatewayRef }}
  hostnames:
    {{- range .Values.gatewayAPI.httpRouteAdvanced.hostnames }}
    - {{ . | quote }}
    {{- end }}
  rules:
  {{- if .Values.gatewayAPI.httpRouteAdvanced.redirectHttpToHttps }}
  # HTTP to HTTPS redirect
  - matches:
      - path:
          type: PathPrefix
          value: /
    filters:
      - type: RequestRedirect
        requestRedirect:
          scheme: https
          statusCode: 301
  {{- end }}
  {{- if .Values.gatewayAPI.httpRouteAdvanced.urlRewrite }}
  # URL rewrite
  - matches:
      - path:
          type: PathPrefix
          value: {{ .Values.gatewayAPI.httpRouteAdvanced.urlRewrite.matchPath }}
    filters:
      - type: URLRewrite
        urlRewrite:
          path:
            type: ReplacePrefixMatch
            replacePrefixMatch: {{ .Values.gatewayAPI.httpRouteAdvanced.urlRewrite.replacePath }}
    backendRefs:
      - name: {{ include "mychart.fullname" . }}
        port: {{ .Values.service.port }}
  {{- end }}
  {{- if .Values.gatewayAPI.httpRouteAdvanced.requestHeaderModifier }}
  # Request header modification
  - matches:
      - path:
          type: PathPrefix
          value: /
    filters:
      - type: RequestHeaderModifier
        requestHeaderModifier:
          {{- with .Values.gatewayAPI.httpRouteAdvanced.requestHeaderModifier.set }}
          set:
            {{- range . }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
          {{- end }}
          {{- with .Values.gatewayAPI.httpRouteAdvanced.requestHeaderModifier.add }}
          add:
            {{- range . }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
          {{- end }}
          {{- with .Values.gatewayAPI.httpRouteAdvanced.requestHeaderModifier.remove }}
          remove:
            {{- toYaml . | nindent 12 }}
          {{- end }}
    backendRefs:
      - name: {{ include "mychart.fullname" . }}
        port: {{ .Values.service.port }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
gatewayAPI:
  httpRouteAdvanced:
    enabled: false
    gatewayRef: my-gateway
    hostnames:
      - app.example.com

    # HTTP to HTTPS redirect
    redirectHttpToHttps: false

    # URL rewrite configuration
    urlRewrite:
      matchPath: /old-api
      replacePath: /api/v2

    # Request header modification
    requestHeaderModifier:
      set:
        - name: X-Forwarded-Proto
          value: https
      add:
        - name: X-Request-ID
          value: "{{ .Release.Name }}"
      remove:
        - X-Internal-Header
```

### GRPCRoute Resource

**File:** `templates/grpcroute.yaml`

```yaml
{{- if .Values.gatewayAPI.grpcRoute.enabled }}
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
metadata:
  name: {{ include "mychart.fullname" . }}-grpc
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  parentRefs:
    {{- range .Values.gatewayAPI.grpcRoute.parentRefs }}
    - name: {{ .name }}
      {{- with .namespace }}
      namespace: {{ . }}
      {{- end }}
      {{- with .sectionName }}
      sectionName: {{ . }}
      {{- end }}
    {{- end }}
  {{- with .Values.gatewayAPI.grpcRoute.hostnames }}
  hostnames:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
  {{- range .Values.gatewayAPI.grpcRoute.rules }}
  - {{- with .matches }}
    matches:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    backendRefs:
    {{- range .backendRefs }}
    - name: {{ .name }}
      port: {{ .port }}
      {{- with .weight }}
      weight: {{ . }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
gatewayAPI:
  grpcRoute:
    enabled: false
    parentRefs:
      - name: my-gateway
        sectionName: grpc
    hostnames:
      - grpc.example.com
    rules:
      # Route all gRPC traffic
      - backendRefs:
          - name: grpc-service
            port: 50051
            weight: 100

      # Method-specific routing
      - matches:
          - method:
              service: myservice.MyService
              method: MyMethod
        backendRefs:
          - name: grpc-service-v2
            port: 50051
```

### ReferenceGrant Resource

**File:** `templates/referencegrant.yaml`

```yaml
{{- if .Values.gatewayAPI.referenceGrant.enabled }}
apiVersion: gateway.networking.k8s.io/v1
kind: ReferenceGrant
metadata:
  name: {{ include "mychart.fullname" . }}-grant
  namespace: {{ .Values.gatewayAPI.referenceGrant.namespace | default .Release.Namespace }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  from:
  {{- range .Values.gatewayAPI.referenceGrant.from }}
  - group: {{ .group }}
    kind: {{ .kind }}
    namespace: {{ .namespace }}
  {{- end }}
  to:
  {{- range .Values.gatewayAPI.referenceGrant.to }}
  - group: {{ .group | default "" | quote }}
    kind: {{ .kind }}
    {{- with .name }}
    name: {{ . }}
    {{- end }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
gatewayAPI:
  referenceGrant:
    enabled: false
    namespace: ""  # defaults to release namespace
    # Allow Gateway in gateway-ns to reference Secrets in this namespace
    from:
      - group: gateway.networking.k8s.io
        kind: Gateway
        namespace: gateway-ns
    to:
      - group: ""
        kind: Secret
        # name: specific-secret  # optional: restrict to specific secret
```

---

## KEDA

KEDA (Kubernetes Event-driven Autoscaling) provides event-driven autoscaling for Kubernetes workloads. It can scale based on events from various sources like message queues, databases, HTTP requests, and more.

### ScaledObject Resource

**File:** `templates/scaledobject.yaml`

```yaml
{{- if .Values.keda.enabled }}
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.keda.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  scaleTargetRef:
    apiVersion: {{ .Values.keda.scaleTargetRef.apiVersion | default "apps/v1" }}
    kind: {{ .Values.keda.scaleTargetRef.kind | default "Deployment" }}
    name: {{ .Values.keda.scaleTargetRef.name | default (include "mychart.fullname" .) }}
    {{- with .Values.keda.scaleTargetRef.envSourceContainerName }}
    envSourceContainerName: {{ . }}
    {{- end }}
  pollingInterval: {{ .Values.keda.pollingInterval | default 30 }}
  cooldownPeriod: {{ .Values.keda.cooldownPeriod | default 300 }}
  {{- with .Values.keda.idleReplicaCount }}
  idleReplicaCount: {{ . }}
  {{- end }}
  minReplicaCount: {{ .Values.keda.minReplicaCount | default 0 }}
  maxReplicaCount: {{ .Values.keda.maxReplicaCount | default 100 }}
  {{- with .Values.keda.fallback }}
  fallback:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.keda.advanced }}
  advanced:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  triggers:
  {{- range .Values.keda.triggers }}
  - type: {{ .type }}
    {{- with .name }}
    name: {{ . }}
    {{- end }}
    metadata:
      {{- range $key, $value := .metadata }}
      {{ $key }}: {{ $value | quote }}
      {{- end }}
    {{- with .authenticationRef }}
    authenticationRef:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .metricType }}
    metricType: {{ . }}
    {{- end }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
keda:
  enabled: false
  annotations: {}
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ""  # defaults to chart fullname
    envSourceContainerName: ""  # optional: container to source env from
  pollingInterval: 30  # seconds
  cooldownPeriod: 300  # seconds
  idleReplicaCount: 0  # scale to 0 when idle (optional)
  minReplicaCount: 1
  maxReplicaCount: 10
  fallback:
    failureThreshold: 3
    replicas: 2
  advanced:
    restoreToOriginalReplicaCount: true
    horizontalPodAutoscalerConfig:
      name: ""  # custom HPA name
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 300
          policies:
            - type: Percent
              value: 100
              periodSeconds: 15
  triggers:
    # CPU-based scaling
    - type: cpu
      metricType: Utilization
      metadata:
        value: "80"

    # Memory-based scaling
    - type: memory
      metricType: Utilization
      metadata:
        value: "80"

    # Prometheus metrics
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        metricName: http_requests_total
        query: sum(rate(http_requests_total{deployment="mychart"}[2m]))
        threshold: "100"

    # RabbitMQ queue length
    - type: rabbitmq
      metadata:
        host: amqp://rabbitmq:5672
        queueName: myqueue
        queueLength: "50"
      authenticationRef:
        name: rabbitmq-auth

    # Kafka consumer lag
    - type: kafka
      metadata:
        bootstrapServers: kafka:9092
        consumerGroup: my-group
        topic: my-topic
        lagThreshold: "100"

    # Redis list length
    - type: redis
      metadata:
        address: redis:6379
        listName: mylist
        listLength: "10"

    # AWS SQS queue
    - type: aws-sqs-queue
      metadata:
        queueURL: https://sqs.us-east-1.amazonaws.com/123456789/myqueue
        queueLength: "50"
        awsRegion: us-east-1
      authenticationRef:
        name: aws-credentials

    # Cron-based scaling
    - type: cron
      metadata:
        timezone: America/New_York
        start: "0 8 * * 1-5"  # 8 AM weekdays
        end: "0 18 * * 1-5"   # 6 PM weekdays
        desiredReplicas: "10"
```

### ScaledJob Resource

**File:** `templates/scaledjob.yaml`

```yaml
{{- if .Values.keda.scaledJob.enabled }}
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: {{ include "mychart.fullname" . }}-job
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  jobTargetRef:
    parallelism: {{ .Values.keda.scaledJob.parallelism | default 1 }}
    completions: {{ .Values.keda.scaledJob.completions | default 1 }}
    activeDeadlineSeconds: {{ .Values.keda.scaledJob.activeDeadlineSeconds | default 600 }}
    backoffLimit: {{ .Values.keda.scaledJob.backoffLimit | default 6 }}
    template:
      spec:
        {{- with .Values.imagePullSecrets }}
        imagePullSecrets:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        restartPolicy: {{ .Values.keda.scaledJob.restartPolicy | default "Never" }}
        containers:
        - name: {{ .Chart.Name }}-job
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          {{- with .Values.keda.scaledJob.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.keda.scaledJob.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.keda.scaledJob.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.keda.scaledJob.resources | nindent 12 }}
  pollingInterval: {{ .Values.keda.scaledJob.pollingInterval | default 30 }}
  successfulJobsHistoryLimit: {{ .Values.keda.scaledJob.successfulJobsHistoryLimit | default 5 }}
  failedJobsHistoryLimit: {{ .Values.keda.scaledJob.failedJobsHistoryLimit | default 5 }}
  maxReplicaCount: {{ .Values.keda.scaledJob.maxReplicaCount | default 100 }}
  scalingStrategy:
    strategy: {{ .Values.keda.scaledJob.scalingStrategy | default "default" }}
  triggers:
  {{- range .Values.keda.scaledJob.triggers }}
  - type: {{ .type }}
    metadata:
      {{- range $key, $value := .metadata }}
      {{ $key }}: {{ $value | quote }}
      {{- end }}
    {{- with .authenticationRef }}
    authenticationRef:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
keda:
  scaledJob:
    enabled: false
    parallelism: 1
    completions: 1
    activeDeadlineSeconds: 600
    backoffLimit: 6
    restartPolicy: Never
    pollingInterval: 30
    successfulJobsHistoryLimit: 5
    failedJobsHistoryLimit: 5
    maxReplicaCount: 100
    scalingStrategy: default  # default, custom, accurate
    command: []
    args: []
    env: []
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 100m
        memory: 128Mi
    triggers:
      - type: aws-sqs-queue
        metadata:
          queueURL: https://sqs.us-east-1.amazonaws.com/123456789/myqueue
          queueLength: "5"
          awsRegion: us-east-1
```

### TriggerAuthentication Resource

**File:** `templates/triggerauthentication.yaml`

```yaml
{{- if .Values.keda.authentication.enabled }}
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: {{ include "mychart.fullname" . }}-auth
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  {{- with .Values.keda.authentication.secretTargetRef }}
  secretTargetRef:
    {{- range . }}
    - parameter: {{ .parameter }}
      name: {{ .name }}
      key: {{ .key }}
    {{- end }}
  {{- end }}
  {{- with .Values.keda.authentication.env }}
  env:
    {{- range . }}
    - parameter: {{ .parameter }}
      name: {{ .name }}
      {{- with .containerName }}
      containerName: {{ . }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- with .Values.keda.authentication.podIdentity }}
  podIdentity:
    provider: {{ .provider }}
    {{- with .identityId }}
    identityId: {{ . }}
    {{- end }}
  {{- end }}
  {{- with .Values.keda.authentication.hashiCorpVault }}
  hashiCorpVault:
    address: {{ .address }}
    authentication: {{ .authentication }}
    {{- with .role }}
    role: {{ . }}
    {{- end }}
    {{- with .mount }}
    mount: {{ . }}
    {{- end }}
    credential:
      {{- toYaml .credential | nindent 6 }}
    secrets:
      {{- range .secrets }}
      - parameter: {{ .parameter }}
        key: {{ .key }}
        path: {{ .path }}
      {{- end }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
keda:
  authentication:
    enabled: false
    # Secret-based authentication
    secretTargetRef:
      - parameter: connection
        name: rabbitmq-secret
        key: connectionString
      - parameter: password
        name: db-secret
        key: password

    # Environment variable authentication
    env:
      - parameter: awsAccessKeyID
        name: AWS_ACCESS_KEY_ID
      - parameter: awsSecretAccessKey
        name: AWS_SECRET_ACCESS_KEY

    # Pod identity (Azure, AWS IRSA, GCP Workload Identity)
    podIdentity:
      provider: azure  # azure, aws-eks, gcp
      identityId: ""  # optional: specific identity

    # HashiCorp Vault authentication
    hashiCorpVault:
      address: https://vault.example.com
      authentication: token  # token, kubernetes
      role: my-role
      mount: secret
      credential:
        token: vault-token  # or serviceAccount for kubernetes auth
      secrets:
        - parameter: connection
          key: connectionString
          path: secret/data/myapp
```

---

## VerticalPodAutoscaler (VPA)

The VerticalPodAutoscaler automatically adjusts the CPU and memory reservations for pods to help "right-size" your applications.

### VerticalPodAutoscaler Resource

**File:** `templates/vpa.yaml`

```yaml
{{- if .Values.vpa.enabled }}
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.vpa.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  targetRef:
    apiVersion: {{ .Values.vpa.targetRef.apiVersion | default "apps/v1" }}
    kind: {{ .Values.vpa.targetRef.kind | default "Deployment" }}
    name: {{ .Values.vpa.targetRef.name | default (include "mychart.fullname" .) }}
  updatePolicy:
    updateMode: {{ .Values.vpa.updatePolicy.updateMode | default "Auto" }}
    {{- with .Values.vpa.updatePolicy.minReplicas }}
    minReplicas: {{ . }}
    {{- end }}
  {{- with .Values.vpa.resourcePolicy }}
  resourcePolicy:
    containerPolicies:
    {{- range .containerPolicies }}
    - containerName: {{ .containerName | default "*" }}
      {{- with .mode }}
      mode: {{ . }}
      {{- end }}
      {{- with .minAllowed }}
      minAllowed:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .maxAllowed }}
      maxAllowed:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .controlledResources }}
      controlledResources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .controlledValues }}
      controlledValues: {{ . }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- with .Values.vpa.recommenders }}
  recommenders:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
vpa:
  enabled: false
  annotations: {}
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ""  # defaults to chart fullname
  updatePolicy:
    # Auto - VPA assigns resource requests on pod creation and updates on existing pods
    # Recreate - VPA assigns resource requests on pod creation and kills existing pods
    # Initial - VPA only assigns requests on pod creation, never updates
    # Off - VPA does not update pods, only provides recommendations
    updateMode: "Auto"
    minReplicas: 1  # minimum replicas for VPA to act on
  resourcePolicy:
    containerPolicies:
      # Apply to all containers
      - containerName: "*"
        minAllowed:
          cpu: 50m
          memory: 64Mi
        maxAllowed:
          cpu: 2
          memory: 4Gi
        controlledResources:
          - cpu
          - memory
        controlledValues: RequestsAndLimits  # RequestsOnly or RequestsAndLimits

      # Specific container policy
      - containerName: my-container
        mode: Auto  # Auto or Off
        minAllowed:
          cpu: 100m
          memory: 128Mi
        maxAllowed:
          cpu: 1
          memory: 2Gi

  # Custom recommenders (optional, requires VPA 0.11+)
  recommenders:
    - name: custom-recommender
```

### VPA with Recommendation Only

For applications where you want VPA recommendations without automatic updates:

**File:** `templates/vpa-recommendation.yaml`

```yaml
{{- if .Values.vpa.recommendationOnly.enabled }}
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: {{ include "mychart.fullname" . }}-recommendation
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
    vpa-mode: recommendation-only
spec:
  targetRef:
    apiVersion: apps/v1
    kind: {{ .Values.vpa.recommendationOnly.kind | default "Deployment" }}
    name: {{ include "mychart.fullname" . }}
  updatePolicy:
    updateMode: "Off"
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      minAllowed:
        cpu: {{ .Values.vpa.recommendationOnly.minCpu | default "25m" }}
        memory: {{ .Values.vpa.recommendationOnly.minMemory | default "32Mi" }}
      maxAllowed:
        cpu: {{ .Values.vpa.recommendationOnly.maxCpu | default "4" }}
        memory: {{ .Values.vpa.recommendationOnly.maxMemory | default "8Gi" }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
vpa:
  recommendationOnly:
    enabled: false
    kind: Deployment
    minCpu: 25m
    minMemory: 32Mi
    maxCpu: 4
    maxMemory: 8Gi
```

---

## General Best Practices

### 1. Conditional Resource Creation

Always wrap CRD resources in conditional blocks:

```yaml
{{- if .Values.certificate.enabled }}
# CRD resource
{{- end }}
```

### 2. Required Values

Use `required` for critical CRD fields:

```yaml
email: {{ required "certManager.clusterIssuer.acme.email is required!" .Values.certManager.clusterIssuer.acme.email }}
```

### 3. Documentation

Document CRD dependencies in Chart.yaml:

```yaml
annotations:
  operatorDependencies: |
    - name: cert-manager
      version: ">=1.12.0"
      url: https://cert-manager.io/docs/installation/
```

### 4. Default Values

Provide sensible defaults for all CRD fields:

```yaml
certificate:
  enabled: false
  duration: 2160h
  renewBefore: 360h
```

### 5. Version Awareness

Be explicit about API versions:

```yaml
apiVersion: cert-manager.io/v1  # Not v1alpha1 or v1beta1
```

### 6. Helper Usage

Use chart helpers for consistent labeling:

```yaml
metadata:
  name: {{ include "mychart.fullname" . }}-tls
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
```

### 7. Testing

Always test CRD resources with:
- `helm template` to verify rendering
- `helm lint` to check syntax
- `kubectl apply --dry-run=server` to validate against cluster

---

## Resources

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Sealed Secrets](https://sealed-secrets.netlify.app/)
- [External Secrets Operator](https://external-secrets.io/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [KEDA Documentation](https://keda.sh/docs/)
- [VerticalPodAutoscaler Documentation](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
