{{/*
Kafka Steam security configuration for C3
*/}}
{{- define "c3.stream-security-config" }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.c3KafkaCluster }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .)  }}
{{- if not (empty $val) }}
{{ printf "confluent.controlcenter.streams.%s" $val }} 
{{- end }}
{{- end }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}

{{/*
Configure Consumer Configurations
*/}}
{{- define "confluent-operator.consumer-security-config" }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .) }}
{{- if not (empty $val) }}
{{ printf "consumer.%s" $val }} 
{{- end }}
{{- end }}
{{- end }}

{{/*
Monitoring Kafka Cluster configurations
*/}}
{{- define "c3.monitoring-clusters" }}
{{- if $.Values.dependencies.monitoringKafkaClusters }}
{{- range $index, $value := .Values.dependencies.monitoringKafkaClusters }}
{{- $_ := set $ "kafkaDependency" $value }}
{{- $cluster_name := index (pluck "name" $value) 0 }}
{{- $bootstrapEndpoint := index (pluck "bootstrapEndpoint" $value) 0 }}
{{- if empty $bootstrapEndpoint }}
{{- fail (printf "provide bootstrap-endpoint for cluster [%s]" $cluster_name) }}
{{- end }}
{{ printf "\n# Start monitoring cluster [%s] configurations\n" $cluster_name }}
{{- printf "confluent.controlcenter.kafka.%s.bootstrap.servers=%s" $cluster_name $bootstrapEndpoint }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" $)  }}
{{- if not (empty $val) }}
{{- if contains "sasl.jaas.config" $val }}
{{- if and (hasKey $value "username") (hasKey $value "password") }}
{{ printf "confluent.controlcenter.kafka.%s.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"%s\" password=\"%s\";" $cluster_name (first (pluck "username" $value)) (first (pluck "password" $value)) }}
{{- else }}
{{ printf "confluent.controlcenter.kafka.%s.%s" $cluster_name $val }}
{{- end }}
{{- else }}
{{ printf "confluent.controlcenter.kafka.%s.%s" $cluster_name $val }}
{{- end }}
{{- end }}
{{- end }}
{{- printf "\n# End monitoring cluster [%s] configurations\n" $cluster_name }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}
{{- end }}
{{- end }}