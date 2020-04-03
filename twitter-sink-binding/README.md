# Creating a Sink Binding to pull from Twitter

Knative Eventing offers many types of [event sources](https://knative.dev/docs/eventing/sources/) that a developer can use to create a streaming application. In this demo, we will talk about [SinkBinding](http://knative.dev/docs/eventing/samples/sinkbinding/) and use [Twitter’s API](https://developer.twitter.com/en/docs).

First we should define some terms. If you have played with Knative a bit, you may remember a concept called [ContainerSource](https://knative.dev/docs/eventing/samples/container-source/).  This allowed you to create a container as an event source. For example, you could create a container that produces a random number every ten seconds then sends it to an event broker to be consumed by your application.

This concept largely still exists but has been replaced by SinkBinding. Per the documentation, a SinkBinding is responsible for linking together “addressable” Kubernetes resources that may receive events (aka the event “sink”) with Kubernetes resources that embed a PodSpec (as spec.template.spec) and want to produce events.

This gives you a simple way to author an event source using standard Kubernetes abstractions such as a Deployment or DaemonSet rather than a single container instance. This can be a powerful tool when you want to create your own events producer and then stream those events to be consumed by your applications.

For the purposes of this, we will create a container that pulls tweets from Twitter every 30 seconds and streams it to my Event Display.

## Setup Twitter

Since we will be using Twitter, let’s first get a Twitter API Key and Secret. You will need a Twitter account. If you don’t have one, they are free, and you can follow me at @thejaysmith if you like. Let’s go to [Twitter’s Developer Page](https://developer.twitter.com/en/apps) and create an app.

![create an app](https://raw.githubusercontent.com/TheJaySmith/knative-howto/master/images/create-an-app.png)

You will be required to fill out “App name” and “Application description”. What you type here is arbitrary but I would recommend naming the application something simple like “Knative Test” (which can also work for Application description).

For the purposes of this demo, you can use your personal website or the GitHub repo URL for “Website URL” and write your best explanation as to what Knative is in the “Tell us how this app will be used” field. You will then agree to the Developer Agreement.
On the following page, let’s go to “Keys and tokens”

![twitter auth](https://raw.githubusercontent.com/TheJaySmith/knative-howto/master/images/twitter-auth.png)

You will copy the “API Key” and the “API Secret” and store it somewhere safe. From there, go ahead and click the “Generate” button to get an “Access token” and “Access token secret”

![generate token](https://raw.githubusercontent.com/TheJaySmith/knative-howto/master/images/generate-token.png)

You will see a pop-up containing the “Access token” and “Access token secret”. Please copy those as we will be using them later.

GitHub and Setup
Now that we have our API keys and secrets, let’s pull down our repo.

```bash
Git clone git@github.com:TheJaySmith/knative-howto.git
cd knative-howto/
```

I have created a script called `setup-cloudrun.sh` that simplifies the staging process. It will attempt to install [Google Cloud SDK](https://cloud.google.com/sdk/) if you don’t have it installed already. If it can execute `gcloud`, it skips this step. It will then do the following.

- Enable Google Cloud APIs if they aren’t already enabled
- Create a [GKE](https://cloud.google.com/kubernetes-engine) Cluster running [Cloud Run on Anthos](https://cloud.google.com/anthos/run)
- Setup [xip.io domain](https://cloud.google.com/run/docs/gke/default-domain) for Cloud Run on Anthos
- Install [Knative Eventing](https://knative.dev/docs/eventing/) and [Knative Monitoring](https://knative.dev/docs/serving/installing-logging-metrics-traces/)
- Give your compute service account access to Secret Manager

To run the script, first set your *Environment Variables* and then run the script.

```bash
export ZONE=’us-central1-a’
export PROJECT_ID=$(gcloud config get-value project)
export PROJ_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
export CLUSTER_NAME=’cr-knative’
chmod +x scripts/setup-cloudrun.sh
sh scripts/setup-cloudrun.sh
```

Cloud Secret Manager

Google Cloud recently GA’d [Cloud Secret Manager](https://cloud.google.com/secret-manager/) which gives you the ability to securely store your secrets encrypted in Google Cloud. Remember those four Twitter API keys we had earlier? We are going to store them in Google Cloud using the Secret Manager.

We will go from the Hamburger -> Security -> Secrets.

![secret manager](https://raw.githubusercontent.com/TheJaySmith/knative-howto/master/images/secret-manager.png)

Let’s now Create a secret . We will create four so we will put a name for your key in “Name” and the secret in “Secret Value”. For the sake of this demo, be sure to use the below names and give them the corresponding “Secret Value” that you collected in the Twitter section.

twitter-api-key
twitter-api-secret
twitter-access-key
twitter-access-secret

*_NOTE:_ please use the above naming conventions as it will be important later.*

Once you have created your secrets, we can move onto the next stage.

## KNative Event Viewer

We will now build our containers.

First, let’s take a look at our code.

```bash
cd eventing/event-viewer/
```

You will see these files

```bash
Dockerfile
app.py
requirements.txt
```

Open the app.py file in your preferred editor. Let’s take a look at this code.

```python
import logging
import os

from flask import Flask, request

app = Flask(__name__)


@app.route('/', methods=['POST'])
def event_push():
    content = request.data.decode('utf-8')
    info(f'Event Display received event: {content}')
    return 'OK', 200

def info(msg):
    app.logger.info(msg)


if __name__ != '__main__':
    # Redirect Flask logs to Gunicorn logs
    gunicorn_logger = logging.getLogger('gunicorn.error')
    app.logger.handlers = gunicorn_logger.handlers
    app.logger.setLevel(gunicorn_logger.level)
    info('Event Display starting')
else:
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
```

I am using the [Flask framework](https://flask.palletsprojects.com/en/1.1.x/) to build this Python app. This app will act as a REST API endpoint and will accept traffic coming from our SinkBinding. It will then insert the entries into the logs. This will effectively act as the **consumer**.

Let’s go ahead and containerize this application and push it to [Google Container Repository (GCR)](https://cloud.google.com/container-registry)

```bash
docker build -t gcr.io/${PROJECT_ID}/event-viewer:v1 .
docker push gcr.io/${PROJECT_ID}/event-viewer:v1
```

We have built the container and pushed it to our local registry. Now let’s move on.

## KNative Twitter Consumer

Let’s navigate to our `twitter-sink-binding` directory

```bash
cd ../twitter/twitter-sink-binding/
```

Before we get started, let’s run these commands in order to include your `$PROJECT_ID` in the container path.

```bash
sed 's|PROJECT_ID|'"$PROJECT_ID"'|g' twitter-deploy.sample.yaml > twitter-deploy.yaml
sed 's|PROJECT_ID|'"$PROJECT_ID"'|g' twitter-sink.sample.yaml > twitter-sink.yaml
sed 's|PROJECT_ID|'"$PROJECT_ID"'|g' twitter-svc.sample.yaml > twitter-svc.yaml
```

Now let’s take a look at `twitter-producer.py` and see what it’s doing.

```python
#!/usr/bin/env python

import os
import json
import requests
import time

#from flask import Flask, jsonify, redirect, render_template, request, Response

from google.cloud import secretmanager

import tweepy

from tweepy.streaming import StreamListener


sink_url = os.getenv('K_SINK')

PROJECT_ID = os.environ.get('PROJECT_ID')

TOPIC = os.environ.get('TOPIC')

secrets = secretmanager.SecretManagerServiceClient()
TWITTER_KEY = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-api-key/versions/1").payload.data.decode("utf-8")
TWITTER_SECRET = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-api-secret/versions/1").payload.data.decode("utf-8")
ACCESS_TOKEN = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-access-key/versions/1").payload.data.decode("utf-8")
ACCESS_SECRET = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-access-secret/versions/1").payload.data.decode("utf-8")



auth = tweepy.OAuthHandler(TWITTER_KEY, TWITTER_SECRET)
auth.set_access_token(ACCESS_TOKEN, ACCESS_SECRET)
api = tweepy.API(auth)


def make_msg(message):
    msg = '{"msg": "%s"}' % (message)
    return msg

def get_tweet():
    tweets = []
    for tweet in api.search(q=TOPIC,count=100,
                        lang="en",
                        since="2019-06-01"):
        newmsg = make_msg(tweet.text)
        tweets.append(newmsg)

    return tweets


body = {"Hello":"World"}
headers = {'Content-Type': 'application/cloudevents+json'}

while True:
    body = get_tweet()
    requests.post(sink_url, data=json.dumps(body), headers=headers)
    time.sleep(30)
```

So let’s break this down;

```bash
secrets = secretmanager.SecretManagerServiceClient()
TWITTER_KEY = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-api-key/versions/1").payload.data.decode("utf-8")
TWITTER_SECRET = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-api-secret/versions/1").payload.data.decode("utf-8")
ACCESS_TOKEN = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-access-key/versions/1").payload.data.decode("utf-8")
ACCESS_SECRET = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-access-secret/versions/1").payload.data.decode("utf-8")
```

Remember how I mentioned how important it was to maintain the name integrity when creating the secrets? You will see that we are now importing the secrets from Secret Manager and assigning their values to variables.

Secrets operate with the schema `projects/PROJECT ID/secrets/SECRET NAME/version/VERSION NUMBER`

Because we only have one revision of the secret, we are using version 1. However, if we needed to revoke a key and regenerate, we can simply update that key in Secrets Manager and it will be assigned __version 2__.

Now we take those secrets and authenticate our Twitter object.

```python
auth = tweepy.OAuthHandler(TWITTER_KEY, TWITTER_SECRET)
auth.set_access_token(ACCESS_TOKEN, ACCESS_SECRET)
api = tweepy.API(auth)
```

The variable `api` now contains an authenticated Twitter object. Now let’s retrieve tweets.

```python
def get_tweet():
    tweets = []
    for tweet in api.search(q=TOPIC,count=25,
                        lang="en",
                        since="2019-06-01"):
        newmsg = make_msg(tweet.text)
        tweets.append(newmsg)

    return tweets
```

This function will pull 25 tweets that match the search criteria of “TOPIC” since January 1, 2020. It formats it using the `make_msg` function and appends it to the tweets dictionary.

Finally, let’s look at the piece of code that produces the event

```bash
headers = {'Content-Type': 'application/cloudevents+json'}

while True:
    body = get_tweet()
    requests.post(sink_url, data=json.dumps(body), headers=headers)
    time.sleep(30)
```

Here we have a while loop that executes every 30 seconds. It will send a message to the `SINK` (defined later) and the body will contain our tweets and we’ll give it a [CloudEvents](https://cloudevents.io/) header.

Next we will build our container. First, let’s set up a value for `$MY_TOPIC`. This is the keyword we will search for in Twitter. You can use topics like “news” or “puppies” or “serverless” or whatever you want.

```bash
export MY_TOPIC=<your twitter topic>
docker build -t gcr.io/${PROJECT_ID}/twitter-producer:v1 . --build-arg PROJECT_ID=$PROJECT_ID --build-arg  TOPIC=$MY_TOPIC
docker push gcr.io/${PROJECT_ID}/twitter-producer:v1
```

You will see that we passed two variables to be used `PROJECT_ID` and `MY_TOPIC`.

## Let’s Deploy

Let’s take a look at `twitter-svc.yaml`

```bash
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: twitter
spec:
  template:
    spec:
      containers:
      - image: gcr.io/<YOUR PROJECT>/twitter-producer:v1
        imagePullPolicy: Always
```

This is a simple Knative service that uses that twitter-sink container that we created earlier. Let’s deploy it.

```bash
kubectl apply -f twitter-svc.yaml
```

Next we will look at `twitter-sink.yaml`

```bash
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: twitter-event-viewer
spec:
  template:
    spec:
      containers:
      - image: gcr.io/<YOUR PROJECT>/event-viewer:v1
        imagePullPolicy: Always
```

This will be our “Event Sink”. A simple way to view this is as the event consumer. This is where Knative Eventing will ultimately send the events to be consumed. Let’s deploy this.

```bash
kubectl apply -f twitter-sink.yaml
```

Finally, let’s open `twitter-sink-binding.yaml`.

```bash
apiVersion: sources.knative.dev/v1alpha2
kind: SinkBinding
metadata:
  name: twitter-bind
spec:
  subject:
    apiVersion: serving.knative.dev/v1
    kind: Service
    name: twitter
  sink:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: twitter-event-viewer
```

You can see that this object kind is **SinkBinding**. In the most basic of terms, this will bind a Kubernetes spec to a Sink. With the old **ContainerSource** method, you would essentially bind a Deployment to a Sink. This was useful for many use cases but also limiting as you could only bind to a Deployment. Now you are able to bind to DaemonSets, Jobs, StatefulSets, Knative Services & Configurations, and of course Deployments.

If you examine the `spec.subject.kind` you will see that we are binding to a Knative Service called “twitter-event-viewer”. The Knative service is that same code from earlier. It will act as the event **producer**.

The`spec.sink` is where you define the **consumer**. In my example, we will be using another Knative service to consume the events. Remember that `event-viewer` container that we created? That will be used in our Knative Service.

Let’s go ahead and deploy the binding

```bash
kubectl apply -f twitter-sink-binding.yaml
```

So let’s take a look at what happened.

```bash
$ kubectl get pods
NAME                                                    READY   STATUS    RESTARTS   AGE
twitter-event-viewer-rqj4f-deployment-5886bd7f6-5pwvv   2/2     Running   0          18s
$ kubectl logs twitter-event-viewer-rqj4f-deployment-5886bd7f6-5pwvv -c user-container
[2020-04-01 23:22:09 +0000] [1] [INFO] Starting gunicorn 19.9.0
[2020-04-01 23:22:09 +0000] [1] [INFO] Listening at: http://0.0.0.0:8080 (1)
[2020-04-01 23:22:09 +0000] [1] [INFO] Using worker: threads
[2020-04-01 23:22:09 +0000] [8] [INFO] Booting worker with pid: 8
[2020-04-01 23:22:09 +0000] [8] [INFO] Event Display starting
[2020-04-01 23:22:11 +0000] [8] [INFO] Event Display received event: ["{\"msg\": <YOUR TWEETS>...
```

## What Happened

Our `twitter-producer` application acts an event producer that runs on a 30 second loop and checks Twitter for tweet matching the search criteria that you set. It will then send those events to our sink `event-viewer` application. In order to view what’s being sent, we just need to read the container logs. You will see a series of tweets come in. If you ran this every 30 seconds, you should see another set of tweets.
