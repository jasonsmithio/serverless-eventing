# Cloud Native Messaging with NATS

__Corresponding [Blog Post](https://thejaysmith.com/titles/serverlessjay/serverless-eventing:-cloud-native-messaging-with-nats/ "Blog Post")__

[Knative Eventing](https://knative.dev/docs/eventing/) offers a variety of EventSources to use for building a serverless eventing platform. So far, my blog has covered [SinkBinding](https://thejaysmith.com/titles/blogroll/serverless-eventing-sinkbinding-101/) as well as [Kafka](https://thejaysmith.com/titles/serverlessjay/serverless-eventing-modernizing-legacy-streaming-with-kafka/, "Kafka").

This tutorial will show you how to use [NATS](https://nats.io/) as a Knative Eventing source. NATS is a relatively new offering compared to other messaging busses such as [RabbitMQ](https://rabbitmq.com, "RabbitMQ") or [Apache Kafka](https://kafka.apache.org, "Apache Kafka") but it was designed for the purpose of supporting messaging in a Cloud Native environment. It is even a [CNCF](https://cncf.io, "CNCF") Incubating Project.



## Scenario

```bash
kubectl create ns nats-io
kubectl apply -f https://github.com/nats-io/nats-operator/releases/latest/download/00-prereqs.yaml
kubectl apply -f https://github.com/nats-io/nats-operator/releases/latest/download/10-deployment.yaml
```

```bash
kubectl create namespace natss
kubectl apply -n natss -f https://raw.githubusercontent.com/knative/eventing-contrib/v0.16.0/natss/config/broker/natss.yaml
```