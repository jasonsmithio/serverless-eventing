#!/usr/bin/env bash


#### Declare MYROOT directory for cloned repo
export MYROOT=$(pwd)
clear 


### install Google Cloud SDK
if ! [ -x "$(command -v gcloud)" ]; then
    echo "***** Installing Google Cloud SDK *****"
    if [[ "$OSTYPE"  == "linux-gnu" ]]; then
        curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-266.0.0-linux-x86_64.tar.gz -o google-cloud-sdk-266.0.0-linux-x86_64.tar.gz
        tar xf google-cloud-sdk-266.0.0-linux-x86_64.tar.gz && ./google-cloud-sdk/install.sh
        echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile
        #source ~/.profile
        export PATH=$PATH:/usr/local/go/bin
        gcloud auth login

    elif [[ "$OSTYPE" == "darwin"* ]]; then
        curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-266.0.0-darwin-x86_64.tar.gz -o google-cloud-sdk-266.0.0-darwin-x86_64.tar.gz
        tar xf google-cloud-sdk-266.0.0-darwin-x86_64.tar.gz && ./google-cloud-sdk/install.sh
        echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bash_profile
        #source ~/.bash_profile
        export PATH=$PATH:/usr/local/go/bin
        gcloud auth login
    else
        echo "unknown OS"
    fi
    gcloud init
    exit 1
else 
    echo "Google Cloud SDK is already installed. Let's move on"
fi

sleep 10

#### BoilerPlate Code for
cd $MYROOT

clear
echo "******Setting Variables******"

if [[ "$OSTYPE"  == "linux-gnu" ]]; then
    export MYOS='linux'
elif [[ "$OSTYPE" == "darwin"* ]]; then
    export MYOS='osx'
else
    echo "unknown OS type"
fi

if [ -z "$CLUSTER_NAME" ]
then
    export CLUSTER_NAME='gke-knative'
fi

if [ -z "$KVERSION" ]
then
    export KVERSION='0.17.0'
fi

if [ -z "$PROJECT_ID" ]
then
    export PROJECT_ID=$(gcloud config get-value project)
fi

if [ -z "$ZONE" ]
then
    export ZONE='us-central1-a'
fi

export PROJ_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
export KO_DOCKER_REPO='gcr.io/'${PROJECT_ID}

### Setup Basic Environment
clear
echo "***** Setting Project and Zone *****"
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE

echo "***** Making sure you have APIs ready to go *****"
gcloud services enable container.googleapis.com \
containerregistry.googleapis.com \
cloudbuild.googleapis.com \
cloudkms.googleapis.com \
storage-api.googleapis.com \
storage-component.googleapis.com \
secretmanager.googleapis.com \
cloudscheduler.googleapis.com


echo "****** We will make sure the Google Cloud SDK is running beta components and kubectl ******"
gcloud components update
gcloud components install beta
gcloud components install kubectl

# Setup gcloud Docker
echo 'Configuring GCloud to work with Docker'
gcloud auth configure-docker


### Creating Cluster
clear
echo "******Now we shall create your cluster******"
gcloud beta container clusters create $CLUSTER_NAME \
--addons HorizontalPodAutoscaling,HttpLoadBalancing,Istio  \
	--zone=$ZONE \
    --cluster-version=latest \
    --enable-stackdriver-kubernetes \
    --enable-ip-alias \
    --enable-autoscaling --min-nodes=1 --max-nodes=10 \
    --enable-autorepair \
	--machine-type=n1-standard-2 \
	--scopes=cloud-platform 

#	--cluster-version=1.15.7-gke.2 \

#wait for 90 seconds
echo "***** Waiting for 90 second for cluster to complete *****"
sleep 90

# Authenticate with cluster
gcloud container clusters get-credentials $CLUSTER_NAME

# Permissions
echo "Setting up cluster permissions"
kubectl create clusterrolebinding cluster-admin-binding \
--clusterrole=cluster-admin \
--user=$(gcloud config get-value core/account)

########## KNATIVE

### Knative Serving
kubectl apply --filename https://github.com/knative/serving/releases/download/v${KVERSION}/serving-crds.yaml
kubectl apply --filename https://github.com/knative/serving/releases/download/v${KVERSION}/serving-core.yaml


## Installing Istio Knative Components
echo "Installing Istio Knative Components"
kubectl apply --filename https://github.com/knative/net-istio/releases/download/v${KVERSION}/release.yaml

#Install Magic DNS (xip.io)
echo "Installing Magic DNS to Knative Serving"
kubectl apply --filename https://github.com/knative/serving/releases/download/v${KVERSION}/serving-default-domain.yaml


#### INSTALL KNATIVE EVENTING
kubectl apply --filename https://github.com/knative/eventing/releases/download/v${KVERSION}/eventing-crds.yaml

kubectl apply --filename https://github.com/knative/eventing/releases/download/v${KVERSION}/eventing-core.yaml

## Channel and Broker

kubectl apply --filename https://github.com/knative/eventing/releases/download/v${KVERSION}/in-memory-channel.yaml

kubectl apply --filename https://github.com/knative/eventing/releases/download/v${KVERSION}/mt-channel-broker.yaml

## Setup Broker
kubectl label namespace default knative-eventing-injection=enabled


## Enable Secret Admin to compute service account
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$PROJ_NUMBER-compute@developer.gserviceaccount.com --role roles/secretmanager.admin


## Install Tekton
#echo "Installing Tekton"
#kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml