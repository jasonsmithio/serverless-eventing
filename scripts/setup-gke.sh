#!/usr/bin/env bash

#### logging 
exec > >(tee -i logfile.txt)

#### Declare MYROOT directory for cloned repo
export MYROOT=$(pwd)
clear 

### install golang v1.13.1

mkdir ~/.golang
cd ~/.golang
if ! [ -x "$(command -v go)" ]; then
    echo "***** Installing GoLang v1.13.1 *****"
    if [[ "$OSTYPE"  == "linux-gnu" ]]; then
        curl https://dl.google.com/go/go1.13.1.linux-amd64.tar.gz -o go1.13.1.linux-amd64.tar.gz
        sudo tar -C /usr/local -xzf go1.13.1.linux-amd64.tar.gz
        echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile
        #source ~/.profile
        export PATH=$PATH:/usr/local/go/bin

    elif [[ "$OSTYPE" == "darwin"* ]]; then
        curl https://dl.google.com/go/go1.13.1.darwin-amd64.tar.gz -o go1.13.1.darwin-amd64.tar.gz
        sudo tar -C /usr/local -xzf go1.13.1.darwin-amd64.tar.gz
        echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bash_profile
        #source ~/.bash_profile
        export PATH=$PATH:/usr/local/go/bin
    else
        echo "unknown OS"
    fi
else 
    echo "GoLang is already installed. Let's move on"
fi

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

sleep 30

#### BoilerPlate Code for
cd $MYROOT

clear
echo "******Setting Variables******"

export ZONE='us-central1-a'
export PROJECT_ID=$(gcloud config get-value project)
export PROJ_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
export BUCKET_ID='my-secrets'
export CLUSTER_NAME='gke-knative'
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
    --enable-stackdriver-kubernetes --enable-ip-alias \
    --enable-autoscaling --min-nodes=1 --max-nodes=10 \
    --enable-autorepair \
	--machine-type=n1-standard-4 \
	--scopes=cloud-platform 

#	--cluster-version=1.15.7-gke.2 \

#wait for 90 seconds
echo "***** Waiting for 90 second for cluster to complete *****"
sleep 90

# Configure Cloud Run with Clust
gcloud config set run/platform gke
gcloud config set run/cluster $CLUSTER_NAME
gcloud config set run/cluster_location $ZONE
gcloud container clusters get-credentials $CLUSTER_NAME

# Permissions
echo "Setting up cluster permissions"
kubectl create clusterrolebinding cluster-admin-binding \
--clusterrole=cluster-admin \
--user=$(gcloud config get-value core/account)

##### Get istio-gateway external IP
echo "****** We are going to grab the external IP ******"
export EXTERNAL_IP=$(kubectl get service istio-ingressgateway --namespace istio-system | awk 'FNR == 2 {print $4}')

echo $EXTERNAL_IP

echo "***** We will now patch configmap for domain ******"
kubectl patch configmap config-domain --namespace knative-serving --patch \
'{"data": {"example.com": null, "'"$EXTERNAL_IP"'.xip.io": ""}}'

## Install Knative Eventing
echo "Install Knative Serving and Eventing"
kubectl apply --selector knative.dev/crd-install=true \
--filename https://github.com/knative/serving/releases/download/v0.13.0/serving-crds.yaml \
--filename https://github.com/knative/eventing/releases/download/v0.13.0/eventing-crds.yaml 

kubectl apply --filename https://github.com/knative/serving/releases/download/v0.13.0/serving-core.yaml \
--filename https://github.com/knative/eventing/releases/download/v0.13.0/eventing-core.yaml \
--filename https://github.com/knative/serving/releases/download/v0.13.0/monitoring-core.yaml


# Install Advanced Monitoring
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.13.0/monitoring-metrics-prometheus.yaml \
--filename https://github.com/knative/serving/releases/download/v0.13.0/monitoring-logs-elasticsearch.yaml \
--filename https://github.com/knative/serving/releases/download/v0.13.0/monitoring-tracing-jaeger.yaml

#Install Tekton
echo "Installing Tekton"
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml