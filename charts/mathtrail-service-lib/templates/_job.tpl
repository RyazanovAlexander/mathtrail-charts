{{/*
=======================================================================
  mathtrail-service-lib :: _job.tpl
  Migration Job template — runs BEFORE the main deployment via Helm Hooks.
  Ensures the DB schema is updated before the new code version starts.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.migrationJob" -}}
{{- if (dig "migration" "enabled" false .Values) }}
{{ include "mathtrail-service-lib.validateImage" . }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-migrate
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  backoffLimit: {{ dig "migration" "backoffLimit" 3 .Values }}
  ttlSecondsAfterFinished: {{ dig "migration" "ttlSecondsAfterFinished" 300 .Values }}
  template:
    metadata:
      labels:
        {{- include "mathtrail-service-lib.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: migration
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        runAsNonRoot: {{ dig "podSecurityContext" "runAsNonRoot" true .Values }}
        {{- with (dig "podSecurityContext" "fsGroup" nil .Values) }}
        fsGroup: {{ . }}
        {{- end }}
      containers:
        - name: migrate
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ dig "image" "pullPolicy" "IfNotPresent" .Values }}
          command:
            {{- toYaml (dig "migration" "command" (list "./migrate") .Values) | nindent 12 }}
          {{- with (dig "migration" "args" list .Values) }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          envFrom:
            {{- if (dig "configMap" "enabled" false .Values) }}
            - configMapRef:
                name: {{ include "mathtrail-service-lib.fullname" . }}-env
            {{- end }}
          {{- with (dig "migration" "env" list .Values) }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with (dig "migration" "envFrom" list .Values) }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: {{ dig "securityContext" "readOnlyRootFilesystem" true .Values }}
            runAsNonRoot: {{ dig "securityContext" "runAsNonRoot" true .Values }}
          resources:
            requests:
              cpu: {{ dig "migration" "resources" "requests" "cpu" "50m" .Values }}
              memory: {{ dig "migration" "resources" "requests" "memory" "64Mi" .Values }}
            limits:
              cpu: {{ dig "migration" "resources" "limits" "cpu" "200m" .Values }}
              memory: {{ dig "migration" "resources" "limits" "memory" "256Mi" .Values }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      restartPolicy: {{ dig "migration" "restartPolicy" "OnFailure" .Values }}
{{- end }}
{{- end -}}
