#!/usr/bin/env bash

kubectl config set-cluster target-cluster \
  --embed-certs=true \
  --server=$K8S_ENDPOINT \
  --certificate-authority=$K8S_CERT && \
kubectl config set-credentials $SERVICE_ACCOUNT --token=$SERVICE_TOKEN && \
kubectl config set-context $SERVICE_ACCOUNT-target-cluster \
  --cluster=target-cluster \
  --user=$SERVICE_ACCOUNT \
  --namespace=$NAMESPACE && \
kubectl config use-context $SERVICE_ACCOUNT-target-cluster