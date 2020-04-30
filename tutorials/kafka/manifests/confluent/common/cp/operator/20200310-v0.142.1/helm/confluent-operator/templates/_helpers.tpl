{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "confluent-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "confluent-operator.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "confluent-operator.chart" -}}
{{- printf "%s-%s" $.Chart.Name $.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create private docker-registry secret
*/}}
{{- define "confluent-operator.imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.global.provider.registry.fqdn (printf "%s:%s" .Values.global.provider.registry.credential.username .Values.global.provider.registry.credential.password | b64enc) }}
{{- end -}}

{{/*
Create APIkeys for Kafka Cluster
*/}}
{{- define "confluent-operator.apikeys" }}
{{- $_ := required "sasl plain username" .Values.global.sasl.plain.username }}
{{- $_ := required "sasl plain password" .Values.global.sasl.plain.password }}
{{- printf "{ \"keys\": { \"%s\": { \"sasl_mechanism\": \"PLAIN\", \"hashed_secret\": \"%s\", \"hash_function\": \"none\", \"logical_cluster_id\": \"%s\", \"user_id\": \"%s\", \"service_account\": false}}}" .Values.global.sasl.plain.username .Values.global.sasl.plain.password .Release.Namespace .Values.global.sasl.plain.username }}
{{- end }}

{{/*
Distribution of pods placement based on zones
*/}}
{{- define "confluent-operator.pod-distribution" }}
{{- $result := dict }}
{{- $zoneCounts := len .Values.global.provider.kubernetes.deployment.zones }}
{{- $zonesList := .Values.global.provider.kubernetes.deployment.zones }}
{{- range $i :=  until ($.replicas | int) }}
    {{- $podName := join "-" (list $.name $i) }}
    {{- $pointer :=  mod $i $zoneCounts }}
    {{- $zoneName := index $zonesList $pointer }} 
    {{- if hasKey $result $zoneName }}
    {{- $ignore :=  dict "pods" (append (index (index $result $zoneName) "pods") $podName) | set $result $zoneName  }}
    {{- else }}
    {{- $ignore := set $result $zoneName (dict "pods" (list $podName)) }}
    {{- end }}
{{- end }}
{{ $result | toYaml | trim | indent 6 }}
{{- end }}

{{/*
  Find replication count based on the size of Kafka Cluster
*/}}
{{- define "confluent-operator.replication_count" }}
{{- $replicas := $.kreplicas | int }}
{{- $count := 1 }}
{{- if lt $replicas 3 }}
{{- $count := 1 }}
{{- printf "%d" $count }}
{{- else }}
{{- $count := 3 }}
{{- printf "%d" $count }}
{{- end -}}
{{- end -}}

{{/*
  Find ISR count based on the size of Kafka Cluster
*/}}
{{- define "confluent-operator.isr_count" }}
{{- $replicas := $.kreplicas | int }}
{{- $count := 1 }}
{{- if lt $replicas 3 }}
{{- $count := 1 }}
{{- printf "%d" $count }}
{{- else }}
{{- $count := 2 }}
{{- printf "%d" $count }}
{{- end -}}
{{- end -}}

{{/* Generate components labels */}}
{{- define "confluent-operator.labels" }}
  labels:
    component: {{ template "confluent-operator.name" $ }}
{{- end }}

{{/* Generate pod annotations for PSC */}}
{{- define "confluent-operator.annotations" }}
config.value.checksum: {{ include "confluent-operator.generate-sha256sum" .  | trim }}
prometheus.io/scrape: "true"
prometheus.io/port: "7778"
{{- if .Values.alphaPodAnnotations }}
{{- range $key, $value := .Values.alphaPodAnnotations }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/* Generate pod annotations for CR */}}
{{- define "confluent-operator.cr-annotations" }}
{{- if .Values.alphaPodAnnotations }}
podAnnotations:
{{- range $key, $value := .Values.alphaPodAnnotations }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/* Generate PSC finalizers */}}
{{- define "confluent-operator.finalizers" }}
  finalizers:
  - physicalstatefulcluster.core.confluent.cloud
  - physicalstatefulcluster.proxy.confluent.cloud
{{- end }}

{{/* Generate component name */}}
{{- define "confluent-operator.component-name" }}
  name: {{ .Values.name }}
{{- end }}

{{/* Generate component namespace */}}
{{- define "confluent-operator.namespace" }}
  namespace: {{ .Release.Namespace }}
{{- end }}

{{/* configure to enable/disable hostport */}}
{{- define "confluent-operator.hostPort" }}
{{- if .Values.disableHostPort }}
    name: local
{{- else }}
    name:  {{ .Values.global.provider.name }}
{{- end }}
{{- end }}


{{/* configure to docker repository */}}
{{- define "confluent-operator.docker-repo" }}
    docker_repo: {{ .Values.global.provider.registry.fqdn }}
{{- end }}

{{/* configure to docker repository */}}
{{- define "confluent-operator.cluster-id" }}
{{- print .Release.Namespace }}
{{- end }}

{{/* configure to psc version */}}
{{- define "confluent-operator.psc-version" }}
version:
  plugin: v1.0.0
  psc: "1.0.0"
{{- end }}


{{/*
This function expects kafka dict which can be passed as a global function
The function return protocol name as supported by Kafka
1. SASL_PLAINTEXT
2. SASL_SSL
3. PLAINTEXT
4. SSL
5. 2WAYSSL (*Custom)
*/}}
{{- define "confluent-operator.kafka-external-advertise-protocol" }}
{{ $kafka := $.kafkaDependency }}
{{- if not $kafka.tls.enabled }}
    {{- print "SASL_PLAINTEXT" -}}
{{- else if not $kafka.tls.authentication }}
    {{- if $kafka.tls.internal }}
        {{- print "SSL" -}}
    {{- else}}  
        {{- "PLAINTEXT" -}} 
    {{- end }}
{{- else if $kafka.tls.authentication.type }}
    {{- if (eq $kafka.tls.authentication.type "plain") }}
        {{- if $kafka.tls.internal }}
            {{- "SASL_SSL" -}}
        {{- else }}
            {{- print "SASL_PLAINTEXT" -}}
        {{- end }}
    {{- else if eq $kafka.tls.authentication.type "tls" }}
        {{- if $kafka.tls.internal }}
            {{- print "2WAYSSL" -}}
        {{- else }}
            {{- "PLAINTEXT" -}}
        {{- end }}
    {{- else }}
        {{- $_ := fail "Supported authentication type is plain/tls" }}
    {{- end }}
{{- else if empty $kafka.tls.authentication.type }}
    {{- if $kafka.tls.internal }}
        {{- print "SSL" -}}
    {{- else}}  
        {{- "PLAINTEXT" -}} 
    {{- end }}
{{- end }}
{{- end }}

{{/*
Configure Kafka client security configurations
*/}}
{{- define "confluent-operator.kafka-client-security" }}
{{- $protocol :=  (include "confluent-operator.kafka-external-advertise-protocol" .) | trim  }}
{{- if contains "SASL" $protocol }}
{{ printf "security.protocol=%s" $protocol }} 
{{ printf "sasl.mechanism=PLAIN" }}
{{ printf "sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"%s\" password=\"%s\";" .Values.global.sasl.plain.username .Values.global.sasl.plain.password }}
{{- else }}
{{- if contains "2WAYSSL" $protocol }}
{{ printf "security.protocol=%s" "SSL" }}
{{ printf "ssl.keystore.location=/tmp/keystore.jks" }}
{{ printf "ssl.keystore.password=mystorepassword" }}
{{ printf "ssl.key.password=mystorepassword" }}
{{- else }}
{{ printf "security.protocol=%s" $protocol }} 
{{- end }}
{{- end }}
{{- if .Values.tls.cacerts }}
{{- if or (or (eq $protocol "SSL") (eq $protocol "SASL_SSL") ) (eq $protocol "2WAYSSL") }}
{{ printf "ssl.truststore.location=/tmp/truststore.jks"}}
{{ printf "ssl.truststore.password=mystorepassword" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Configure Producer Configurations
*/}}
{{- define "confluent-operator.producer-security-config" }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .)  }}
{{- if not (empty $val) }}
{{ printf "producer.%s" $val }} 
{{- end }}
{{- end }}
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
Producer Monitoring Interceptor Configurations
*/}}
{{- define "confluent-operator.producer-interceptor-security-config" }}
{{ print "producer.interceptor.classes=io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor" }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .)  }}
{{- if not (empty $val) }}
{{ printf "producer.confluent.monitoring.interceptor.%s" $val }} 
{{- end }}
{{- end }}
{{- end }}

{{/*
Consumer Monitoring Interceptor Configurations
*/}}
{{- define "confluent-operator.consumer-interceptor-security-config" }}
{{ print "consumer.interceptor.classes=io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor" }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .)  }}
{{- if not (empty $val) }}
{{ printf "consumer.confluent.monitoring.interceptor.%s" $val }} 
{{- end }}
{{- end }}
{{- end }}

{{/*
Metric Reporter security configuration
*/}}
{{- define "confluent-operator.metric-reporter-security-config" }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .)  }}
{{- if not (empty $val) }}
{{ printf "confluent.metrics.reporter.%s" $val }} 
{{- end }}
{{- end }}
{{- end }}

