{{/*
=======================================================================
  mathtrail-service-lib :: _hpa.tpl
  HorizontalPodAutoscaler for microservice autoscaling.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.hpa" -}}
{{- if (dig "autoscaling" "enabled" false .Values) }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "mathtrail-service-lib.fullname" . }}
  minReplicas: {{ dig "autoscaling" "minReplicas" 1 .Values }}
  maxReplicas: {{ dig "autoscaling" "maxReplicas" 10 .Values }}
  metrics:
    {{- if (dig "autoscaling" "targetCPUUtilizationPercentage" nil .Values) }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ dig "autoscaling" "targetCPUUtilizationPercentage" 80 .Values }}
    {{- end }}
    {{- if (dig "autoscaling" "targetMemoryUtilizationPercentage" nil .Values) }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ dig "autoscaling" "targetMemoryUtilizationPercentage" 80 .Values }}
    {{- end }}
{{- end }}
{{- end -}}
