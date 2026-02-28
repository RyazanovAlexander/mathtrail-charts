{{/*
=======================================================================
  mathtrail-service-lib :: _vso-dynamic-secret.tpl
  VaultDynamicSecret CR (secrets.hashicorp.com/v1beta1) for VSO.
  Enabled by vso.enabled=true in service values.
  VSO watches this CR and creates/rotates the DB credentials K8s Secret.
  rolloutRestartTargets ensures pods restart when credentials rotate
  (required for pgxpool / GORM which build DSN once at startup).
=======================================================================
*/}}

{{- define "mathtrail-service-lib.vaultDynamicSecret" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if dig "vso" "enabled" false $v }}
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-db
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
spec:
  vaultAuthRef: {{ include "mathtrail-service-lib.fullname" . }}
  mount: database
  path: creds/{{ dig "vso" "dbRole" (printf "%s-role" (include "mathtrail-service-lib.fullname" .)) $v }}
  renewalPercent: 85
  destination:
    name: {{ dig "vso" "secretName" (printf "%s-db-secret" (include "mathtrail-service-lib.fullname" .)) $v }}
    create: true
    labels:
      {{- include "mathtrail-service-lib.labels" . | nindent 6 }}
  rolloutRestartTargets:
    - kind: Deployment
      name: {{ include "mathtrail-service-lib.fullname" . }}
{{- end }}
{{- end -}}
