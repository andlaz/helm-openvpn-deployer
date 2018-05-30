FROM ubuntu:16.04
MAINTAINER andras.szerdahelyi@gmail.com

ARG KUBECTL_VERSION=1.10.2-00
RUN apt-get update && \
    apt-get install -y curl jq apt-transport-https && \
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl=$KUBECTL_VERSION openvpn inetutils-ping supervisor

ARG HELM_VERSION=v2.8.2
RUN curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > /install-helm.sh && \
    chmod +x /install-helm.sh && \
    /install-helm.sh --version $HELM_VERSION && \
    helm init --client-only

COPY util/* /
ENV OVPN=/vpn/cluster.ovpn

