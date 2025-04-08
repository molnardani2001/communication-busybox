#!/usr/bin/env bash

# Test case for dynamic communication between components, .Values.enableDynamicCommunication=true values must be set
# and env variable ENABLE_DYNAMIC_COMMUNICATION should have true value in the containers

# In this test every component, sends a kafka message to every other component and calls them over REST as well

topics=$(kubectl get kafkatopics -n molnardani -o json | jq -r '.items[].spec.topicName')
services=$(kubectl get svc -n molnardani -o json | jq -r '.items[].metadata.name' | grep "communication")

function make_sure_consumers_running() {
  local busybox_name="$1"
  local busybox_host="$2"
  for topic in $topics; do
    echo "Subscribe from $busybox_name to $topic as consumer"
    curl -X POST "http://$busybox_host/consume" -H 'Content-Type: application/json' -d "{\"topic\": \"$topic\"}"
  done
}

function produce_to_topic() {
  busybox_name="$1"
  busybox_host="$2"
  topic="$3"
  curl -X POST "http://$busybox_host/send" -H 'Content-Type: application/json' \
  -d "{\"topic\": \"$topic\", \"key\": \"$(uuidgen)\", \"message\": \"Hello from $busybox_name through kafka\"}"
}

function call_other_service() {
  busybox_name="$1"
  busybox_host="$2"
  other_busybox_name="$3"
  curl -X POST "http://$busybox_host/call" -H 'Content-Type: application/json' \
  -d "{\"url\": \"$other_busybox_name\", \"payload\": {\"message\": \"Hello from $busybox_name over REST\"}}"
}

kubectl port-forward svc/communication-busybox-1 8081:8080 -n molnardani &
cb1_pid=$!
echo "communication-busybox-1 pid: $cb1_pid"
kubectl port-forward svc/communication-busybox-2 8082:8080 -n molnardani &
cb2_pid=$!
echo "communication-busybox-2 pid: $cb2_pid"
kubectl port-forward svc/communication-busybox-3 8083:8080 -n molnardani &
cb3_pid=$!
echo "communication-busybox-3 pid: $cb3_pid"
kubectl port-forward svc/communication-busybox-4 8084:8080 -n molnardani &
cb4_pid=$!
echo "communication-busybox-4 pid: $cb4_pid"
kubectl port-forward svc/communication-busybox-5 8085:8080 -n molnardani &
cb5_pid=$!
echo "communication-busybox-5 pid: $cb5_pid"

# just to make sure every port-forward is working
sleep 3

declare -A service_host_mapping
service_host_mapping["communication-busybox-1"]="localhost:8081"
service_host_mapping["communication-busybox-2"]="localhost:8082"
service_host_mapping["communication-busybox-3"]="localhost:8083"
service_host_mapping["communication-busybox-4"]="localhost:8084"
service_host_mapping["communication-busybox-5"]="localhost:8085"

for service in $services; do
  make_sure_consumers_running "$service" "${service_host_mapping[$service]}"
done

for service in $services; do
  for topic in $topics; do
    echo "Producing message from $service to topic $topic"
    produce_to_topic "$service" "${service_host_mapping[$service]}" "$topic"
  done
done

for service1 in $services; do
  for service2 in $services; do
    if [[ "$service1" != "$service2" ]]; then
      echo "Calling $service2 from $service over REST"
      call_other_service "$service" "${service_host_mapping[$service]}" "$service2"
    fi
  done
done

kill "$cb1_pid"
kill "$cb2_pid"
kill "$cb3_pid"
kill "$cb4_pid"
kill "$cb5_pid"

