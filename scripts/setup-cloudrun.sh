#!/usr/bin/env bash


#### Declare MYROOT directory for cloned repo
export MYROOT=$(pwd)
clear 


### install Google Cloud SDK
if ! [ -x "$(command -v gcloud)" ]; then
    echo "***** Installing Google Cloud SDK *****"
    if [[ "$OSTYPE"  == "linux-gnu" ]]; then
        curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-317.0.0-linux-x86_64.tar.gz -o google-cloud-sdk-317.0.0-linux-x86_64.tar.gz
        tar xf google-cloud-sdk-266.0.0-linux-x86_64.tar.gz && ./google-cloud-sdk/install.sh
        echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile
        #source ~/.profile
        export PATH=$PATH:/usr/local/go/bin
        gcloud auth login

    elif [[ "$OSTYPE" == "darwin"* ]]; then
        curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-317.0.0-darwin-x86_64.tar.gz -o google-cloud-sdk-317.0.0-darwin-x86_64.tar.gz
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


sleep 5

#### BoilerPlate Code for
cd $MYROOT

clear
echo "******Setting Variables******"

if [ -z "$CLUSTER_NAME" ]
then
    export CLUSTER_NAME='cr-knative'
fi

export ZONE='us-central1-a'
export PROJECT_ID=$(gcloud config get-value project)
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
    --addons=HttpLoadBalancing,CloudRun  \
	--zone=$ZONE \
    --enable-stackdriver-kubernetes \
    --enable-ip-alias \
    --enable-autoscaling --min-nodes=1 --max-nodes=10 \
    --enable-autorepair \
	--machine-type=n1-standard-4 \
    --num-nodes=3 \
	--scopes=cloud-platform \
    --release-channel=regular

#	--cluster-version=1.15.12-gke.9 \ \
#   --addons=Istio,HttpLoadBalancing,CloudRun  \
#   --istio-config=auth=MTLS_PERMISSIVE \

#wait for 90 seconds
echo "***** Waiting for 90 seconds for cluster to complete *****"
sleep 90

# Configure Cloud Run with Cluster
gcloud config set run/platform gke
gcloud config set run/cluster $CLUSTER_NAME
gcloud config set run/cluster_location $ZONE
gcloud container clusters get-credentials $CLUSTER_NAME

# Permissions
echo "Setting up cluster permissions"
kubectl create clusterrolebinding cluster-admin-binding \
--clusterrole=cluster-admin \
--user=$(gcloud config get-value core/account)

###ISTIO?  https://github.com/knative/serving/blob/master/DEVELOPMENT.md#deploy-istio
# kubectl apply -f https://raw.githubusercontent.com/knative-sandbox/net-istio/master/third_party/istio-1.5.7-helm/istio-crds.yaml
#kubectl apply -f https://raw.githubusercontent.com/knative-sandbox/net-istio/master/third_party/istio-1.5.7-helm/istio-minimal.yaml

# cluster local gateway
# kubectl get service cluster-local-gateway -n istio-system

# Istio for 0.16
# kubectl apply -f https://raw.githubusercontent.com/knative/serving/master/third_party/istio-1.4.9/istio-knative-extras.yaml

# Istio for 0.17
##kubectl apply --filename https://raw.githubusercontent.com/knative/serving/master/third_party/net-istio.yaml
#kubectl apply --filename https://github.com/knative/net-istio/releases/download/v0.17.0/release.yaml


##### Get istio-gateway external IP
echo "****** We are going to grab the external IP ******"
export EXTERNAL_IP=$(kubectl get service istio-ingress --namespace gke-system | awk 'FNR == 2 {print $4}')

echo $EXTERNAL_IP

echo "***** We will now patch configmap for domain ******"
kubectl patch configmap config-domain --namespace knative-serving --patch \
'{"data": {"example.com": null, "'"$EXTERNAL_IP"'.xip.io": ""}}'

## Install Knative Eventing
## https://knative.dev/docs/install/any-kubernetes-cluster/#installing-the-eventing-component


echo "Install Knative Eventing"
kubectl apply --filename https://github.com/knative/eventing/releases/download/v0.18.0/eventing-crds.yaml

echo "***** Waiting for 45 seconds for Knative Eventing CRDs to Install  *****"
sleep 45

kubectl apply --filename https://github.com/knative/eventing/releases/download/v0.18.0/eventing-core.yaml

echo "***** Waiting for 30 seconds for Knative Eventing Core to Install  *****"
sleep 30

#install Channels

kubectl apply --filename https://github.com/knative/eventing/releases/download/v0.16.0/mt-channel-broker.yam \
--filename https://github.com/knative/eventing/releases/download/v0.16.0/in-memory-channel.yaml



# Install Advanced Monitoring
#kubectl apply --filename https://github.com/knative/serving/releases/download/v0.17.0/monitoring-core.yaml \
#--filename https://github.com/knative/serving/releases/download/v0.17.0/monitoring-metrics-prometheus.yaml

# Setup Broker
kubectl label namespace default knative-eventing-injection=enabled


# Enable Secret Admin to compute service account
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$PROJ_NUMBER-compute@developer.gserviceaccount.com --role roles/secretmanager.admin
