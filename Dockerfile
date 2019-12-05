# Dockerfile for image to be used in init containers
# it requires the aws-cli and kubectl binary

FROM python:3.7-alpine

USER root

WORKDIR /

# jq is required for init script
RUN apk add --no-cache build-base curl bash jq

# install aws-cli
RUN curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" \
    && unzip awscli-bundle.zip \
    && ./awscli-bundle/install -b /bin/aws\
    && aws --version

# install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl\
    && chmod +x ./kubectl\
    && mv ./kubectl /bin/kubectl\
    && kubectl version --client