{{/*
*/}}
{{- define "confluent-operator.cr-pod-security-config" }}
{{- if not .Values.global.pod.randomUID }}
podSecurityContext:
{{- if .Values.global.pod.securityContext.fsGroup }}
  fsGroup: {{ .Values.global.pod.securityContext.fsGroup }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsUser }}
  runAsUser: {{ .Values.global.pod.securityContext.runAsUser }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsGroup }}
  runAsGroup: {{ .Values.global.pod.securityContext.runAsGroup }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsNonRoot }}
  runAsNonRoot: {{ .Values.global.pod.securityContext.runAsNonRoot }}
{{- end }}
{{- if (ne (len .Values.global.pod.securityContext.supplementalGroups) 0) }}
  supplementalGroups:
{{ toYaml .Values.global.pod.securityContext.supplementalGroups | trim | indent 2 }}
{{- end }}
{{- if (ne (len .Values.global.pod.securityContext.seLinuxOptions) 0) }}
  seLinuxOptions:
{{ toYaml $.Values.global.pod.securityContext.seLinuxOptions | trim | indent 4 }}
{{- end }}
{{- else }}
podSecurityContext:
  randomUID: {{ .Values.global.pod.randomUID }}
{{- end }}
{{- end}}

{{/*
*/}}
{{- define "confluent-operator.psc-pod-security-config" }}
{{- if not .Values.global.pod.randomUID }}
pod_security_context:
{{- if .Values.global.pod.securityContext.fsGroup }}
  fs_group: {{ .Values.global.pod.securityContext.fsGroup }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsUser }}
  run_as_user: {{ .Values.global.pod.securityContext.runAsUser }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsGroup }}
  run_as_group: {{ .Values.global.pod.securityContext.runAsGroup }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsNonRoot }}
  run_as_non_root: {{ .Values.global.pod.securityContext.runAsNonRoot }}
{{- end }}
{{- if (ne (len .Values.global.pod.securityContext.supplementalGroups) 0) }}
  supplemental_groups:
{{ toYaml .Values.global.pod.securityContext.supplementalGroups | trim | indent 2 }}
{{- end }}
{{- if (ne (len .Values.global.pod.securityContext.seLinuxOptions) 0) }}
  selinux_options:
{{ toYaml $.Values.global.pod.securityContext.seLinuxOptions | trim | indent 4 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
*/}}
{{- define "confluent-operator.cr-config-overrides"}}
{{- if or .Values.configOverrides.server .Values.configOverrides.jvm }}
configOverrides:
{{- if .Values.configOverrides.server }}
  server:
{{ toYaml .Values.configOverrides.server | trim | indent 2 }}
{{- end }}
{{- if .Values.configOverrides.jvm }}
  jvm:
{{ toYaml .Values.configOverrides.jvm | trim | indent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
*/}}
{{- define "confluent-operator.route" }}
{{- $targetPort := $.targetPort }}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  {{- if $.Values.loadBalancer.annotations }}
  annotations:
{{ toYaml .Values.loadBalancer.annotations | trim | indent 4 }}
  {{- end }}
  name: {{ .Values.name }}-bootstrap
  namespace: {{ .Release.Namespace }}
spec:
  {{- if empty $.Values.loadBalancer.prefix }}
  host: {{ .Values.name }}.{{ .Values.loadBalancer.domain }}
  {{- else }}
  host: {{ $.Values.loadBalancer.prefix }}.{{- $.Values.loadBalancer.domain }}
  {{- end }}
  {{- if .Values.tls.enabled }}
  {{- if .Values.loadBalancer.wildCardPolicy }}
  wildcardPolicy: Subdomain
  {{- end }}
  tls:
    termination: passthrough
  {{- end }}
  port:
    targetPort: external
  to:
    kind: Service
    name: {{ .Values.name }}
{{- end }}

{{/*
JVM security configurations
*/}}
{{- define "confluent-operator.jvm-security-configs"}}
{{- $authenticationType := $.authType }}
{{- $tls := $.tlsEnable }}
{{- if $tls }}
{{- $_ := required "Fullchain PEM cannot be empty" .Values.tls.fullchain }}
{{- $_ := required "Private key pem cannot be empty." .Values.tls.privkey }}
{{- if (eq  $authenticationType "tls") }}
-Djavax.net.ssl.keyStore=/tmp/keystore.jks
-Djavax.net.ssl.keyStorePassword=mystorepassword
-Djavax.net.ssl.keyStoreType=pkcs12
{{- end }}
{{- if .Values.tls.cacerts }}
-Djavax.net.ssl.trustStore=/tmp/truststore.jks
-Djavax.net.ssl.trustStorePassword=mystorepassword
{{- end }}
{{- end }}
{{- end }}

{{/*
Init container configurations
*/}}
{{- define "confluent-operator.psc-init-container" }}
{{- $_ := required "requires init-container image repository" .Values.global.initContainer.image.repository }}
{{- $_ := required "requires init-container image tag" .Values.global.initContainer.image.tag }}
init_containers:
- name: init-container
  image: {{ .Values.global.initContainer.image.repository -}}:{{- .Values.global.initContainer.image.tag }}
  {{- include "confluent-operator.init-container-parameter" . | indent 2 }}
{{- end }}

