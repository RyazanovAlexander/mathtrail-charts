{{/*
=======================================================================
  mathtrail-service-lib :: _vso-vault-auth.tpl
  VaultAuth CR (secrets.hashicorp.com/v1beta1) for Vault Secrets Operator.
  Enabled by vso.enabled=true in service values.
  VSO uses this CR to authenticate to Vault on behalf of the service.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.vaultAuth" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if dig "vso" "enabled" false $v }}
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
spec:
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: {{ dig "vso" "vaultRole" (include "mathtrail-service-lib.fullname" .) $v }}
    serviceAccount: {{ include "mathtrail-service-lib.serviceAccountName" . }}
    audiences:
      - vault
{{- end }}
{{- end -}}
