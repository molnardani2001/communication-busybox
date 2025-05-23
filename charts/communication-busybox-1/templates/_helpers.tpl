{{/*
Expand the name of the chart.
*/}}
{{- define "communication-busybox-1.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "communication-busybox-1.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "communication-busybox-1.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "communication-busybox-1.labels" -}}
helm.sh/chart: {{ include "communication-busybox-1.chart" . }}
{{ include "communication-busybox-1.selectorLabels" . }}
{{/*
custom label to secure services only with the below label
*/}}
service-istio-secure: "true"
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: communication-busybox-1
{{- end }}

{{- define "communication-busybox-1.annotations" -}}
sidecar.istio.io/inject: "true"
sidecar.istio.io/userVolume: {{ include "communication-busybox-1.service-mesh-user-volume" . | fromYaml | toJson | quote }}
sidecar.istio.io/userVolumeMount: {{ include "communication-busybox-1.service-mesh-user-volume-mount" . | fromYaml | toJson | quote }}
{{- end -}}

{{- define "communication-busybox-1.service-mesh-user-volume" }}
istio-certs:
  secret:
    secretName: istio-shared-cert
    optional: true
istio-ca-cert:
  secret:
    secretName: istio-ca-cert
    optional: true
{{- end -}}

{{- define "communication-busybox-1.service-mesh-user-volume-mount" }}
istio-certs:
  mountPath: "/etc/certs"
  readOnly: true
istio-ca-cert:
  mountPath: "/etc/certs/ca"
  readOnly: true
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "communication-busybox-1.selectorLabels" -}}
app.kubernetes.io/name: {{ include "communication-busybox-1.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "communication-busybox-1.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "communication-busybox-1.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "communication-busybox-1.extractKafkaTopics" -}}
  {{- $topics := list -}}
  {{- range $key, $value := . -}}
    {{- if kindIs "map" $value -}}
      {{- if hasKey $value "name" -}}
        {{- $topics = append $topics $value.name -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- join "," $topics -}}
{{- end -}}

{{- define "communication-busybox-1.extractServiceHosts" -}}
 {{- $hosts := list -}}
 {{- range $key, $value := . -}}
    {{- if kindIs "map" $value -}}
      {{- if hasKey $value "host" -}}
        {{- $hosts = append $hosts $value.host -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- join "," $hosts -}}
{{- end -}}

{{- define "communication-busybox-1.getJaegerHost" -}}
{{- if ((.Values.global).jaeger).host -}}
{{ print .Values.global.jaeger.host }}
{{- else if (.Values.jaeger).host -}}
{{ print .Values.jaeger.host }}
{{- else -}}
{{ print "svc.cluster.local.default" }}
{{- end -}}
{{- end -}}

{{- define "communication-busybox-1.getJaegerPort" -}}
{{- if ((.Values.global).jaeger).port -}}
{{ print .Values.global.jaeger.port }}
{{- else if (.Values.jaeger).port -}}
{{ print .Values.jaeger.port }}
{{- else -}}
{{ print "8080" }}
{{- end -}}
{{- end -}}