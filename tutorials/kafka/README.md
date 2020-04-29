# Serverlesss Eventing With Kafka

[Knative Eventing](https://knative.dev/docs/eventing/) offers a variety of EventSources to use for building a serverless eventing platform. In my [previous blog post](https://thejaysmith.com/titles/blogroll/serverless-eventing-sinkbinding-101/) I talk about [SinkBinding](https://github.com/TheJaySmith/serverless-eventing/tree/master/tutorials/twitter-sink-binding) and we use the technology to create an EventSource the pulls Twitter data.

This tutorial will show you how to use [Apache Kafka](https://kafka.apache.org/) as a Knative Eventing source. Now there are many options for deploying Kafka on a Kubernetes cluster. I am using [Confluent's](https://confluent.co) Kafka Kubernetes Operator. I forked the operator found [here](https://docs.confluent.io/current/tutorials/examples/kubernetes/gke-base/docs/index.html?utm_source=github&utm_medium=demo&utm_campaign=ch.examples_type.community_content.kubernetes) to use.

Another great solution is [Strimzi](https://strimzi.io/) which is a CNCF incubated project.  

Let's set some environment variables

```bash
export PROJECT=<your project>
export PROJ_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
export CLUSTER_NAME='cp-examples-operator-gcp'
export ZONE='us-central1-a'
```

Install Helm version 3

```bash
 curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

Now let'd download our repo and install the Confluent Operator

```bash
git clone https://github.com/TheJaySmith/serverless-eventing
cd tutorials/kafka/manifests/confluent
make gke-create-cluster
make demo
```

Now let's see what's installed.

```bash
kubectl -n operator get all
```

```bash
gcloud container clusters update \
$CLUSTER_NAME \
--update-addons=CloudRun=ENABLED,HttpLoadBalancing=ENABLED \
--zone=$ZONE
```

## Permissions

echo "Setting up cluster permissions"
kubectl create clusterrolebinding cluster-admin-binding \
--clusterrole=cluster-admin \
--user=$(gcloud config get-value core/account)

## Get istio-gateway external IP

echo "****** We are going to grab the external IP ******"
export EXTERNAL_IP=$(kubectl get service istio-ingress --namespace gke-system | awk 'FNR == 2 {print $4}')

echo $EXTERNAL_IP

echo "***** We will now patch configmap for domain ******"
kubectl patch configmap config-domain --namespace knative-serving --patch \
'{"data": {"example.com": null, "'"$EXTERNAL_IP"'.xip.io": ""}}'

## Install Knative Eventing

echo "Install Knative Eventing"
kubectl apply --selector knative.dev/crd-install=true \
--filename https://github.com/knative/eventing/releases/download/v0.13.0/eventing-crds.yaml 

kubectl apply --filename https://github.com/knative/eventing/releases/download/v0.13.0/eventing-core.yaml \
--filename https://github.com/knative/serving/releases/download/v0.13.0/monitoring-core.yaml

## Install Advanced Monitoring

kubectl apply --filename https://github.com/knative/serving/releases/download/v0.13.0/monitoring-metrics-prometheus.yaml \
--filename https://github.com/knative/serving/releases/download/v0.13.0/monitoring-logs-elasticsearch.yaml \
--filename https://github.com/knative/serving/releases/download/v0.13.0/monitoring-tracing-jaeger.yaml

## Enable Secret Admin to compute service account

gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$PROJ_NUMBER-compute@developer.gserviceaccount.com --role roles/secretmanager.admin
