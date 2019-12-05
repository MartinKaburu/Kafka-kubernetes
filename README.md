# Kafka-kubernetes
Kafka Architecture for Kubernetes deployment. This repository contains Kubernetes manifest files for deploying kafka bitnami image, zookeeper and all dependent resources to Kubernetes.

### Deploying to Kubernetes
- *This assumes that you have a fully setup Kubernetes cluster and that your kubectl CLI client is authorized to apply resources on your cluster.*
1. Apply the dependent resources in the order below.
```bash
kubectl apply -f kafka/storage-class.yml,kafka/persistent-volume-claim.yml,kafka/loadbalancer-service.yml,kafka/server-config.yml,zookeeper/headless-service.yml,zookeeper/service.yml
```

2. Apply Zookeeper.
```bash
kubectl apply -f zookeeper/statefulset.yml
```

3. Substitute AWS credentials in `kafka/statefulset.yml` for the init-container environment.

4. Apply Kafka statefulset.
```bash
kafka apply -f kafka/statefulset.yml
```
