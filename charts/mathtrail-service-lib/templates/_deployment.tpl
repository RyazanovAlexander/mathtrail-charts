{{/*
=======================================================================
  mathtrail-service-lib :: _deployment.tpl
  Main Deployment with:
    - Init Container waiting for migration completion
    - Dapr Sidecar integration
    - Mandatory probe contract (Startup/Liveness/Readiness)
    - Security Context
    - Resource Requests & Limits
    - Graceful Shutdown (preStop hook)
=======================================================================
*/}}

{{- define "mathtrail-service-lib.deployment" -}}
{{ include "mathtrail-service-lib.validateImage" . }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
spec:
  {{- if not (dig "autoscaling" "enabled" false .Values) }}
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
        runAsNonRoot: {{ dig "podSecurityContext" "runAsNonRoot" true .Values }}
        {{- with (dig "podSecurityContext" "fsGroup" nil .Values) }}
        fsGroup: {{ . }}
        {{- end }}
        {{- with (dig "podSecurityContext" "runAsUser" nil .Values) }}
        runAsUser: {{ . }}
        {{- end }}
        {{- with (dig "podSecurityContext" "runAsGroup" nil .Values) }}
        runAsGroup: {{ . }}
        {{- end }}

      {{/* Init container: wait for migration completion */}}
      {{- if (dig "migration" "enabled" false .Values) }}
      initContainers:
        - name: wait-for-migration
          image: {{ dig "migration" "waitImage" "bitnami/kubectl:latest" .Values }}
          command:
            - "/bin/sh"
            - "-c"
            - "kubectl wait --for=condition=complete job/{{ include "mathtrail-service-lib.fullname" . }}-migrate --timeout={{ dig "migration" "waitTimeout" "120s" .Values }}"
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
          imagePullPolicy: {{ dig "image" "pullPolicy" "IfNotPresent" .Values }}
          ports:
            - name: http
              containerPort: {{ dig "service" "port" 8080 .Values }}
              protocol: TCP

          {{/* ---- Probe contract ---- */}}
          startupProbe:
            httpGet:
              path: {{ dig "probes" "startup" "path" "/health/startup" .Values }}
              port: http
            initialDelaySeconds: {{ dig "probes" "startup" "initialDelaySeconds" 0 .Values }}
            periodSeconds: {{ dig "probes" "startup" "periodSeconds" 5 .Values }}
            failureThreshold: {{ dig "probes" "startup" "failureThreshold" 30 .Values }}
            timeoutSeconds: {{ dig "probes" "startup" "timeoutSeconds" 3 .Values }}

          livenessProbe:
            httpGet:
              path: {{ dig "probes" "liveness" "path" "/health/liveness" .Values }}
              port: http
            initialDelaySeconds: {{ dig "probes" "liveness" "initialDelaySeconds" 0 .Values }}
            periodSeconds: {{ dig "probes" "liveness" "periodSeconds" 10 .Values }}
            failureThreshold: {{ dig "probes" "liveness" "failureThreshold" 3 .Values }}
            timeoutSeconds: {{ dig "probes" "liveness" "timeoutSeconds" 3 .Values }}

          readinessProbe:
            httpGet:
              path: {{ dig "probes" "readiness" "path" "/health/ready" .Values }}
              port: http
            initialDelaySeconds: {{ dig "probes" "readiness" "initialDelaySeconds" 0 .Values }}
            periodSeconds: {{ dig "probes" "readiness" "periodSeconds" 10 .Values }}
            failureThreshold: {{ dig "probes" "readiness" "failureThreshold" 3 .Values }}
            timeoutSeconds: {{ dig "probes" "readiness" "timeoutSeconds" 3 .Values }}

          {{/* ---- Resources ---- */}}
          resources:
            requests:
              cpu: {{ dig "resources" "requests" "cpu" "100m" .Values }}
              memory: {{ dig "resources" "requests" "memory" "128Mi" .Values }}
            limits:
              cpu: {{ dig "resources" "limits" "cpu" "500m" .Values }}
              memory: {{ dig "resources" "limits" "memory" "512Mi" .Values }}

          {{/* ---- Container Security Context ---- */}}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: {{ dig "securityContext" "readOnlyRootFilesystem" true .Values }}
            runAsNonRoot: {{ dig "securityContext" "runAsNonRoot" true .Values }}
            {{- with (dig "securityContext" "runAsUser" nil .Values) }}
            runAsUser: {{ . }}
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

          {{- if or (dig "configMap" "enabled" false .Values) .Values.envFrom }}
          envFrom:
            {{- if (dig "configMap" "enabled" false .Values) }}
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
      {{- if or .Values.affinity (dig "defaultAntiAffinity" "enabled" true .Values) }}
      affinity:
        {{- if (dig "defaultAntiAffinity" "enabled" true .Values) }}
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
