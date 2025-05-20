# Cloud Native Messaging with NATS

__Corresponding [Blog Post](https://thejaysmith.com/titles/serverlessjay/serverless-eventing:-cloud-native-messaging-with-nats/ "Blog Post")__

[Knative Eventing](https://knative.dev/docs/eventing/) offers a variety of EventSources to use for building a serverless eventing platform. So far, my blog has covered [SinkBinding](https://thejaysmith.com/titles/blogroll/serverless-eventing-sinkbinding-101/) as well as [Kafka](https://thejaysmith.com/titles/serverlessjay/serverless-eventing-modernizing-legacy-streaming-with-kafka/ "Kafka").

This tutorial will show you how to use [NATS](https://nats.io/) as a Knative Eventing source. NATS is a relatively new offering compared to other messaging busses such as [RabbitMQ](https://rabbitmq.com "RabbitMQ") or [Apache Kafka](https://kafka.apache.org "Apache Kafka") but it was designed for the purpose of supporting messaging in a Cloud Native environment. It is even a [CNCF](https://cncf.io "CNCF") Incubating Project.

## Concepts

For the purposes of this demo, we will also introduce the concept of the [Eventing Channel](https://knative.dev/docs/eventing/channels/default-channels/, "Eventing Channel"). Channels are [Kubernetes Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/ "Kubernetes Custom Resources") which define a single event forwarding and persistence layer. Messaging implementations may provide implementations of Channels via a Kubernetes Custom Resource, supporting different technologies, such as Apache Kafka or NATS Streaming. A simpler way to think of it is as a delivery mechanism that can fan-out messages to multiple destinations (sinks).

We will be using the [NATS Streaming Server](https://docs.nats.io/nats-streaming-concepts/intro "NATS Streaming Server") for our channel. It is NATS Server designed specifically for streaming data. This is the perfect NATS component for Serverless Eventing.

## Scenario

You are creating a financial services application that collects foreign exchange rates in real time and uses the data to automate trades. We would need a service that pulls the data from the fiancnial markets using an API then write that data to an Eventing Bus where it can be consumed. We don't want our developers consuming the services to worry about how they subscribe to the messaging bus.

## Setup Environment

First we will setup some basic environment variables. Be sure to replace `<your project>` with your actual Google Cloud project name.

```bash
export PROJECT_ID=<your project>
export PROJ_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
export CLUSTER_NAME='gke-knative-nats'
export ZONE='us-central1-a'
export KO_DOCKER_REPO="gcr.io/${PROJECT_ID}"
```

And now let's get our GitHub Repo

```bash
git clone https://github.com/TheJaySmith/serverless-eventing
cd serverless-eventing
```

I have created a script called `setup-gke.sh` that simplifies the staging process. It will attempt to install [Google Cloud SDK](https://cloud.google.com/sdk/) if you don’t have it installed already. If it can execute `gcloud`, it skips this step. It will then do the following.

- Enable Google Cloud APIs if they aren’t already enabled
- Create a [GKE](https://cloud.google.com/kubernetes-engine) Cluster
- Setup [xip.io domain](https://cloud.google.com/run/docs/gke/default-domain) for GKE
- Install [Knative Eventing](https://knative.dev/docs/eventing/) and [Knative Monitoring](https://knative.dev/docs/serving/installing-logging-metrics-traces/)
- Give your compute service account access to Secret Manager

Now let's navigate back to the `serverless-eventing` directory and run the script.

```bash
chmod +x scripts/setup-gke.sh
sh scripts/setup-gke.sh
```

Alright, we are ready to get started.

## Install Ko

[Ko](https://github.com/google/ko "Ko") is an open source tool that builds and deploys Go applications to Kubernetes. We will use it to help setup NATS Streaming as our Eventing Bus. Installing Ko is simple. Make sure that you have [Go](https://golang.org/ "Go") setup on your machine and run this line.

```bash
GO111MODULE=on go get github.com/google/ko/cmd/ko
```

## Setup NATS Streaming Server

Now it is time to setup NATS. Let's install the NATS Streaming Server first. We will be using the [Eventing Channel](https://github.com/knative/eventing-contrib/blob/release-0.16/natss/config/README.md "Eventing Channel") created by our KNative Community. In future examples, we will create and configure our own server but there is no point in reinventing the wheel when not needed. So let's create a namespace for our NATS Server intallation and install the server.

```bash
kubectl create namespace natss
kubectl apply --filename tutorials/nats/natss-channel/build/natss.yaml
```

Next, let's install some Knative components for NATS Streaming Server

```bash
kubectl create namespace natss-knative
kubectl apply --filename https://github.com/knative/eventing-contrib/releases/download/v0.17.0/natss-channel.yaml
```

Let's now setup our NATS Channel. All of our Kubernetes Application YAML files are located in the `config/` directory.

```bash
mkdir -p build/src/knative.dev
cd build/src/knative.dev
git clone git@github.com:knative/eventing-contrib.git
cd eventing-contrib
ko apply -f natss/config
cd ../../../..
```

This installs the basic NATS Streaming Chhannel CRDs as documented [here](https://github.com/knative/eventing-contrib/blob/release-0.16/natss/config/README.md).

Now let's take a look at our files.

```bash
cd tutorials/nats/natss-channel/
```

Now let's install our NATS Channel called "foo"

```bash
kubectl apply -f manifests/natss-foo-channel.yaml
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

<!-- Eventing Broker tutorial later 
Now we will install an [Eventing Broker](https://knative.dev/development/eventing/broker/, "Eventing Broker"). A Broker represents an ‘event mesh’. Events are sent to the Broker's ingress and are then sent to any subscribers that are interested in that event. Once inside a Broker, all metadata other than the CloudEvent is stripped away (e.g. unless set as a CloudEvent attribute, there is no concept of how this event entered the Broker).

```bash
kubectl apply -f manifests/natss-channel-configmap.yaml
kubectl apply -f manifests/natss-broker.yaml
```

This will create a broker called `natss-backed-broker`. You can find it by running this command.

```bash
kubectl get brokers natss-backed-broker
```
-->

## NATS BOX

After setting up NATS Streaming, it's nice to be able to test on cluster. This is especially important if all of the operations are expected to run on cluster. You wouldn't necessarily wnat to expose the services to the larger internet. The NATS team has provided us with a handy tool called [NATS Box](https://github.com/nats-io/nats-box "NATS Box"). You deploy the a container in a pod in Kubernetes and test as if you were a service on the same cluter.

Open a new tab in your terminal and run the below command to enter the NATS Box for publishing.

```bash
kubectl run -i --rm --tty nats-box-pub --image=synadia/nats-box --restart=Never
```

Now we will publish an event to the "hello" subject. The message will be "test".

```bash
stan-pub -s nats://nats-streaming.natss.svc:4222 -c knative-nats-streaming hello test
```

Open a second terminal tab and we will use this command to create a new NATS Box for subscribing.

```bash
kubectl run -i --rm --tty nats-box-sub --image=synadia/nats-box --restart=Never
```

Run the below command to consume from the "hello" subject.

```bash
stan-sub -s nats://nats-streaming.natss.svc:4222 -c knative-nats-streaming hello
```

You should see something like this.

```bash
[#1] Received: sequence:1 subject:"hello" data:"test" timestamp:1596228651186265865
```

If you see something like the above, then you are good to go!

## Setup AlphaVantage

For demos, [AlphaVantage](alphavantage.co "AlphaVantage") is my goto source. They have a free tier that allows around 500 API calls/day and it's easy to sign up. You can get your key [here](https://www.alphavantage.co/support/#api-key "here").

Some people have asked why I always recommend AlphaVantage when I do these demos. I will say that they pay me absolutely nothing to promote them. I just really like using their API for Serverless Eventing demos as financial data tends to be real-time in nature.

### Cloud Secret Manager

Google Cloud recently GA’d [Cloud Secret Manager](https://cloud.google.com/secret-manager/) which gives you the ability to securely store your secrets encrypted in Google Cloud. Remember those four Twitter API keys we had earlier? We are going to store them in Google Cloud using the Secret Manager.

We will go from the Hamburger -> Security -> Secrets.

![secret manager](https://raw.githubusercontent.com/TheJaySmith/serverless-eventing/master/assets/images/secret-manager.png)

Let’s now Create a secret. We will name this secret `alpha-vantage-key` and give it the "Value" of the API Key you just created. You have now created a secured value that our applicaiton will use.

## Building our Applications

Let's now build our application. First, let's make sure that `gcloud` will be properly authenitcated with the `docker` command. If you do not have Docker installed, you can find it [here](https://docs.docker.com/get-docker/ "here").

```bash
gcloud auth configure-docker
```

Next we will build our currency app. Let's go to the currency app folder.

```bash
cd app/currency/
```

Let's take a look at the app in the `currency.py` file.

```bash
CURR1 = 'USD'
CURR2 = 'JPY'
```

These are the currency values that we will be using. While I have hardcoded 'USD' and 'JPY', you can change this to anything that you want.

```bash
afx = ForeignExchange(key=ALPHAVANTAGE_KEY)

def make_msg(message):
    msg = '{"msg": "%s"}' % (message)
    return msgs


def get_currency():
    data, _ = afx.get_currency_exchange_rate(
            from_currency=CURR1, to_currency=CURR2)
    exrate = data['5. Exchange Rate']
    return exrate


while True:
    headers = {'Content-Type': 'application/cloudevents+json'}
    body = get_currency()
    requests.post(sink_url, data=json.dumps(body), headers=headers)
    time.sleep(30)
```

We first create an AlphaVantage object using our key called `afx`. The `make_msg` function formats the function. The `def_currency` function will use CURR1 and CURR2 and return an exchange rate. The while loop will execute the `def_currency` function, get the exchange rate, and send it to our event sink every 30 seconds. You could make it more or less but I chose '30' as it will give you more time to play with it during the 500 calls/day limit.

Now lets build the containers and push them to [Google Container Registry](https://cloud.google.com/container-registry "Google Container Registry").

```bash
docker build --build-arg PROJECT_ID=${PROJECT_ID} -t gcr.io/${PROJECT_ID}/natss-currency:v1  .
docker push gcr.io/${PROJECT_ID}/natss-currency:v1
```

Now we will build our `natss-client`. This application will receive the financial messages and send them to the NATS Streaming Server.

```bash
cd ../natss-client/
```

A lot is happening is this code so let's take a look at `natss-client.py`. For the sake of simplicity, we will focus on unique aspects of this code.

```bash
import asyncio
from nats.aio.client import Client as NATS
from stan.aio.client import Client as STAN
from nats.aio.errors import ErrConnectionClosed, ErrTimeout, ErrNoServers
```

Here we are importing some important libraries. We are going to be using this asynchronously so the `asyncio` library is important as a dependency for the NATS python libraries. We are using [asyncio-nats-client](https://pypi.org/project/asyncio-nats-client/) and [asyncio-nats-streaming](https://pypi.org/project/asyncio-nats-streaming/) to connect to the NATS Streaming Server and send streaming data.

We will be using [Flask](https://flask.palletsprojects.com/en/1.1.x/ "Flask") to handle the POST requests coming from our `natss-currency` application.

```bash
        async def run(loop):
            nc = NATS()
            sc = STAN()

            await nc.connect("nats://nats-streaming.natss.svc:4222", loop=loop)
            await sc.connect("knative-nats-streaming", "testing-1", nats=nc)

            async def ack_handler(ack):
                print("Received ack: {}".format(ack.guid))

            # Publish asynchronously by using an ack_handler which
            # will be passed the status of the publish.

            await sc.publish("foo.default", json.dumps({"specversion": "1.0", "type" : "dev.knative.messaging.natsschannel", "source" : "/apis/messaging.knative.dev/v1alpha1/namespaces/default/natsschannels/foo", "data" : content }).encode(), ack_handler=ack_handler)
            #await sc.publish("foo.default", event, ack_handler=ack_handler)
            async def cb(msg):
                print("Received a message on subscription (seq: {}): {}".format(msg.sequence, msg.data))

            await sc.subscribe("foo.default", start_at='first', cb=cb)
            await asyncio.sleep(1, loop=loop)

            await sc.close()
            await nc.close()
```

This function will connect to our NATS Streaming server located at `nats://nats-streaming.natss.svc:4222` with a cluster ID of `knative-nats-streaming` and a client ID of `testing-1`.

It will take all the request and then publish them to the `foo.default` channel. The channel itself is named `foo` but you will see later that it is deployed in the `default` namespace, hence the name. We are formatting the message to be [CloudEvent](https://cloudevents.io, "CloudEvents") compliant as described [here](https://github.com/cloudevents/spec/blob/v1.0/nats-protocol-binding.md).

Now let's build the containers.

```bash
docker build -t gcr.io/${PROJECT_ID}/natss-client:v1 .
docker push gcr.io/${PROJECT_ID}/natss-client:v1
```

Great, now it is time to test and deploy.

## Deploy and Use

First let's check out our manifests files.

```bash
cd ../../manifests
sed -i '' 's/PROJECT_ID/'${PROJECT_ID}'/g' natss-client.yaml
sed -i '' 's/PROJECT_ID/'${PROJECT_ID}'/g' natss-currency.yaml
```

First we will deploy a SinkBinding. Here you can see that we deploy the SinkBinding undo the name `natss-currency-sink-bind`. This will take the "subject" as the event source and the sink as the event sink. For these purposes we are using a Knative Service but [SinkBinding](https://knative.dev/docs/eventing/samples/sinkbinding/ "SinkBinding") does allow for you to use other Kubernetes objects such as datasets. I also have a demo [here](https://github.com/TheJaySmith/serverless-eventing/tree/master/tutorials/twitter-sink-binding).

So let's up our binding.

```bash
kubectl apply -f natss-currency-sink-bind.yaml
```

Next we deploy the `natss-client` service. We want to ensure that our sink is ready to receive before we deploy the source. This service will act as the publisher to the NATS Streaming Server.

```bash
kubectl apply -f natss-client.yaml
```

Finally we deploy the `natss-currency` service. This will start creating events as soon as we deploy.

```bash
kubectl apply -f natss-currency.yaml
```

All of our services are deployed so let's move on.

## Testing Time

Remember how we used NATS Box to view events? Let's try this again.

```bash
kubectl run -i --rm --tty nats-box-sub-1 --image=synadia/nats-box --restart=Never
```

Now we will publish an event to the "hello" subject. The message will be "test".

```bash
stan-sub -s nats://nats-streaming.natss.svc:4222 -c knative-nats-streaming -id newclient foo.default
```

You should see something like this:

```bash
 Received: sequence:2759 subject:"foo.default" data:"{\"specversion\": \"1.0\", \"type\": \"dev.knative.messaging.natsschannel\", \"source\": \"/apis/messaging.knative.dev/v1alpha1/namespaces/default/natsschannels/foo\", \"data\": \"\\\"106.53000000\\\"\"}" timestamp:1597173746280108693
```

You should notice the foreign exchange rate as the value of "data".

So everything is writing, let's do one more test. Let's subscribe and consume. First let's create a [Subscription](https://knative.dev/docs/reference/eventing/#messaging.knative.dev/v1beta1.Subscription). Take a look at `natss-sub.yaml`.

```bash
apiVersion: messaging.knative.dev/v1
kind: Subscription
metadata:
  name: natss-sub-0
spec:
  channel:
    apiVersion: messaging.knative.dev/v1alpha1
    kind: NatssChannel
    name: foo
  subscriber:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: natss-viewer
```

We are creating a subscription service called `natss-sub-0` and it will subscribe to the NatssChannel named `foo`. It will then send that data to be consumed by our Service named `natss-viewer`.

Let's apply this.

```bash
kubectl apply -f natss-sub.yaml
```

Finally, we will deploy a service to read the events. In a real world application, this may be your service that processes the data in order to get an output. For our purposes, it'll just log the results. So let's go ahead and apply.

```bash
kubectl apply -f natss-viewer.yaml
```

Give it a few seconds then run this command

```bash
kubectl logs -l serving.knative.dev/service=natss-viewer -c user-container --since=10m
```

If all works, you should see something like this.

```bash
Context Attributes,
  specversion: 1.0
  type: dev.knative.messaging.natsschannel
  source: /apis/messaging.knative.dev/v1alpha1/namespaces/default/natsschannels/foo
  id:
Data,
  "\"106.55000000\""
```

Congrats! Your service is now consuming data in real time from the NATS Streaming Server!

## Summarize

In this demo, we used the NATS Streaming Server to create a Knative Channel and subscribe a consumer service ttot use the streaming data. NATSS is a great Cloud Native solution for Eventing Busses. While this only showed one service accepting data, you would be able to scale that by using multiple subscriptions, brokers, and/or triggers. In the future, I will show [NATSS JetStream](https://github.com/nats-io/jetstream) as well as Brokers and Triggers.

## End

Be sure to delete your clusters!