{{- define "confluent-operator.init-container-parameter" }}
command:
- /bin/sh
- -xc
args:
- until [ -f /mnt/config/pod/{{ .Values.name }}/template.jsonnet ]; do echo "file not found"; sleep 10s; done; /opt/startup.sh
{{- end }}

{{/*
Init container configurations
*/}}
{{- define "confluent-operator.cr-init-container" }}
{{- $_ := required "requires init-container image repository" .Values.global.initContainer.image.repository }}
{{- $_ := required "requires init-container image tag" .Values.global.initContainer.image.tag }}
initContainers:
- name: init-container
  image: {{ .Values.global.provider.registry.fqdn }}/{{ .Values.global.initContainer.image.repository -}}:{{- .Values.global.initContainer.image.tag }}
  {{- include "confluent-operator.init-container-parameter" . | indent 2 }}
{{- end }}

{{/*
jsonnet template
*/}}
{{- define "confluent-operator.template-psc" }}
{{- $domainName := $.domainName }}
// pod's cardinal value
local podID = std.extVar("id");
// log4j setting
local log4jSetting(name, namespace, id) = {
   local log4JSetting = "app:%s,clusterId:%s,server:%s" % [name, namespace, id],
   'log4j.appender.stdout.layout.fields': log4JSetting,
   'log4j.appender.jsonlog.layout.fields': log4JSetting
};
// component endpoint setting
local componentEndpoint(compName, namespace, name, clusterDomain) =  std.join(".", ["%s" % name,"%s" % compName,"%s" % namespace,"%s" % clusterDomain]);
// jvm setting
local jvmSettings(compName, namespace, name, clusterDomain) = {
    '-Djava.rmi.server.hostname': componentEndpoint(compName, namespace, name, clusterDomain),
};
// get's value from either scheduler-plugins or helm charts
local podNamespace = {{ .Release.Namespace | quote }};
local componentName = {{ .Values.name | quote }};
local podName = std.join("-", ["%s" % componentName, "%s" % podID]);
local k8sClusterDomain = {{ $domainName | quote }};
{
  'jvm.config': jvmSettings(componentName, podNamespace, podName, k8sClusterDomain),
  'log4j.properties': log4jSetting(componentName, podNamespace, podID),
{{- if or (eq .Chart.Name "connect")  (eq .Chart.Name "replicator") }}
  '{{ .Chart.Name }}.properties': {
      'rest.advertised.host.name': componentEndpoint(componentName, podNamespace, podName, k8sClusterDomain),
      'rest.advertised.host.port': "8083",
      'rest.advertised.listener': "http",
    },
{{- end }}
{{- if eq .Chart.Name "schemaregistry"  }}
  'schema-registry.properties': {
      "host.name": componentEndpoint(componentName, podNamespace, podName, k8sClusterDomain),
    },
{{- end }}
{{- if eq .Chart.Name "ksql"  }}
  'ksql-server.properties': {
      'host.name': componentEndpoint(componentName, podNamespace, podName, k8sClusterDomain),
    },
{{- end }}
{{- if eq .Chart.Name "controlcenter"  }}
  'control-center.properties': {
      'confluent.controlcenter.id' : podID,
    },
{{- end }}
}
{{- end }}

{{/*
This will generate sha256sum by omitting fields which does not require annotations update
to trigger rolls. This is short-term changes till we move psc structure gradually to component-manager.
*/}}
{{- define "confluent-operator.generate-sha256sum" }}
{{ $update := omit $.Values "replicas" "placement" "image" "nodeAffinity" "rack" "resources" "disableHostPort" }}
{{- $value :=  toYaml $update | sha256sum | quote }}
{{- print $value }}
{{- end }}

{{/*
Component REST endpoint
*/}}
{{- define "confluent-operator.dns-name" }}
{{- if empty $.Values.loadBalancer.prefix }}
dns: {{ $.Values.name }}.{{- $.Values.loadBalancer.domain }}
{{- else }}
dns: {{ $.Values.loadBalancer.prefix }}.{{- $.Values.loadBalancer.domain }}
{{- end }}
{{- end }}

{{/*
Confluent Component Resource Requirements
*/}}
{{- define "confluent-operator.resource-requirements" }}
requests:
{{- if .Values.resources.requests }}
{{ toYaml .Values.resources.requests | trim | indent 2 }}
{{- else }}
{{ toYaml .Values.resources | trim | indent 2 }}
{{- end }}
{{- if .Values.resources.limits }}
limits:
{{ toYaml .Values.resources.limits | trim | indent 2 }}
{{- end }}
{{- end }}
