## Overview

This is a docker image with kubectl + helm + jq + openvpn. You can use it to connect to an openvpn gateway and interact with a Kubernetes API server via `kubectl` or with Tiller via `helm`

## Build

```bash
docker build --build-arg HELM_VERSION=v2.8.2 --build-arg KUBECTL_VERSION=1.10.2-00 -t andlaz/helm-openvpn-deployer .
```

## Usage

### Image environment variables

OVPN - path to the openvpn client config file in the container
K8S_CERT - path to the Kubernetes API public certificate in the container
K8S_ENDPOINT - Kubernetes API endpoint URL
SERVICE_ACCOUNT - Kubernetes service account name to use in the kubectl context
SERVICE_TOKEN - The above service account's token to use in the kubectl context
NAMESPACE - Namespace to use in the kubectl context

#### Examples

##### OpenVPN tunnel

The below command will:
1. Mount and configure your ovpn file
2. Create `/dev/net/tun` in the container
3. Have supervisord daemonize an openvpn client

```bash
OVPN_DIR=$HOME/vpn-config; OVPN=cluster.ovpn;
docker run --cap-add=NET_ADMIN -v $OVPN_DIR:/vpn -e OVPN=/vpn/$OVPN -ti --rm andlaz/helm-openvpn-deployer /bin/bash -c '/create-device.sh && supervisord -c /openvpn-client.conf && sleep 3 && tail -f /var/log/openvpn.log'
```

##### ( optional ) Getting a service token

The below requires that you have a working kubectl context configured

###### Create the service account

Create a service account ( `deployer` in the examples and snippets below ) with
the roles of your choice. If you only need this service account to access
the tiller gRPC port, you can use

```bash
NAMESPACE='my-namespace'; \
kubectl apply -n $NAMESPACE -f manifests/tiller-deployer/
```

###### Get the service token for the above account and the cluster public cert

```bash
export NAMESPACE='my-namespace' && \
export K8S_CERT_DIR=/tmp/cluster && \
export SERVICE_ACCOUNT=tiller-deployer && \
export SECRET_NAME=$(kubectl get serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE -o json | jq -r .secrets[].name) && \
mkdir -p $K8S_CERT_DIR && \
export TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o json | jq -r '.data["token"]' | base64 -D) && \
kubectl get secret $SECRET_NAME -n $NAMESPACE -o json | jq -r '.data["ca.crt"]' | base64 -D > $K8S_CERT_DIR/ca.crt
```

##### Run a kubectl command against the cluster

Assuming ( you ran the above, or )
- the cluster public cert is at `$K8S_CERT_DIR/ca.crt`
- the namespace to use in `$NAMESPACE`
- the service account name in `$SERVICE_ACCOUNT`
- the service account token in `$TOKEN`
- the cluster api endpoint is in the kubectl current context

```bash
# Get API endpoint from current context 
export CONTEXT=$(kubectl config current-context) && \
export CLUSTER_NAME=$(kubectl config get-contexts $CONTEXT | awk '{print $3}' | tail -n 1) && \
export K8S_ENDPOINT=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$CLUSTER_NAME\")].cluster.server}") && \
docker run -v $K8S_CERT_DIR:/cluster -ti --rm \
-e K8S_ENDPOINT=https://10.11.1.158:6443 -e K8S_CERT=/cluster/ca.crt \
-e SERVICE_ACCOUNT=$SERVICE_ACCOUNT -e NAMESPACE=$NAMESPACE \
-e SERVICE_TOKEN=$TOKEN \
andlaz/helm-openvpn-deployer /bin/bash -c \
'/kubectl-config.sh && kubectl get pods -n $NAMESPACE'
```

##### Run a helm command against Tiller, after connecting to OpenVPN

Assuming ( you ran the above, or )
- your OpenVPN client config in `$OVPN_DIR/$OVPN`
- the cluster public cert is at `$K8S_CERT_DIR/ca.crt`
- the namespace to use in `$NAMESPACE`
- the service account name in `$SERVICE_ACCOUNT`
- the service account token in `$TOKEN`
- the cluster api endpoint is in the kubectl current context


```bash
export K8S_CERT_DIR=/tmp/cluster && \
# Get API endpoint from current context 
export CONTEXT=$(kubectl config current-context) && \
export CLUSTER_NAME=$(kubectl config get-contexts $CONTEXT | awk '{print $3}' | tail -n 1) && \
export K8S_ENDPOINT=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$CLUSTER_NAME\")].cluster.server}") && \

# Set API endpoint explicitly
# export K8S_ENDPOINT=https://1.2.3.4:6443 && \
OVPN_DIR=$HOME/vpn-config; \
OVPN=cluster.ovpn; \
docker run -ti --rm --cap-add=NET_ADMIN \
-v $K8S_CERT_DIR:/cluster -v $OVPN_DIR:/vpn \
-e OVPN=/vpn/$OVPN \
-e K8S_ENDPOINT=$K8S_ENDPOINT -e K8S_CERT=/cluster/ca.crt \
-e SERVICE_ACCOUNT=$SERVICE_ACCOUNT -e NAMESPACE=$NAMESPACE \
-e SERVICE_TOKEN=$TOKEN \
andlaz/helm-openvpn-deployer /bin/bash -c \
'/create-device.sh && \
/kubectl-config.sh && \
supervisord -c /openvpn-client.conf && \
sleep 10 && \
# ^ TODO verify openvpn tunnel is up..
helm ls --all --tiller-namespace $NAMESPACE'
```