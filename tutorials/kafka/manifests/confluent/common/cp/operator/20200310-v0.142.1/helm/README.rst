Introduction
============

Helm is an open-source packaging tool that helps you install applications and services on kubernetes. Helm uses a packaging format called charts. Charts are a collection of YAML templates that describes a related set of kubernetes resources.

This Helm chart deploys Confluent Operator which helps to automate tasks related to operating Kafka cluster.

https://docs.confluent.io/current/installation/operator/index.html

Helm Chart
==========

`Install helm <https://docs.helm.sh/using_helm/#installing-helm>`__

Tiller and Role-Base Access Control (RBAC)
==========================================

Configure RBAC to give ``tiller`` permission to deploy the Confluent Operator in any namespace.

::

    $ kubectl create serviceaccount tiller -n kube-system
    $ kubectl create clusterrolebinding tiller --clusterrole=cluster-admin --serviceaccount kube-system:tiller
    $ helm init --service-account tiller


Helm Chart Configurations
=========================

The following table lists the configuration parameters and its `default values <./confluent-operator/values.yaml>`_

Install Confluent Operator through Helm Charts
==============================================

Deploy the Confluent Operator in a namespace ``operator`` on ``AWS`` Platform.
For other Platform, use the following Helm commands with appropriate overridden values as an argument.

Take a look at the providers/ folder for more examples.

==========================
Install Confluent Operator
==========================

::

    helm install -f ./providers/aws.yaml --name operator --namespace operator --set operator.enabled=true ./confluent-operator

=================================
Install Zookeeper Custom Resource
=================================

Run the command below once the Confluent Operator pod is up and running:

::

    helm install -f ./providers/aws.yaml --name zookeeper  --namespace operator --set zookeeper.enabled=true ./confluent-operator

=============================
Install Kafka Custom Resource
=============================

Run the commands below once the Zookeeper pods are up and running:

::

    helm install -f ./providers/aws.yaml --name kafka --namespace operator --set kafka.enabled=true ./confluent-operator

All external and internal endpoints of the Kafka Cluster are displayed after the completion of Helm command execution.

=======================
Install Connect Cluster 
=======================

::

    helm install -f ./providers/aws.yaml --name connect --namespace operator --set connect.enabled=true ./confluent-operator

Use REST endpoints to configure connectors

=======================
Install Schema Registry
=======================

::

    helm install -f ./providers/aws.yaml --name schemaregistry --namespace operator --set schemaregistry.enabled=true ./confluent-operator

Use REST endpoints to configure schemaregistry

==================
Install Replicator
==================

::

    helm install -f ./providers/aws.yaml --name replicator --namespace operator --set replicator.enabled=true ./confluent-operator


Use REST endpoints to configure replicator

=====================
Install ControlCenter
=====================

::

    helm install -f ./providers/aws.yaml --name controlcenter --namespace operator --set controlcenter.enabled=true ./confluent-operator

============
Install KSQL
============

::

    helm install -f ./providers/aws.yaml --name ksql --namespace operator --set ksql.enabled=true ./confluent-operator



===============
Upgrade Cluster
===============

Updates any default values of the charts by updating ``./providers/aws.yaml`` before running ``helm upgrade``

::

    helm upgrade -f ./providers/aws.yaml --set operator.enabled=true operator confluent-operator
    helm upgrade -f ./providers/aws.yaml --set zookeeper.enabled=true zookeeper confluent-operator
    helm upgrade -f ./providers/aws.yaml --set kafka.enabled=true kafka confluent-operator
    helm upgrade -f ./providers/aws.yaml --set controlcenter.enabled=true controlcenter confluent-operator
    helm upgrade -f ./providers/aws.yaml --set schemaregistry.enabled=true schemaregistry confluent-operator
    helm upgrade -f ./providers/aws.yaml --set connect.enabled=true connect confluent-operator
    helm upgrade -f ./providers/aws.yaml --set replicator.enabled=true replicator confluent-operator
    helm upgrade -f ./providers/aws.yaml --set ksql.enabled=true ksql confluent-operator

==============
Delete Cluster
==============

::

    helm delete --purge ksql
    helm delete --purge controlcenter
    helm delete --purge schemaregistry
    helm delete --purge connect
    helm delete --purge replicator
    helm delete --purge kafka
    helm delete --purge zookeeper
    helm delete --purge operator
    kubectl delete namespace operator


::

    kubectl delete pod -l type=kafka --force --grace-period=0 -n operator
    kubectl delete pod -l type=zookeeper --force --grace-period=0 -n operator

