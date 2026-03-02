{{/*
=======================================================================
  mathtrail-service-lib :: _vso-dynamic-secret.tpl
  VaultDynamicSecret CR (secrets.hashicorp.com/v1beta1) for VSO.
  Enabled by vso.enabled=true in service values.
  VSO watches this CR and creates/rotates the DB credentials K8s Secret.
  Set vso.rolloutRestart=true to trigger a Deployment rolling restart on
  credential rotation (legacy fallback). Default false — services that
  implement in-process pool rotation (DynamicPool) do not need a restart.
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
  {{- if dig "vso" "rolloutRestart" false $v }}
  rolloutRestartTargets:
    - kind: Deployment
      name: {{ include "mathtrail-service-lib.fullname" . }}
  {{- end }}
{{- end }}
{{- end -}}
