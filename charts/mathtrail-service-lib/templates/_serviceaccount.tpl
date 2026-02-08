{{/*
=======================================================================
  mathtrail-service-lib :: _serviceaccount.tpl
  ServiceAccount + automatic RBAC for init-container (wait-for-migration).
=======================================================================
*/}}

{{- define "mathtrail-service-lib.serviceAccount" -}}
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "mathtrail-service-lib.serviceAccountName" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.serviceAccount.automount | default true }}
{{- end }}
{{- end -}}
