{{/*
=======================================================================
  mathtrail-service-lib :: _job.tpl
  Migration Job template — runs BEFORE the main deployment via Helm Hooks.
  Ensures the DB schema is updated before the new code version starts.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.migrationJob" -}}
{{- if .Values.migration.enabled }}
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
  backoffLimit: {{ .Values.migration.backoffLimit | default 3 }}
  ttlSecondsAfterFinished: {{ .Values.migration.ttlSecondsAfterFinished | default 300 }}
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
        runAsNonRoot: {{ .Values.podSecurityContext.runAsNonRoot | default true }}
        {{- if .Values.podSecurityContext.fsGroup }}
        fsGroup: {{ .Values.podSecurityContext.fsGroup }}
        {{- end }}
      containers:
        - name: migrate
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}
          command:
            {{- toYaml (.Values.migration.command | default (list "./migrate")) | nindent 12 }}
          {{- with .Values.migration.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          envFrom:
            {{- if .Values.configMap.enabled }}
            - configMapRef:
                name: {{ include "mathtrail-service-lib.fullname" . }}-env
            {{- end }}
          {{- with .Values.migration.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.migration.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: {{ .Values.securityContext.readOnlyRootFilesystem | default true }}
            runAsNonRoot: {{ .Values.securityContext.runAsNonRoot | default true }}
          resources:
            requests:
              cpu: {{ .Values.migration.resources.requests.cpu | default "50m" }}
              memory: {{ .Values.migration.resources.requests.memory | default "64Mi" }}
            limits:
              cpu: {{ .Values.migration.resources.limits.cpu | default "200m" }}
              memory: {{ .Values.migration.resources.limits.memory | default "256Mi" }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      restartPolicy: {{ .Values.migration.restartPolicy | default "OnFailure" }}
{{- end }}
{{- end -}}
