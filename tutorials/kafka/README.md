# Serverlesss Eventing With Kafka

__Corresponding [Blog Post](https://thejaysmith.com/titles/serverlessjay/serverless-eventing-modernizing-legacy-streaming-with-kafka/ "Blog Post")__

[Knative Eventing](https://knative.dev/docs/eventing/) offers a variety of EventSources to use for building a serverless eventing platform. In my [previous blog post](https://thejaysmith.com/titles/blogroll/serverless-eventing-sinkbinding-101/) I talk about [SinkBinding](https://github.com/TheJaySmith/serverless-eventing/tree/master/tutorials/twitter-sink-binding) and we use the technology to create an EventSource the pulls Twitter data.

This tutorial will show you how to use [Apache Kafka](https://kafka.apache.org/) as a Knative Eventing source. Now there are many options for deploying Kafka on a Kubernetes cluster. I am using [Confluent's](https://confluent.co) Kafka Kubernetes Operator. I forked the operator found [here](https://docs.confluent.io/current/tutorials/examples/kubernetes/gke-base/docs/index.html?utm_source=github&utm_medium=demo&utm_campaign=ch.examples_type.community_content.kubernetes) to use.

Another great solution is [Strimzi](https://strimzi.io/) which is a CNCF incubated project. In the upcoming weeks, we will have a Strimzi demo.

## Scenario

Let's say that you are creating a financial services mobile app that allows users to trade in foreign exchanges. It would be important to have the most up-to-date exchange information in order to make a decision. We want to collect the data and then store it somewhere where it can be pushed to individual user's mobile apps.

From a scalability and reliability perspective, those messages should be sent to a messaging platform. This also offers abstraction from your core applicaiton as your application is not communicating directly to the mobile front end but rather using Kafka as the intermediary.

Here we will create an application that regularly checks for currency exchange information between "USD" and "JPY". It will then send the information to an event sink which will write it to a Kafka topic.

## Setup

Let's set some environment variables. Be sure to replace "your project" with your actual Project ID.

```bash
export PROJECT_ID=<your project>
export PROJ_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
export CLUSTER_NAME='cr-knative'
export ZONE='us-central1-a'
```

Install Helm version 3

```bash
 curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

## Install Kafka

Now lets download our repo and install the [Confluent Operator](https://docs.confluent.io/current/tutorials/examples/kubernetes/gke-base/docs/index.html "Confluent Operator")

```bash
git clone --branch 6.0.0-post https://github.com/confluentinc/examples
cd examples/kubernetes/gke-base
```

We will also download our customiations to the directory.

```bash
curl https://raw.githubusercontent.com/TheJaySmith/serverless-eventing/master/tutorials/kafka/manifests/confluent/gke/Makefile-impl --output Makefile-impl
curl https://raw.githubusercontent.com/TheJaySmith/serverless-eventing/master/tutorials/kafka/manifests/confluent/gke/cfg/values.yaml --output cfg/values.yaml
```

And let's install the cluster.

```bash
make gke-create-cluster
make demo
```

Now let's see what's installed.

```bash
kubectl -n operator get all
```

You will most likely see something like this

```bash
...
Created [https://container.googleapis.com/v1/projects/<project-id>/zones/us-central1-a/clusters/cp-examples-operator-<username>].
To inspect the contents of your cluster, go to: <link>
kubeconfig entry generated for cp-examples-operator-<username>.
NAME                            LOCATION  MASTER_VERSION  MASTER_IP     MACHINE_TYPE  NODE_VERSION   NUM_NODES  STATUS
cp-examples-operator-<username> <zone>    1.12.8-gke.10   <ip-address>  n1-highmem-2  1.12.8-gke.10  3          RUNNING
✔  ++++++++++ GKE Cluster Created
```

We will setup an NGINX Ingress for the Control Center. Let's first set cluster permissions.

```bash
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account)
```

Next, we need to apply this mandatory installation to get the NGINX to work

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
```

And now we will apply the NGINX ingress.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/provider/cloud-generic.yaml
```

Finally, we will create the ingress for Confluent Kafka.

```bash
curl https://raw.githubusercontent.com/TheJaySmith/serverless-eventing/master/tutorials/kafka/manifests/confluent/gke/kafka-nginx-ingress.yaml --output kafka-nginx-ingress.yaml
kubectl apply -f kafka-nginx-ingress.yaml -n operator
```

Final step, we will setup a wildcard DNS using [xip.io](xip.io "xip.io"). First we grab our broker IP address.

```bash
export KAFKA_IP=$(kubectl get service kafka-bootstrap-lb -n operator -o=jsonpath='{.status.loadBalancer.ingress[].ip}')
```

and then we reapply the Helm chart with the added IP address. **PLEASE NOTE** this assumes that you are executing in the `gke` directory.

```bash
helm upgrade --install --namespace operator --wait --timeout=5m -f cfg/values.yaml --set global.initContainer.image.tag=6.0.0.0 --set global.provider.region=us-central1 --set global.provider.kubernetes.deployment.zones={us-central1-a}  --set kafka.image.tag=6.0.0.0 --set kafka.replicas=1 --set kafka.enabled=true kafka --set kafka.loadBalancer.enabled=true --set kafka.loadBalancer.domain=${KAFKA_IP}.xip.io -f cfg/values.yaml ../common/cp/operator/1.6.0/helm/confluent-operator
```

## Install Knative on a GKE Cluster

We will do this on a separate cluster. The purposes is to simulate an environment where your application lives on one cluster and the Kafka brokers are hosted somewhere else. While we use a Kubernetes cluster in this example, it could just as easily be a hosted solution, bare metal, VMs, etc.

First let's download our directory

```bash
cd ../../..
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
chmod +x scripts/setup-cloudrun.sh
sh scripts/setup-cloudrun.sh
```

## Setup AlphaVantage

For demos, [AlphaVantage](alphavantage.co "AlphaVantage") is my goto source. They have a free tier that allows around 500 API calls/day and it's easy to sign up. You can get your key [here](https://www.alphavantage.co/support/#api-key "here").

Cloud Secret Manager

Google Cloud recently GA’d [Cloud Secret Manager](https://cloud.google.com/secret-manager/) which gives you the ability to securely store your secrets encrypted in Google Cloud. Remember those four Twitter API keys we had earlier? We are going to store them in Google Cloud using the Secret Manager.

We will go from the Hamburger -> Security -> Secrets.

![secret manager](https://raw.githubusercontent.com/TheJaySmith/serverless-eventing/master/assets/images/secret-manager.png)

Let’s now Create a secret. We will name this secret `alpha-vantage-key` and give it the "Value" of the API Key you just created. You have now created a secured value that our applicaiton will use.

## Build our Applications

Let's now build our application. First, let's make sure that `gcloud` will be properly authenitcated with the `docker` command. If you do not have Docker installed, you can find it [here](https://docs.docker.com/get-docker/ "here").

```bash
gcloud auth configure-docker
```

Next we will build our currency app. Let's go to the currency app folder.

```bash
cd tutorials/kafka/resources/apps/currency/
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
docker build --build-arg PROJECT_ID=${PROJECT_ID} -t gcr.io/${PROJECT_ID}/currency-controller:v1  .
docker push gcr.io/${PROJECT_ID}/currency-controller:v1
```

Now we will build our `producer-sink`. This application will receive the applications and then push them to Kafka.

```bash
cd ../producer
```

 But first, let's do a quick change to the file.

```bash
sed -i '' 's/KAFKA_IP/'${KAFKA_IP}'/g' producer.py
```

Now let's look at `producer.py`

```bash
producer = KafkaProducer(bootstrap_servers=['KAFKA_IP.xip.io:9092'],
                         sasl_plain_username = 'test',
                         sasl_plain_password = 'test123',
                         security_protocol='SASL_PLAINTEXT',
                         sasl_mechanism='PLAIN')
```

`KAFKA_IP` should be replaced by your Kafka IP that we got earlier. This command will send data to our Kafka Cluster.

```bash
def info(msg):
    app.logger.info(msg)


@app.route('/', methods=['POST'])
def default_route():
    if request.method == 'POST':
        content = request.data.decode('utf-8')
        info(f'Event Display received event: {content}')

        producer.send('money-demo', bytes(content[i], encoding='utf-8'))

        return jsonify(hello=str(content))
    else:
        return jsonify('this is error')
```

This will receive the events sent by the currency app. This is effectively the `event sink`. It will then send the information to our Kafka Cluster but will also log the outputs so that you can view them in `kubectl logs`.

Now let's build the containers.

```bash
docker build -t gcr.io/${PROJECT_ID}/currency-kafka:v1 .
docker push gcr.io/${PROJECT_ID}/currency-kafka:v1
```

Great, now it is time to test and deploy.

## Deploy and Use

First let's check out our config files.

```bash
cd ../../config
sed -i '' 's/PROJECT_ID/'${PROJECT_ID}'/g' currency-controller.yaml
sed -i '' 's/PROJECT_ID/'${PROJECT_ID}'/g' currency-kafka.yaml
```

We entered the `config` directory and added our `PROJECT_ID` to the `currency-controller.yaml` and `currency-kafka.yaml` files.

`currency-controller.yaml` will deploy a [Knative Service](https://knative.dev/docs/serving/services/creating-services/ "Knative Service") for our controller container. This will generate our messages as the **event source**. `currency-kafka.yaml` will deploy a Knative service for our currency-kafka container. This will receive the messages from the controller. We call this the **event si

Lets deploy these. Now they should be deployed in a sequence so give about 10 seconds to each one before you deploy the next.

First we will deploy the binding. This file will tell us to bind our event source (`currency-controller`) to our event sink (`currency-kafka`). Lets examine this first.

```bash
apiVersion: sources.knative.dev/v1alpha2
kind: SinkBinding
metadata:
  name: currency-sink-bind
spec:
  subject:
    apiVersion: serving.knative.dev/v1
    kind: Service
    name: currency-controller
  sink:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: currency-kafka
```

Here you can see that we deploy the SinkBinding undo the name `currency-sink-bind`. This will take the "subject" as the event source and the sink as the event sink. For these purposes we are using a Knative Service but [SinkBinding](https://knative.dev/docs/eventing/samples/sinkbinding/ "SinkBinding") does allow for you to use other Kubernetes objects such as datasets.

Now let's deploy.

```bash
kubectl apply -f currency-sink-bind.yaml
```

Next we deploy the currency-kafka service. We want to ensure that our sink is ready to receive before we deploy the source.

```bash
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: currency-kafka
spec:
  template:
    spec:
      containers:
      - image: gcr.io/PROJECT_ID/currency-kafka:v1
        imagePullPolicy: Always
```

This is a standard Knative Service for currency Kafka. Now lets deploy.

```bash
kubectl apply -f currency-kafka.yaml
```

Finally we deploy the currency-controller service. This will start creating events as soon as we deploy. Let's look at the file

```bash
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: currency-controller
spec:
  template:
    spec:
      containers:
      - image: gcr.io/PROJECT_ID/currency-controller:v1
        imagePullPolicy: Always
```

and deploy...

```bash
kubectl apply -f currency-controller.yaml
```

Now let's ensure that everything is running.

```bash
kubectl get pods
```

You should see the `controller` and `kafka` service running.

## Let's Test

There is a tool that I like called *Kafkacat*. It's an open source CLI that makes it pretty easy to work with a Kafka broker without a JVM. You can download it [here](https://github.com/edenhill/kafkacat "here") and follow the instructions for your system.

In the same `config` directory run this.

```bash
sed 's/KAFKA_IP/'${KAFKA_IP}'/g' kafka-config.sample.properties > kafka-config.properties
```

This will put you `$KAFKA_IP` in the `kafka-config.properties` file. We will use this file to authenticate with the broker. You will notice that the username is "test" and the password is "test123". It goes without saying that this isn't a best practice for security. For demo purposes, it's fine. There are a myriad of ways to secure your brokers and the various Kafka libraries offer ways to do that.

Now, let's see what we get

```bash
kafkacat -b ${KAFKA_IP}.xip.io:9092 -F kafka-config.properties -t money-demo -C
```

If done correctly, you should see a new number pop up every 30 seconds like:

```bash
105.00
105.67
```

## Summarize

Sending data from a source to a single sink may not seem impressive but let's imagine scaling. We want to create sources for every posssible currency exchange and send them to Kafka but you don't want to force write N Kafka connectors for each currency type. You also don't want to write a large monolithic application that handles every possible message type to simplify.

While adopting microservices, you just create event-sources to generate the events then use the SinkBinding to tell the events where to go. In this example, we used a single event-sink but you could further scale it out with [Channels](https://knative.dev/docs/eventing/channels/) and [Brokers](https://knative.dev/docs/eventing/broker-trigger/) which I will explain in a later tutorial.

PLEASE NOTE: This is an example of how to deploy Kafka on Kubernetes and create a streaming application. Realistically, you would want to make a larger Kubernetes cluster for Kafka and consider how you would secure and expose the brokers.

## End

Be sure to delete your clusters!
