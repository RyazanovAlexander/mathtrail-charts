{{/*
=======================================================================
  mathtrail-service-lib :: _helpers.tpl
  Common helper templates for the library chart.
=======================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "mathtrail-service-lib.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this
(by the DNS naming spec). If release name contains chart name it will be used
as a full name.
*/}}
{{- define "mathtrail-service-lib.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mathtrail-service-lib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mathtrail-service-lib.labels" -}}
helm.sh/chart: {{ include "mathtrail-service-lib.chart" . }}
{{ include "mathtrail-service-lib.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: mathtrail
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mathtrail-service-lib.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mathtrail-service-lib.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "mathtrail-service-lib.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mathtrail-service-lib.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Dapr annotations — always injected when dapr.enabled is true.
*/}}
{{- define "mathtrail-service-lib.daprAnnotations" -}}
{{- if .Values.dapr.enabled }}
dapr.io/enabled: "true"
dapr.io/app-id: {{ .Values.dapr.appId | default (include "mathtrail-service-lib.fullname" .) }}
dapr.io/app-port: {{ .Values.service.port | quote }}
{{- if .Values.dapr.appProtocol }}
dapr.io/app-protocol: {{ .Values.dapr.appProtocol | quote }}
{{- end }}
{{- if .Values.dapr.logLevel }}
dapr.io/log-level: {{ .Values.dapr.logLevel | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate that required resources are set.
Using the fail function is the best way to enforce quality.
*/}}
{{- define "mathtrail-service-lib.validateResources" -}}
{{- if not .Values.resources }}
{{- fail "FATAL: .Values.resources must be defined. Set requests and limits for CPU/Memory." }}
{{- end }}
{{- if not .Values.resources.requests }}
{{- fail "FATAL: .Values.resources.requests must be defined (cpu, memory)." }}
{{- end }}
{{- if not .Values.resources.limits }}
{{- fail "FATAL: .Values.resources.limits must be defined (cpu, memory)." }}
{{- end }}
{{- end }}

{{/*
Validate image configuration.
*/}}
{{- define "mathtrail-service-lib.validateImage" -}}
{{- if not .Values.image.repository }}
{{- fail "FATAL: .Values.image.repository must be specified." }}
{{- end }}
{{- if not .Values.image.tag }}
{{- if not .Chart.AppVersion }}
{{- fail "FATAL: Either .Values.image.tag or .Chart.AppVersion must be set." }}
{{- end }}
{{- end }}
{{- end }}
