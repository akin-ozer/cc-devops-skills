# Kubernetes Resource Templates for Helm

Reference templates for common Kubernetes resources with Helm templating.

## Table of Contents

- [Workload Resources](#workload-resources)
  - [Deployment](#deployment)
  - [StatefulSet](#statefulset)
  - [DaemonSet](#daemonset)
  - [Job](#job)
  - [CronJob](#cronjob)
- [Service Resources](#service-resources)
  - [Service](#service)
  - [Ingress](#ingress)
- [Configuration Resources](#configuration-resources)
  - [ConfigMap](#configmap)
  - [Secret](#secret)
- [Storage Resources](#storage-resources)
  - [PersistentVolumeClaim](#persistentvolumeclaim)
- [RBAC Resources](#rbac-resources)
  - [ServiceAccount](#serviceaccount)
  - [Role](#role)
  - [RoleBinding](#rolebinding)
  - [ClusterRole](#clusterrole)
  - [ClusterRoleBinding](#clusterrolebinding)
- [Network Resources](#network-resources)
  - [NetworkPolicy](#networkpolicy)
- [Autoscaling Resources](#autoscaling-resources)
  - [HorizontalPodAutoscaler](#horizontalpodautoscaler)
  - [PodDisruptionBudget](#poddisruptionbudget)

---

## Workload Resources

### Deployment

**File:** `templates/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.deployment.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  {{- with .Values.deployment.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}
      {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "mychart.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "mychart.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      {{- with .Values.initContainers }}
      initContainers:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
      - name: {{ .Chart.Name }}
        securityContext:
          {{- toYaml .Values.securityContext | nindent 12 }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        {{- with .Values.command }}
        command:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        {{- with .Values.args }}
        args:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
        {{- range .Values.extraPorts }}
        - name: {{ .name }}
          containerPort: {{ .containerPort }}
          protocol: {{ .protocol | default "TCP" }}
        {{- end }}
        {{- with .Values.livenessProbe }}
        livenessProbe:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        {{- with .Values.readinessProbe }}
        readinessProbe:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        {{- with .Values.startupProbe }}
        startupProbe:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
        {{- with .Values.env }}
        env:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        {{- with .Values.envFrom }}
        envFrom:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        {{- with .Values.volumeMounts }}
        volumeMounts:
          {{- toYaml . | nindent 12 }}
        {{- end }}
      {{- with .Values.sidecars }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.priorityClassName }}
      priorityClassName: {{ . }}
      {{- end }}
```

**Corresponding values.yaml:**

```yaml
replicaCount: 1

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: ""

imagePullSecrets: []

deployment:
  annotations: {}
  strategy: {}
    # type: RollingUpdate
    # rollingUpdate:
    #   maxSurge: 1
    #   maxUnavailable: 0

podAnnotations: {}
podLabels: {}

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true

service:
  targetPort: 8080

extraPorts: []

command: []
args: []

livenessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

startupProbe: {}

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi

env: []
envFrom: []

volumeMounts: []
volumes: []

initContainers: []
sidecars: []

nodeSelector: {}
affinity: {}
tolerations: []
priorityClassName: ""
```

---

### StatefulSet

**File:** `templates/statefulset.yaml`

```yaml
{{- if eq .Values.workloadType "StatefulSet" }}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  serviceName: {{ include "mychart.fullname" . }}-headless
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
  {{- with .Values.statefulset.updateStrategy }}
  updateStrategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.statefulset.podManagementPolicy }}
  podManagementPolicy: {{ . }}
  {{- end }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "mychart.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "mychart.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
      - name: {{ .Chart.Name }}
        securityContext:
          {{- toYaml .Values.securityContext | nindent 12 }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
        volumeMounts:
        - name: data
          mountPath: {{ .Values.persistence.mountPath }}
        {{- with .Values.volumeMounts }}
          {{- toYaml . | nindent 12 }}
        {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  {{- if .Values.persistence.enabled }}
  volumeClaimTemplates:
  - metadata:
      name: data
      {{- with .Values.persistence.annotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      accessModes:
        {{- range .Values.persistence.accessModes }}
        - {{ . | quote }}
        {{- end }}
      {{- with .Values.persistence.storageClass }}
      storageClassName: {{ . }}
      {{- end }}
      resources:
        requests:
          storage: {{ .Values.persistence.size }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
workloadType: StatefulSet

statefulset:
  updateStrategy:
    type: RollingUpdate
  podManagementPolicy: OrderedReady

persistence:
  enabled: true
  accessModes:
    - ReadWriteOnce
  size: 10Gi
  storageClass: ""
  mountPath: /data
  annotations: {}
```

---

### DaemonSet

**File:** `templates/daemonset.yaml`

```yaml
{{- if eq .Values.workloadType "DaemonSet" }}
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
  {{- with .Values.daemonset.updateStrategy }}
  updateStrategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "mychart.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "mychart.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      hostNetwork: {{ .Values.daemonset.hostNetwork }}
      {{- if .Values.daemonset.hostPID }}
      hostPID: true
      {{- end }}
      containers:
      - name: {{ .Chart.Name }}
        securityContext:
          {{- toYaml .Values.securityContext | nindent 12 }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
        volumeMounts:
        - name: host
          mountPath: /host
          readOnly: true
        {{- with .Values.volumeMounts }}
          {{- toYaml . | nindent 12 }}
        {{- end }}
      volumes:
      - name: host
        hostPath:
          path: /
      {{- with .Values.volumes }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
workloadType: DaemonSet

daemonset:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  hostNetwork: false
  hostPID: false
```

---

### Job

**File:** `templates/job.yaml`

```yaml
{{- if eq .Values.workloadType "Job" }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.job.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with .Values.job.backoffLimit }}
  backoffLimit: {{ . }}
  {{- end }}
  {{- with .Values.job.completions }}
  completions: {{ . }}
  {{- end }}
  {{- with .Values.job.parallelism }}
  parallelism: {{ . }}
  {{- end }}
  {{- with .Values.job.activeDeadlineSeconds }}
  activeDeadlineSeconds: {{ . }}
  {{- end }}
  {{- with .Values.job.ttlSecondsAfterFinished }}
  ttlSecondsAfterFinished: {{ . }}
  {{- end }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "mychart.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      restartPolicy: {{ .Values.job.restartPolicy }}
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "mychart.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
      - name: {{ .Chart.Name }}
        securityContext:
          {{- toYaml .Values.securityContext | nindent 12 }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        {{- with .Values.command }}
        command:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        {{- with .Values.args }}
        args:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
        {{- with .Values.env }}
        env:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        {{- with .Values.volumeMounts }}
        volumeMounts:
          {{- toYaml . | nindent 12 }}
        {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
workloadType: Job

job:
  annotations: {}
  backoffLimit: 3
  completions: 1
  parallelism: 1
  activeDeadlineSeconds: null
  ttlSecondsAfterFinished: 86400
  restartPolicy: Never

command: []
args: []
```

---

### CronJob

**File:** `templates/cronjob.yaml`

```yaml
{{- if eq .Values.workloadType "CronJob" }}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  schedule: {{ .Values.cronjob.schedule | quote }}
  {{- with .Values.cronjob.concurrencyPolicy }}
  concurrencyPolicy: {{ . }}
  {{- end }}
  {{- with .Values.cronjob.failedJobsHistoryLimit }}
  failedJobsHistoryLimit: {{ . }}
  {{- end }}
  {{- with .Values.cronjob.successfulJobsHistoryLimit }}
  successfulJobsHistoryLimit: {{ . }}
  {{- end }}
  {{- with .Values.cronjob.startingDeadlineSeconds }}
  startingDeadlineSeconds: {{ . }}
  {{- end }}
  {{- if .Values.cronjob.suspend }}
  suspend: true
  {{- end }}
  jobTemplate:
    metadata:
      labels:
        {{- include "mychart.labels" . | nindent 8 }}
    spec:
      {{- with .Values.cronjob.backoffLimit }}
      backoffLimit: {{ . }}
      {{- end }}
      {{- with .Values.cronjob.ttlSecondsAfterFinished }}
      ttlSecondsAfterFinished: {{ . }}
      {{- end }}
      template:
        metadata:
          {{- with .Values.podAnnotations }}
          annotations:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          labels:
            {{- include "mychart.labels" . | nindent 12 }}
            {{- with .Values.podLabels }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
        spec:
          restartPolicy: {{ .Values.cronjob.restartPolicy }}
          {{- with .Values.imagePullSecrets }}
          imagePullSecrets:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          serviceAccountName: {{ include "mychart.serviceAccountName" . }}
          securityContext:
            {{- toYaml .Values.podSecurityContext | nindent 12 }}
          containers:
          - name: {{ .Chart.Name }}
            securityContext:
              {{- toYaml .Values.securityContext | nindent 16 }}
            image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
            imagePullPolicy: {{ .Values.image.pullPolicy }}
            {{- with .Values.command }}
            command:
              {{- toYaml . | nindent 16 }}
            {{- end }}
            {{- with .Values.args }}
            args:
              {{- toYaml . | nindent 16 }}
            {{- end }}
            resources:
              {{- toYaml .Values.resources | nindent 16 }}
            {{- with .Values.env }}
            env:
              {{- toYaml . | nindent 16 }}
            {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
workloadType: CronJob

cronjob:
  schedule: "0 0 * * *"
  concurrencyPolicy: Forbid
  failedJobsHistoryLimit: 1
  successfulJobsHistoryLimit: 3
  startingDeadlineSeconds: null
  suspend: false
  backoffLimit: 3
  ttlSecondsAfterFinished: 86400
  restartPolicy: Never
```

---

## Service Resources

### Service

**File:** `templates/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type }}
  {{- if and (eq .Values.service.type "LoadBalancer") .Values.service.loadBalancerIP }}
  loadBalancerIP: {{ .Values.service.loadBalancerIP }}
  {{- end }}
  {{- with .Values.service.loadBalancerSourceRanges }}
  loadBalancerSourceRanges:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.service.externalIPs }}
  externalIPs:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if .Values.service.sessionAffinity }}
  sessionAffinity: {{ .Values.service.sessionAffinity }}
  {{- if .Values.service.sessionAffinityConfig }}
  sessionAffinityConfig:
    {{- toYaml .Values.service.sessionAffinityConfig | nindent 4 }}
  {{- end }}
  {{- end }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
      name: http
      {{- if and (eq .Values.service.type "NodePort") .Values.service.nodePort }}
      nodePort: {{ .Values.service.nodePort }}
      {{- end }}
    {{- range .Values.service.extraPorts }}
    - port: {{ .port }}
      targetPort: {{ .targetPort }}
      protocol: {{ .protocol | default "TCP" }}
      name: {{ .name }}
      {{- if and (eq $.Values.service.type "NodePort") .nodePort }}
      nodePort: {{ .nodePort }}
      {{- end }}
    {{- end }}
  selector:
    {{- include "mychart.selectorLabels" . | nindent 4 }}
```

**Headless Service (for StatefulSets):**

**File:** `templates/service-headless.yaml`

```yaml
{{- if eq .Values.workloadType "StatefulSet" }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mychart.fullname" . }}-headless
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
      name: http
  selector:
    {{- include "mychart.selectorLabels" . | nindent 4 }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
service:
  type: ClusterIP
  port: 80
  targetPort: 8080
  nodePort: null
  annotations: {}
  loadBalancerIP: ""
  loadBalancerSourceRanges: []
  externalIPs: []
  sessionAffinity: None
  sessionAffinityConfig: {}
  extraPorts: []
  # - name: metrics
  #   port: 9090
  #   targetPort: 9090
  #   protocol: TCP
```

---

### Ingress

**File:** `templates/ingress.yaml`

```yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "mychart.fullname" $ }}
                port:
                  {{- if .servicePort }}
                  number: {{ .servicePort }}
                  {{- else }}
                  number: {{ $.Values.service.port }}
                  {{- end }}
          {{- end }}
    {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
ingress:
  enabled: false
  className: "nginx"
  annotations: {}
    # cert-manager.io/cluster-issuer: letsencrypt-prod
    # nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # nginx.ingress.kubernetes.io/rate-limit: "100"
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: Prefix
          # servicePort: 80
  tls: []
  #  - secretName: chart-example-tls
  #    hosts:
  #      - chart-example.local
```

---

## Configuration Resources

### ConfigMap

**File:** `templates/configmap.yaml`

```yaml
{{- if .Values.configMap.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.configMap.data }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
```

**With files:**

```yaml
{{- if .Values.configMap.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.configMap.data }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- with .Values.configMap.files }}
  {{- range $key, $value := . }}
  {{ $key }}: |
    {{- $value | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
configMap:
  enabled: false
  data: {}
    # KEY: "value"
  files: {}
    # config.yaml: |
    #   server:
    #     port: 8080
```

---

### Secret

**File:** `templates/secret.yaml`

```yaml
{{- if .Values.secret.enabled }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
type: {{ .Values.secret.type }}
{{- if .Values.secret.stringData }}
stringData:
  {{- range $key, $value := .Values.secret.stringData }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
{{- if .Values.secret.data }}
data:
  {{- range $key, $value := .Values.secret.data }}
  {{ $key }}: {{ $value }}
  {{- end }}
{{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
secret:
  enabled: false
  type: Opaque
  stringData: {}
    # API_KEY: "secret-key"
  data: {}
    # PASSWORD: cGFzc3dvcmQ=  # base64 encoded
```

---

## Storage Resources

### PersistentVolumeClaim

**File:** `templates/pvc.yaml`

```yaml
{{- if and .Values.persistence.enabled (not (eq .Values.workloadType "StatefulSet")) }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.persistence.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  accessModes:
    {{- range .Values.persistence.accessModes }}
    - {{ . | quote }}
    {{- end }}
  resources:
    requests:
      storage: {{ .Values.persistence.size | quote }}
  {{- if .Values.persistence.storageClass }}
  {{- if (eq "-" .Values.persistence.storageClass) }}
  storageClassName: ""
  {{- else }}
  storageClassName: {{ .Values.persistence.storageClass | quote }}
  {{- end }}
  {{- end }}
  {{- with .Values.persistence.selector }}
  selector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
persistence:
  enabled: false
  accessModes:
    - ReadWriteOnce
  size: 10Gi
  storageClass: ""
  annotations: {}
  selector: {}
```

---

## RBAC Resources

### ServiceAccount

**File:** `templates/serviceaccount.yaml`

```yaml
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "mychart.serviceAccountName" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.serviceAccount.automount }}
{{- with .Values.serviceAccount.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
```

---

### Role

**File:** `templates/role.yaml`

```yaml
{{- if .Values.rbac.create }}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
rules:
{{- range .Values.rbac.rules }}
- apiGroups:
  {{- range .apiGroups }}
    - {{ . | quote }}
  {{- end }}
  resources:
  {{- range .resources }}
    - {{ . | quote }}
  {{- end }}
  verbs:
  {{- range .verbs }}
    - {{ . | quote }}
  {{- end }}
  {{- with .resourceNames }}
  resourceNames:
  {{- range . }}
    - {{ . | quote }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}
```

---

### RoleBinding

**File:** `templates/rolebinding.yaml`

```yaml
{{- if .Values.rbac.create }}
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "mychart.fullname" . }}
subjects:
- kind: ServiceAccount
  name: {{ include "mychart.serviceAccountName" . }}
  namespace: {{ .Release.Namespace }}
{{- end }}
```

---

### ClusterRole

**File:** `templates/clusterrole.yaml`

```yaml
{{- if .Values.rbac.createClusterRole }}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
rules:
{{- range .Values.rbac.clusterRules }}
- apiGroups:
  {{- range .apiGroups }}
    - {{ . | quote }}
  {{- end }}
  resources:
  {{- range .resources }}
    - {{ . | quote }}
  {{- end }}
  verbs:
  {{- range .verbs }}
    - {{ . | quote }}
  {{- end }}
{{- end }}
{{- end }}
```

---

### ClusterRoleBinding

**File:** `templates/clusterrolebinding.yaml`

```yaml
{{- if .Values.rbac.createClusterRole }}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ include "mychart.fullname" . }}
subjects:
- kind: ServiceAccount
  name: {{ include "mychart.serviceAccountName" . }}
  namespace: {{ .Release.Namespace }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
rbac:
  create: false
  createClusterRole: false
  rules: []
  # - apiGroups: [""]
  #   resources: ["configmaps", "secrets"]
  #   verbs: ["get", "list", "watch"]
  clusterRules: []
  # - apiGroups: [""]
  #   resources: ["nodes"]
  #   verbs: ["get", "list"]
```

---

## Network Resources

### NetworkPolicy

**File:** `templates/networkpolicy.yaml`

```yaml
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
  policyTypes:
  {{- range .Values.networkPolicy.policyTypes }}
    - {{ . }}
  {{- end }}
  {{- with .Values.networkPolicy.ingress }}
  ingress:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.networkPolicy.egress }}
  egress:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
networkPolicy:
  enabled: false
  policyTypes:
    - Ingress
    - Egress
  ingress: []
  # - from:
  #   - namespaceSelector:
  #       matchLabels:
  #         name: allowed-namespace
  #   ports:
  #   - protocol: TCP
  #     port: 8080
  egress: []
  # - to:
  #   - podSelector: {}
  #   ports:
  #   - protocol: TCP
  #     port: 53
```

---

## Autoscaling Resources

### HorizontalPodAutoscaler

**File:** `templates/hpa.yaml`

```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: {{ .Values.workloadType | default "Deployment" }}
    name: {{ include "mychart.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  {{- with .Values.autoscaling.behavior }}
  behavior:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
    {{- with .Values.autoscaling.customMetrics }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: null
  behavior: {}
  # behavior:
  #   scaleDown:
  #     stabilizationWindowSeconds: 300
  #     policies:
  #     - type: Percent
  #       value: 50
  #       periodSeconds: 15
  customMetrics: []
  # - type: Pods
  #   pods:
  #     metric:
  #       name: packets-per-second
  #     target:
  #       type: AverageValue
  #       averageValue: 1k
```

---

### PodDisruptionBudget

**File:** `templates/pdb.yaml`

```yaml
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  {{- if .Values.podDisruptionBudget.minAvailable }}
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  {{- end }}
  {{- if .Values.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ .Values.podDisruptionBudget.maxUnavailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
{{- end }}
```

**Corresponding values.yaml:**

```yaml
podDisruptionBudget:
  enabled: false
  minAvailable: 1
  maxUnavailable: null
```

---

## Usage Notes

1. Replace `mychart` with your actual chart name throughout all templates
2. Include standard helpers from `_helpers.tpl`
3. Use `toYaml` for complex nested structures
4. Always provide sensible defaults in values.yaml
5. Use `with` blocks for optional sections
6. Add checksums for ConfigMaps and Secrets to trigger pod restarts
7. Document all values with comments