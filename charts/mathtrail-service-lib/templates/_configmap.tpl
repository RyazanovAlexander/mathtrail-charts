{{/*
=======================================================================
  mathtrail-service-lib :: _configmap.tpl
  ConfigMap for common microservice environment settings.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.configMap" -}}
{{- if (dig "configMap" "enabled" false .Values) }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-env
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
data:
  {{- range $key, $value := (dig "configMap" "data" dict .Values) }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
{{- end -}}
