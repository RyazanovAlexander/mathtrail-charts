{{/*
=======================================================================
  mathtrail-service-lib :: _service.tpl
  Service template for the microservice.
=======================================================================
*/}}

{{- define "mathtrail-service-lib.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
  {{- with (dig "service" "annotations" dict .Values) }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ dig "service" "type" "ClusterIP" .Values }}
  ports:
    - port: {{ dig "service" "port" 8080 .Values }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "mathtrail-service-lib.selectorLabels" . | nindent 4 }}
{{- end -}}
