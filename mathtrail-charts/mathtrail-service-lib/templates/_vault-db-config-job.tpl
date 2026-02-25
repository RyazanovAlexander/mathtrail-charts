{{/*
=======================================================================
  mathtrail-service-lib :: _vault-db-config-job.tpl
  Vault Database Config Job — creates the DB connection + dynamic role
  in Vault's Database Secrets Engine via `bank-vaults configure`.
  Runs as a Helm pre-install/pre-upgrade hook BEFORE the migration Job.
=======================================================================

  This Job:
  1. Waits for Vault to be ready (init container)
  2. Authenticates via Kubernetes auth (wget → Vault HTTP API)
  3. Writes a declarative YAML config and runs `bank-vaults configure`
     which idempotently applies database/config + database/roles.

  SQL creation/revocation statements are inline in the YAML config.
  Vault placeholders ({{name}}, {{password}}, etc.) are Helm-escaped
  as {{ "{{name}}" }} so they survive template rendering as literals.
*/}}

{{- define "mathtrail-service-lib.vaultDbConfigJob" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if $v.vaultDbConfig.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-vault-db-config
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
    app.kubernetes.io/component: vault-db-config
  annotations:
    # Run before the migration Job (weight 5) — DB creds must exist first.
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  backoffLimit: {{ $v.vaultDbConfig.backoffLimit }}
  ttlSecondsAfterFinished: {{ $v.vaultDbConfig.ttlSecondsAfterFinished }}
  template:
    metadata:
      labels:
        {{- include "mathtrail-service-lib.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: vault-db-config
    spec:
      serviceAccountName: {{ include "mathtrail-service-lib.serviceAccountName" . }}
      restartPolicy: Never

      initContainers:
        # Block until Vault is initialized, unsealed, and accepting requests.
        # Prevents wasting backoff retries on predictable infra cold-start delays
        # (Local Path Provisioner PVC + Vault unseal can take 30-60s on K3s).
        - name: wait-for-vault
          image: {{ $v.vaultDbConfig.waitImage }}
          command:
            - sh
            - -c
            - |
              echo "Waiting for Vault at {{ $v.vaultDbConfig.vaultAddr }}..."
              until wget -qO- {{ $v.vaultDbConfig.vaultAddr }}/v1/sys/health 2>/dev/null; do
                echo "Vault not ready, retrying in 3s..."
                sleep 3
              done
              echo "Vault is ready."
          resources:
            requests:
              cpu: "10m"
              memory: "16Mi"
            limits:
              cpu: "50m"
              memory: "32Mi"

      containers:
        - name: vault-db-config
          image: {{ $v.vaultDbConfig.image }}
          env:
            - name: VAULT_ADDR
              value: {{ $v.vaultDbConfig.vaultAddr | quote }}
            - name: PG_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ $v.vaultDbConfig.pgSecretName }}
                  key: {{ $v.vaultDbConfig.pgSecretKey }}
            # Templated values passed as env vars for clean shell access.
            - name: CONN_NAME
              value: {{ $v.vaultDbConfig.connectionName | quote }}
            - name: PG_HOST
              value: {{ $v.vaultDbConfig.pgHost | quote }}
            - name: PG_PORT
              value: {{ $v.vaultDbConfig.pgPort | quote }}
            - name: PG_DATABASE
              value: {{ $v.vaultDbConfig.pgDatabase | quote }}
            - name: PG_USERNAME
              value: {{ $v.vaultDbConfig.pgUsername | quote }}
            - name: ROLE_NAME
              value: {{ $v.vaultDbConfig.roleName | quote }}
            - name: DEFAULT_TTL
              value: {{ $v.vaultDbConfig.defaultTtl | quote }}
            - name: MAX_TTL
              value: {{ $v.vaultDbConfig.maxTtl | quote }}
            - name: VAULT_ROLE
              value: {{ $v.vaultDbConfig.vaultRole | quote }}
          command:
            - sh
            - -ec
            - |
              # ── Step 1: Authenticate to Vault via Kubernetes SA token ──
              # wget (busybox) is available in the alpine-based bank-vaults image.
              # Parse client_token from the JSON response without requiring jq.
              VAULT_TOKEN=$(wget -qO- \
                --header="Content-Type: application/json" \
                --post-data="{\"role\":\"${VAULT_ROLE}\",\"jwt\":\"$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)\"}" \
                "${VAULT_ADDR}/v1/auth/kubernetes/login" | \
                grep -o '"client_token":"[^"]*"' | cut -d'"' -f4)
              export VAULT_TOKEN
              echo "Authenticated to Vault as role=${VAULT_ROLE}"

              # ── Step 2: Write declarative Vault database config ──
              # ${VAR} — shell env vars expanded at runtime by the heredoc.
              # {{ "{{username}}" }} etc. — Vault engine placeholders; Helm-escaped
              # so they survive template rendering as literal {{ }} strings.
              cat > /tmp/vault-config.yaml << EOF
              secrets:
                - type: database
                  path: database
                  configuration:
                    config:
                      - name: "${CONN_NAME}"
                        plugin_name: postgresql-database-plugin
                        connection_url: "postgresql://{{ "{{username}}" }}:{{ "{{password}}" }}@${PG_HOST}:${PG_PORT}/${PG_DATABASE}?sslmode=disable"
                        allowed_roles:
                          - "${ROLE_NAME}"
                        username: "${PG_USERNAME}"
                        password: "${PG_PASSWORD}"
                    roles:
                      - name: "${ROLE_NAME}"
                        db_name: "${CONN_NAME}"
                        creation_statements: |
                          CREATE ROLE "{{ "{{name}}" }}" WITH LOGIN PASSWORD '{{ "{{password}}" }}' VALID UNTIL '{{ "{{expiration}}" }}';
                          GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "{{ "{{name}}" }}";
                          GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "{{ "{{name}}" }}";
                        revocation_statements: "DROP ROLE IF EXISTS {{ "{{name}}" }}"
                        default_ttl: "${DEFAULT_TTL}"
                        max_ttl: "${MAX_TTL}"
              EOF

              # ── Step 3: Apply declaratively (idempotent) ──
              bank-vaults configure --config-file /tmp/vault-config.yaml
              echo "Done: ${CONN_NAME} + ${ROLE_NAME} configured."
          resources:
            {{- toYaml $v.vaultDbConfig.resources | nindent 12 }}
{{- end }}
{{- end -}}
