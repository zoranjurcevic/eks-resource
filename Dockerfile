FROM ubuntu:impish-20211015

LABEL "author"="zoran.jurcevic@sky.uk"
LABEL "inspired-by"="ksuda@zlab.co.jp"

ARG KUBERNETES_VERSION=v1.21.0

# Do NOT update the next line manually, please use ./scripts/update-aws-iam-authenticator.sh instead
ARG AWS_IAM_AUTHENTICATOR_VERSION=v0.5.3

RUN set -x && \
    apt-get update && \
    apt-get install -y jq curl unzip && \
    # Download and install kubectl
    [ -z "$KUBERNETES_VERSION" ] && KUBERNETES_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt) ||: && \
    curl -s -LO https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    kubectl version --client && \
    # Download and install aws cli 
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    # Download and install helm
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh

RUN mkdir -p /opt/resource
COPY assets/* /opt/resource/
