#! /bin/bash

# This file is a replica of the kafka-server-config.yml init.sh data
# it updates the server.properties file by autogenerating values
# such as broker-id, external and internal listeners, annotating brokers
# and adding labels to pods

set -e
set -x

configure_kubectl(){
  mkdir -p  ~/.aws
  touch ~/.aws/credentials
  cat <<EOT > ~/.aws/credentials
[default]
aws_access_key_id = $AWS_ACCESS_KEY
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
region = $REGION
EOT
  aws eks --region ap-south-1 update-kubeconfig --name spincity-staging
  CONTEXT=$(aws eks --region $REGION update-kubeconfig --name $CLUSTER_NAME | awk '{print $3}')
  kubectl config use-context $CONTEXT
}

initialise_kafka(){
  KAFKA_BROKER_ID=${HOSTNAME##*-}
  SEDS=("s/#init#broker.id=#init#/broker.id=$KAFKA_BROKER_ID/")
  LABELS="kafka-broker-id=$KAFKA_BROKER_ID"
  ANNOTATIONS=""

  # check if kubectl is installed
  hash kubectl 2>/dev/null || {
    echo "kubectl not found in path."
    SEDS+=("s/#init#broker.rack=#init#/#init#broker.rack=# kubectl not found in path/")
    return 1
  } && {
    # set zone label
    ZONE=$(kubectl get node "$NODE_NAME" -o=go-template='{{index .metadata.labels "failure-domain.beta.kubernetes.io/zone"}}')
    if [[ "x$ZONE" == "x<no value>" ]]; then
      SEDS+=("s/#init#broker.rack=#init#/#init#broker.rack=# zone label not found for node $NODE_NAME/")
    else
      SEDS+=("s/#init#broker.rack=#init#/broker.rack=$ZONE/")
      LABELS="$LABELS kafka-broker-rack=$ZONE"
    fi

    # get external loadbalancer endpoint
    EXTERNAL_HOST=$(kubectl get svc "kafka-$KAFKA_BROKER_ID-lb" -o json -n $POD_NAMESPACE  | jq -r '.status.loadBalancer.ingress[0].hostname')
    EXTERNAL_PORT=9090

    # set internal and external listeners
    SEDS+=("s|#init#advertised.listeners=PLAINTEXT://#init#|advertised.listeners=INTERNAL://kafka-${KAFKA_BROKER_ID}.kafka-headless:9092,EXTERNAL://${EXTERNAL_HOST}:${EXTERNAL_PORT}|")
    ANNOTATIONS="$ANNOTATIONS kafka-listener-outside-host=$EXTERNAL_HOST kafka-listener-outside-port=$EXTERNAL_PORT"

    # apply labels and annotations
    if [[ ! -z "$LABELS" ]]; then
      LABELS="$LABELS kafka-set-component=kafka-$KAFKA_BROKER_ID"
      kubectl -n $POD_NAMESPACE label pod $POD_NAME $LABELS --overwrite || echo "Failed to label $POD_NAMESPACE.$POD_NAME - RBAC issue?"
    fi
    if [[ ! -z "$ANNOTATIONS" ]]; then
      kubectl -n $POD_NAMESPACE annotate pod $POD_NAME $ANNOTATIONS --overwrite || echo "Failed to annotate $POD_NAMESPACE.$POD_NAME - RBAC issue?"
    fi
  }

  # execute sed statements
  printf '%s\n' "${SEDS[@]}" | sed -f - /bitnami/kafka/server.properties > /opt/bitnami/kafka/conf/server.properties
  [[ $? -eq 0 ]] && cat /opt/bitnami/kafka/conf/server.properties
}


main() {
  configure_kubectl
  initialise_kafka
}

main
