{{/*
=======================================================================
  mathtrail-service-lib :: _serviceaccount.tpl
  ServiceAccount + automatic RBAC for init-container (wait-for-migration).
=======================================================================
*/}}

{{- define "mathtrail-service-lib.serviceAccount" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if $v.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "mathtrail-service-lib.serviceAccountName" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
  {{- $hasAnnotations := or $v.vaultDbConfig.enabled $v.serviceAccount.annotations }}
  {{- if $hasAnnotations }}
  annotations:
    {{- if $v.vaultDbConfig.enabled }}
    # Pre-install hook so the SA exists before the vault-db-config Job (weight -5)
    # runs on fresh installs where no release resources have been created yet.
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-10"
    "helm.sh/hook-delete-policy": before-hook-creation
    {{- end }}
    {{- with $v.serviceAccount.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
automountServiceAccountToken: {{ $v.serviceAccount.automount }}
{{- end }}
{{- end -}}
