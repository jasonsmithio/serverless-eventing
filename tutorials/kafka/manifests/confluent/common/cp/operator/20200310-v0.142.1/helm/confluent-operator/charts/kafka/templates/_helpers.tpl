{{/*
Configure Confluent Metric Reporters
*/}}
{{- define "kafka.confluent-metric-reporter" }}
{{- $_ := set $ "kreplicas" .Values.replicas }}
metricReporter:
  enabled: {{ .Values.metricReporter.enabled }}
  {{- if  empty .Values.metricReporter.bootstrapEndpoint }}
  bootstrapEndpoint: {{ .Values.name }}:9071
  {{- else }}
  bootstrapEndpoint: {{ .Values.metricReporter.bootstrapEndpoint }}
  {{- end }}
  publishMs: {{ .Values.metricReporter.publishMs }}
  {{- if  empty .Values.metricReporter.replicationFactor }}
  replicationFactor: {{ include  "confluent-operator.replication_count" . }}
  {{- else }}
  replicationFactor: {{ .Values.metricReporter.replicationFactor }}
  {{- end }}
  internal: {{ .Values.metricReporter.tls.internal }}
  tls:
    enabled: {{ .Values.metricReporter.tls.enabled }}
    {{- if and .Values.metricReporter.tls.authentication (not (empty .Values.metricReporter.tls.authentication.type))}}
    authentication:
        type: {{ .Values.metricReporter.tls.authentication.type }}
    {{- end }}
{{- end }}

{{/*
Create SASL Users
*/}}
{{- define "kafka.sasl_users" }}
{{- $result := dict "users" (list) }}
{{- range $i, $value := .Values.sasl.plain }}
{{- $users := split "=" $value }}
{{- $user := index $users "_0" }}
{{- $pass := index $users "_1" }}
{{- if eq $user $.Values.global.sasl.plain.username }}
{{- fail "global.sasl.plain.username must not contain in sasl.plain" }}
{{- end }}
{{- if empty $pass }}
{{- fail "password is required..."}}
{{- end }}
{{- end }}
{{- $totalUsers := append .Values.sasl.plain (printf "%s=%s" .Values.global.sasl.plain.username .Values.global.sasl.plain.password) }}
{{- range $i, $value := $totalUsers }}
{{- $users := split "=" $value }}
{{- $user := index $users "_0" }}
{{- $pass := index $users "_1" }}
{{- $ignore := (printf " \"%s\": { \"sasl_mechanism\": \"PLAIN\", \"hashed_secret\": \"%s\", \"hash_function\": \"none\", \"logical_cluster_id\": \"%s\", \"user_id\": \"%s\"}" $user $pass $.Release.Namespace $user) | append $result.users | set $result "users" }}
{{- end }}
{{- printf "{ \"keys\": { %s}}" (join ", " $result.users) }}
{{- end }}