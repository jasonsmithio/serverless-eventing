#!/usr/bin/env bash
### THIS IS A TEST SCRIPT

while getops k:g:c: flag; do
    case "${flag}" in
        k) kversion=${OPTARG};;
        g) gke=${OPTARG};;
        c) clustername=${OPTARG};;
        ?) echo "Error: Invalid option was specified -- ${OPTARG}";;
    esac
done


if [[ "$OSTYPE"  == "linux-gnu" ]]; then
    export MYOS='linux'
elif [[ "$OSTYPE" == "darwin"* ]]; then
    export MYOS='osx'
else
    echo "unknown OS type"
fi


# Flag input check and assignment
if [ -z "$kversion" ]
then
    export KVERSION='0.16.0'
else
    export KVERSION=$kversion
fi


if [ -z "$gke" ]
then
    export GKE='1.16.13-gke.400'
else
    export GKE=$gke
fi


if [ -z "$clustername" ]
then
    export CLUSTER_NAME='cr-knative-test'
else
    export CLUSTER_NAME=$clustername
fi



### AUTO DECLARE VARIABLES

export ZONE='us-west1-a'
#export PROJECT_ID=$(gcloud config get-value project)
export PROJ_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
export KO_DOCKER_REPO='gcr.io/'${PROJECT_ID}


### PREP CLOUDRUN

gcloud config set run/platform gke
gcloud config set project ${PROJECT_ID}


gcloud beta container clusters create ${CLUSTER_NAME} \
  --addons=HttpLoadBalancing,CloudRun \
  --machine-type=n1-standard-2 \
  --cluster-version=${GKE} \
  --enable-ip-alias \
  --enable-stackdriver-kubernetes \
  --zone=${ZONE}


  #########CLOUD RUN###############
  #gcloud container clusters create ${CLUSTER_NAME} \
  #--addons=HttpLoadBalancing,CloudRun \
  #--machine-type=n1-standard-2 \
  #--cluster-version=${GKE} \
  #--enable-stackdriver-kubernetes \
  #--zone=${ZONE}


gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${ZONE} --project ${PROJECT_ID}

# Permissions
echo "Setting up cluster permissions"
kubectl create clusterrolebinding cluster-admin-binding \
--clusterrole=cluster-admin \
--user=$(gcloud config get-value core/account)


########## KNATIVE

### Knative Serving
kubectl apply --filename https://github.com/knative/serving/releases/download/v${KVERSION}/serving-crds.yaml
kubectl apply --filename https://github.com/knative/serving/releases/download/v${KVERSION}/serving-core.yaml




## INSTALL ISTIO
echo "Installing Istio 1.5.7 for Knative Serving"
# Download and unpack Istio
ISTIO_VERSION=1.5.10
ISTIO_TARBALL=istio-${ISTIO_VERSION}-${MYOS}.tar.gz
DOWNLOAD_URL=https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/${ISTIO_TARBALL}

curl -L ${DOWNLOAD_URL} | tar xz
if [ $? != 0 ]; then
  echo "Failed to download Istio package"
  exit 1
fi
#tar xzf ${ISTIO_TARBALL} 

#Install Istio
chmod +x ./istio-${ISTIO_VERSION}/bin/istioctl
./istio-${ISTIO_VERSION}/bin/istioctl manifest apply
#./istio-${ISTIO_VERSION}/bin/istioctl manifest apply -f "$(dirname $0)/$1"




# Clean up
rm -rf istio-${ISTIO_VERSION}
#rm ${ISTIO_TARBALL}

##This installs Istio Development
# https://raw.githubusercontent.com/knative-sandbox/net-istio/master/third_party/istio-1.5.7/istio-minimal.yaml

# This is no mesh
# https://raw.githubusercontent.com/knative-sandbox/net-istio/master/third_party/istio-1.5.7/istio-ci-no-mesh.yaml

## This is mesh
# https://raw.githubusercontent.com/knative-sandbox/net-istio/master/third_party/istio-1.5.7/istio-ci-mesh.yaml

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
