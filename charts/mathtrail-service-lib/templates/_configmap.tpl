{{/*
=======================================================================
  mathtrail-service-lib :: _configmap.tpl
  ConfigMap for common microservice environment settings.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.configMap" -}}
{{- if .Values.configMap.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-env
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.configMap.data }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
{{- end -}}
