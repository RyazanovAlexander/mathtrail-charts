{{/*
=======================================================================
  mathtrail-service-lib :: _deployment.tpl
  Main Deployment with:
    - Init Container waiting for migration completion
    - Dapr Sidecar integration
    - Mandatory probe contract (Startup/Liveness/Readiness)
    - Security Context
    - Resource Requests & Limits (mandatory, validated)
    - Graceful Shutdown (preStop hook)
=======================================================================
*/}}

{{- define "mathtrail-service-lib.deployment" -}}
{{ include "mathtrail-service-lib.validateResources" . }}
{{ include "mathtrail-service-lib.validateImage" . }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount | default 1 }}
  {{- end }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      {{- include "mathtrail-service-lib.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- include "mathtrail-service-lib.daprAnnotations" . | nindent 8 }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "mathtrail-service-lib.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "mathtrail-service-lib.serviceAccountName" . }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds | default 30 }}
      securityContext:
        runAsNonRoot: {{ .Values.podSecurityContext.runAsNonRoot | default true }}
        {{- if .Values.podSecurityContext.fsGroup }}
        fsGroup: {{ .Values.podSecurityContext.fsGroup }}
        {{- end }}
        {{- if .Values.podSecurityContext.runAsUser }}
        runAsUser: {{ .Values.podSecurityContext.runAsUser }}
        {{- end }}
        {{- if .Values.podSecurityContext.runAsGroup }}
        runAsGroup: {{ .Values.podSecurityContext.runAsGroup }}
        {{- end }}

      {{/* Init container: wait for migration completion */}}
      {{- if .Values.migration.enabled }}
      initContainers:
        - name: wait-for-migration
          image: {{ .Values.migration.waitImage | default "bitnami/kubectl:latest" }}
          command:
            - "/bin/sh"
            - "-c"
            - "kubectl wait --for=condition=complete job/{{ include "mathtrail-service-lib.fullname" . }}-migrate --timeout={{ .Values.migration.waitTimeout | default "120s" }}"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
          resources:
            requests:
              cpu: "10m"
              memory: "32Mi"
            limits:
              cpu: "50m"
              memory: "64Mi"
      {{- end }}

      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP

          {{/* ---- Probe contract ---- */}}
          startupProbe:
            httpGet:
              path: {{ .Values.probes.startup.path | default "/health/startup" }}
              port: http
            initialDelaySeconds: {{ .Values.probes.startup.initialDelaySeconds | default 0 }}
            periodSeconds: {{ .Values.probes.startup.periodSeconds | default 5 }}
            failureThreshold: {{ .Values.probes.startup.failureThreshold | default 30 }}
            timeoutSeconds: {{ .Values.probes.startup.timeoutSeconds | default 3 }}

          livenessProbe:
            httpGet:
              path: {{ .Values.probes.liveness.path | default "/health/liveness" }}
              port: http
            initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds | default 0 }}
            periodSeconds: {{ .Values.probes.liveness.periodSeconds | default 10 }}
            failureThreshold: {{ .Values.probes.liveness.failureThreshold | default 3 }}
            timeoutSeconds: {{ .Values.probes.liveness.timeoutSeconds | default 3 }}

          readinessProbe:
            httpGet:
              path: {{ .Values.probes.readiness.path | default "/health/ready" }}
              port: http
            initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds | default 0 }}
            periodSeconds: {{ .Values.probes.readiness.periodSeconds | default 10 }}
            failureThreshold: {{ .Values.probes.readiness.failureThreshold | default 3 }}
            timeoutSeconds: {{ .Values.probes.readiness.timeoutSeconds | default 3 }}

          {{/* ---- Resources (mandatory) ---- */}}
          resources:
            requests:
              cpu: {{ .Values.resources.requests.cpu | default "100m" }}
              memory: {{ .Values.resources.requests.memory | default "128Mi" }}
            limits:
              cpu: {{ .Values.resources.limits.cpu | default "500m" }}
              memory: {{ .Values.resources.limits.memory | default "512Mi" }}

          {{/* ---- Container Security Context ---- */}}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: {{ .Values.securityContext.readOnlyRootFilesystem | default true }}
            runAsNonRoot: {{ .Values.securityContext.runAsNonRoot | default true }}
            {{- if .Values.securityContext.runAsUser }}
            runAsUser: {{ .Values.securityContext.runAsUser }}
            {{- end }}
            capabilities:
              drop:
                - ALL

          {{/* ---- Environment variables ---- */}}
          env:
            - name: APP_NAME
              value: {{ include "mathtrail-service-lib.name" . }}
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            {{- with .Values.env }}
            {{- toYaml . | nindent 12 }}
            {{- end }}

          {{- if or .Values.configMap.enabled .Values.envFrom }}
          envFrom:
            {{- if .Values.configMap.enabled }}
            - configMapRef:
                name: {{ include "mathtrail-service-lib.fullname" . }}-env
            {{- end }}
            {{- with .Values.envFrom }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}

          {{/* ---- Graceful Shutdown ---- */}}
          lifecycle:
            preStop:
              exec:
                command:
                  - "/bin/sh"
                  - "-c"
                  - "sleep {{ .Values.preStopDelaySec | default 5 }}"

          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}

      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}

      {{/* ---- Affinity & Anti-Affinity ---- */}}
      {{- if or .Values.affinity .Values.defaultAntiAffinity.enabled }}
      affinity:
        {{- if .Values.defaultAntiAffinity.enabled }}
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    {{- include "mathtrail-service-lib.selectorLabels" . | nindent 20 }}
                topologyKey: kubernetes.io/hostname
        {{- end }}
        {{- with .Values.affinity }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- end }}

      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}
