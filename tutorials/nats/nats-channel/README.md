# Cloud Native Messaging with NATS

__Corresponding [Blog Post](https://thejaysmith.com/titles/serverlessjay/serverless-eventing:-cloud-native-messaging-with-nats/ "Blog Post")__

[Knative Eventing](https://knative.dev/docs/eventing/) offers a variety of EventSources to use for building a serverless eventing platform. So far, my blog has covered [SinkBinding](https://thejaysmith.com/titles/blogroll/serverless-eventing-sinkbinding-101/) as well as [Kafka](https://thejaysmith.com/titles/serverlessjay/serverless-eventing-modernizing-legacy-streaming-with-kafka/, "Kafka").

This tutorial will show you how to use [NATS](https://nats.io/) as a Knative Eventing source. NATS is a relatively new offering compared to other messaging busses such as [RabbitMQ](https://rabbitmq.com, "RabbitMQ") or [Apache Kafka](https://kafka.apache.org, "Apache Kafka") but it was designed for the purpose of supporting messaging in a Cloud Native environment. It is even a [CNCF](https://cncf.io, "CNCF") Incubating Project.

## Concepts

For the purposes of this demo, we will also introduce the concept of the [Eventing Channel](https://knative.dev/docs/eventing/channels/default-channels/, "Eventing Channel"). Channels are [Kubernetes Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/, "Kubernetes Custom Resources") which define a single event forwarding and persistence layer. Messaging implementations may provide implementations of Channels via a Kubernetes Custom Resource, supporting different technologies, such as Apache Kafka or NATS Streaming. A simpler way to think of it is as a delivery mechanism that can fan-out messages to multiple destinations (sinks).

We will be using the [NATS Streaming Server](https://docs.nats.io/nats-streaming-concepts/intro, "NATS Streaming Server") for our channel. It is NATS Server designed specifically for streaming data. This is the perfect NATS component for Serverless Eventing.

## Scenario

## Setup Environment

First we will setup some basic environment variables. Be sure to replace `<your project>` with your actual Google Cloud project name.

```bash
export PROJECT_ID=<your project>
export PROJ_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
export CLUSTER_NAME='cr-knative-nats'
export ZONE='us-central1-a'
export KO_DOCKER_REPO="gcr.io/${PROJECT_ID}"
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

<!--## Install Ko

[Ko](https://github.com/google/ko, "Ko") is an open source tool that builds and deploys Go applications to Kubernetes. We will use it to help setup NATS Streaming as our Eventing Bus. Installing Ko is simple. Make sure that you have [Go](https://golang.org/, "Go") setup on your machine and run this line.

```bash
GO111MODULE=on go get github.com/google/ko/cmd/ko
```
-->

## Setup NATS Streaming Server

Now it is time to setup NATS. Let's install the NATS Streaming Server first. We will be using the [Eventing Channel](https://github.com/knative/eventing-contrib/blob/release-0.16/natss/config/README.md, "Eventing Channel") created by our KNative Community. In future examples, we will create and configure our own server but there is no point in reinventing the wheel when not needed. So let's create a namespace for our NATS Server intallation and install the server.

```bash
kubectl create namespace natss
kubectl apply --filename https://raw.githubusercontent.com/knative/eventing-contrib/master/natss/config/broker/natss.yaml
```

Now let's take a look at our files.

```bash
cd tutorials/nats/nats-channel/
```

Let's now setup our NATS Channel. All of our Kubernetes Application YAML files are located in the `config/` directory.

```bash
kubectl apply -f config/
```

<!--
```bash
ko apply -f config/
```
-->

Now let's install our NATS Channel called "nats-test-channel"

```bash
kubectl apply -f manifests/nats-test-channel.yaml
```

Now let's verify that this was installed properly. First let's check the NATSS Channel Controller is located in one Pod.

```bash
kubectl get deployment -n knative-eventing natss-ch-controller
```

Then we can check the NATSS Channel Dispatcher receives and distributes all events. There is a single Dispatcher for all NATSS Channels.

```bash
kubectl get deployment -n knative-eventing natss-ch-dispatcher
```

By default the components are configured to connect to NATS at `nats://nats-streaming.natss.svc:4222` with NATS Streaming cluster ID `knative-nats-streaming`.
