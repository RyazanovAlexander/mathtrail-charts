{{/*
=======================================================================
  mathtrail-service-lib :: _serviceaccount.tpl
  ServiceAccount + automatic RBAC for init-container (wait-for-migration).
=======================================================================
*/}}

{{- define "mathtrail-service-lib.serviceAccount" -}}
{{- if (dig "serviceAccount" "create" true .Values) }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "mathtrail-service-lib.serviceAccountName" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
  {{- with (dig "serviceAccount" "annotations" dict .Values) }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ dig "serviceAccount" "automount" true .Values }}
{{- end }}
{{- end -}}
