{{/*
Kafka configurations for Connect workers
*/}}
{{- define "connect.kafka-config" }}
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
{{- define "connect.producer-config" }}
{{- if empty .Values.dependencies.producer.bootstrapEndpoint }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.kafka }}
{{ printf "producer.bootstrap.servers=%s" .Values.dependencies.kafka.bootstrapEndpoint }}
{{- else }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.producer }}
{{ printf "producer.bootstrap.servers=%s" .Values.dependencies.producer.bootstrapEndpoint }}
{{- end }}
{{ include "confluent-operator.producer-security-config" . | trim }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}

{{/*
Kafka Consumer configurations
*/}}
{{- define "connect.consumer-config" }}
{{- if empty .Values.dependencies.consumer.bootstrapEndpoint }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.kafka }}
{{ printf "consumer.bootstrap.servers=%s" .Values.dependencies.kafka.bootstrapEndpoint }}
{{- else }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.consumer }}
{{ printf "consumer.bootstrap.servers=%s" .Values.dependencies.consumer.bootstrapEndpoint }}
{{- end }}
{{ include "confluent-operator.consumer-security-config" . | trim }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}

{{/*
Kafka Producer-Interceptor configurations
*/}}
{{- define "connect.producer-interceptor-config" }}
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
{{- define "connect.consumer-interceptor-config" }}
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
