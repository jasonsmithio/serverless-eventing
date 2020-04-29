{{/*
Kafka configurations for Replicator workers
*/}}
{{- define "replicator.kafka-config" }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.kafka }}
{{- $protocol :=  (include "confluent-operator.kafka-external-advertise-protocol" .) | trim  }}
{{- $bootstrap :=  .Values.dependencies.kafka.bootstrapEndpoint }}
{{- if contains "SASL" $protocol }}
{{ printf "bootstrap.servers=%s://%s" $protocol $bootstrap }}
{{- else }}
{{- if contains "2WAYSSL" $protocol }}
{{ printf "bootstrap.servers=SSL://%s" $bootstrap }}
{{ else }}
{{ printf "bootstrap.servers=%s://%s" $protocol $bootstrap }}
{{- end }}
{{- end }}
{{ include "confluent-operator.kafka-client-security" . | trim }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}

{{/*
Kafka Producer configurations
*/}}
{{- define "replicator.producer-config" }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.kafka }}
{{ printf "producer.bootstrap.servers=%s" .Values.dependencies.kafka.bootstrapEndpoint }}
{{ include "confluent-operator.producer-security-config" . | trim }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}

{{/*
Kafka Consumer configurations
*/}}
{{- define "replicator.consumer-config" }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.kafka }}
{{ printf "consumer.bootstrap.servers=%s" .Values.dependencies.kafka.bootstrapEndpoint }}
{{ include "confluent-operator.consumer-security-config" . | trim }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}

{{/*
Kafka Producer-Interceptor configurations
*/}}
{{- define "replicator.producer-interceptor-config" }}
{{- if empty .Values.dependencies.interceptor.producer.bootstrapEndpoint }}
{{ printf "producer.confluent.monitoring.interceptor.bootstrap.servers=%s" .Values.dependencies.kafka.bootstrapEndpoint }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.kafka }}
{{- else }} 
{{ printf "producer.confluent.monitoring.interceptor.bootstrap.servers=%s" .Values.dependencies.interceptor.producer.bootstrapEndpoint }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.interceptor.producer }}
{{- end }}
{{ include "confluent-operator.producer-interceptor-security-config" . | trim }}
{{ printf "producer.confluent.monitoring.interceptor.publishMs=%d" (.Values.dependencies.interceptor.publishMs | int64) }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}


{{/*
Kafka Consumer-Interceptor configurations
*/}}
{{- define "replicator.consumer-interceptor-config" }}
{{- if empty .Values.dependencies.interceptor.consumer.bootstrapEndpoint }}
{{ printf "consumer.confluent.monitoring.interceptor.bootstrap.servers=%s" .Values.dependencies.kafka.bootstrapEndpoint }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.kafka }}
{{- else }} 
{{ printf "consumer.confluent.monitoring.interceptor.bootstrap.servers=%s" .Values.dependencies.interceptor.consumer.bootstrapEndpoint }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.interceptor.consumer }}
{{- end }}
{{ include "confluent-operator.consumer-interceptor-security-config" . | trim }}
{{ printf "consumer.confluent.monitoring.interceptor.publishMs=%d" (.Values.dependencies.interceptor.publishMs | int64) }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}
