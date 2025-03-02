#!/usr/bin/bash

kubectl config use-context minikube
istioctl install --set profile=demo -y
kubectl get pods -n istio-system
#helm repo add kiali https://kiali.org/helm-charts
#helm repo update kiali
helm install --namespace kiali-operator --create-namespace kiali-operator kiali/kiali-operator
kubectl create namespace kafka-operator
helm install strimzi/strimzi-kafka-operator --namespace molnardani --generate-name
# kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.1/components.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml