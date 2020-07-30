# Cloud Native Messaging with NATS

__Corresponding [Blog Post](https://thejaysmith.com/titles/serverlessjay/serverless-eventing:-cloud-native-messaging-with-nats/ "Blog Post")__

[Knative Eventing](https://knative.dev/docs/eventing/) offers a variety of EventSources to use for building a serverless eventing platform. So far, my blog has covered [SinkBinding](https://thejaysmith.com/titles/blogroll/serverless-eventing-sinkbinding-101/) as well as [Kafka](https://thejaysmith.com/titles/serverlessjay/serverless-eventing-modernizing-legacy-streaming-with-kafka/, "Kafka").

This tutorial will show you how to use [NATS](https://nats.io/) as a Knative Eventing source. NATS is a relatively new offering compared to other messaging busses such as [RabbitMQ](https://rabbitmq.com, "RabbitMQ") or [Apache Kafka](https://kafka.apache.org, "Apache Kafka") but it was designed for the purpose of supporting messaging in a Cloud Native environment. It is even a [CNCF](https://cncf.io, "CNCF") Incubating Project.

## Scenario

## Setup Environment

First we will setup some basic environment variables. Be sure to replace `<your project>` with your actual Google Cloud project name.

```bash
export PROJECT_ID=<your project>
export PROJ_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
export CLUSTER_NAME='cr-knative-nats'
export ZONE='us-central1-a'
```

And now let's get our GitHub Repo

```bash
git clone https://github.com/TheJaySmith/serverless-eventing
cd serverless-eventing
```

I have created a script called `setup-cloudrun.sh` that simplifies the staging process. It will attempt to install [Google Cloud SDK](https://cloud.google.com/sdk/) if you don’t have it installed already. If it can execute `gcloud`, it skips this step. It will then do the following.

- Enable Google Cloud APIs if they aren’t already enabled
- Create a [GKE](https://cloud.google.com/kubernetes-engine) Cluster running [Cloud Run on Anthos](https://cloud.google.com/anthos/run)
- Setup [xip.io domain](https://cloud.google.com/run/docs/gke/default-domain) for Cloud Run on Anthos
- Install [Knative Eventing](https://knative.dev/docs/eventing/) and [Knative Monitoring](https://knative.dev/docs/serving/installing-logging-metrics-traces/)
- Give your compute service account access to Secret Manager

Now let's navigate back to the `serverless-eventing` directory and run the script.

```bash
chmod +x scripts/setup-cloudrun.sh
sh scripts/setup-cloudrun.sh
```

Alright, we are ready to get started.

## Setup CertManager

Security has been and will always be an important part of your messaging experience. After all, you don't want outsiders to see what's being passed in your application. We will be using [TLS](https://en.wikipedia.org/wiki/Transport_Layer_Security, "TLS") encryption by using [Cert-Manager](https://cert-manager.io/, "cert-manager") in our cluster. I find it to be one of the better OSS TLS certificate management systems for Kubernetes so we will use it here.

```bash
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.0/cert-manager.yaml
```

Just like that, you have a managed certificate issuer for your Kubernetes cluster.

## Setup NATS

Now it is time to setup NATS. Let's install the NATS operator first.

```bash
kubectl create ns nats-io

#Install NATS Operator
kubectl apply -f https://github.com/nats-io/nats-operator/releases/latest/download/00-prereqs.yaml
kubectl apply -f https://github.com/nats-io/nats-operator/releases/latest/download/10-deployment.yaml

#Install NATS Streaming Server
kubectl apply -f https://raw.githubusercontent.com/nats-io/k8s/master/nats-server/simple-nats.yml
kubectl apply -f https://raw.githubusercontent.com/nats-io/k8s/master/nats-streaming-server/simple-stan.yml
```

Now let's take a look at our files.

```bash
cd tutorials/nats/
```

NOTE: you will see a lot of files for other NATS setups that you can [see here](https://github.com/nats-io/nats-operator, "see here"). In future demos, we will see other options for setting up a secure NATS cluster such as those with [service accounts](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/, "service accounts")

First let's apply look at `certs/nats-cluster-selfsign.yaml`

```bash
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: selfsigning
spec:
  selfSigned: {}
```

This is the cluster certificate issuer and we'll be selfsigning. You can use other options such as [Let's Encrypt](https://cert-manager.io/docs/configuration/acme/, "Let's Encrypt") but for our purposes, we'll use a self-signed.

Next let's look at `certs/nats-certs.yaml`

```bash
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: nats-ca
spec:
  secretName: nats-ca
  duration: 8736h # 1 year
  renewBefore: 240h # 10 days
  issuerRef:
    name: selfsigning
    kind: ClusterIssuer
  commonName: nats-ca
  usages: 
    - cert sign # workaround for odd cert-manager behavior
  organization:
  - Your organization
  isCA: true
  ```

This will create the actual certificate. Finally, let's look at `certs/nats-cert-issuer.yaml`.

```bash
apiVersion: cert-manager.io/v1alpha2
kind: Issuer
metadata:
  name: nats-ca
spec:
  ca:
    secretName: nats-ca
```

This is what NATS will use to issue the certificate. In the `certs/` directory you will see `nats-routes-tls.yaml` and `nats-server-tls.yaml`. This will issue the certs to your NATS server. Now let's apply these.

```bash
kubectl apply -f certs/*
```

Congratulations, you have launched a certificate manager for NATS. Let's now look at `clusters/nats-cluster-cert.yaml`.

```bash
apiVersion: nats.io/v1alpha2
kind: NatsCluster
metadata:
  name: knative-nats-cluster-certs
spec:
  size: 3
  version: "1.3.0"

  tls:
    # Certificates to secure the NATS client connections:
    serverSecret: "nats-clients-tls"

    # Certificates to secure the routes.
    routesSecret: "nats-routes-tls"
```

Here we will create a NATS cluser with 3 replicas. You never want to give your Eventing Bus a single point of failure so we will replicate. Let's go ahead and apply this.

```bash
kubectl apply -f clusters/nats-cluster-cert.yaml
```



```bash
kubectl create namespace natss
kubectl apply -n natss -f https://raw.githubusercontent.com/knative/eventing-contrib/v0.16.0/natss/config/broker/natss.yaml
```