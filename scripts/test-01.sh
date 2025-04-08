#!/usr/bin/env bash

# Test case for communications according to only static configurations

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

## communication-busybox-1 ##

curl -X POST 'http://localhost:8081/send' \
 -H 'Content-Type: application/json' \
 -d "{\"topic\": \"busybox-1-topic-1\", \"key\": \"$(uuidgen)\", \"message\": \"Hello from service-1 through kafka\"}"

curl -X POST 'http://localhost:8081/call' \
 -H 'Content-Type: application/json' \
 -d '{"url": "communication-busybox-2", "payload": {"message": "Hello from service-1 over REST"}}'

## communication-busybox-2 ##

curl -X POST 'http://localhost:8082/send' \
 -H 'Content-Type: application/json' \
 -d "{\"topic\": \"busybox-2-topic-1\", \"key\": \"$(uuidgen)\", \"message\": \"Hello from service-2 through kafka\"}"

curl -X POST 'http://localhost:8082/send' \
 -H 'Content-Type: application/json' \
 -d "{\"topic\": \"busybox-2-topic-2\", \"key\": \"$(uuidgen)\", \"message\": \"Hello from service-2 through kafka\"}"

curl -X POST 'http://localhost:8082/call' \
 -H 'Content-Type: application/json' \
 -d '{"url": "communication-busybox-1", "payload": {"message": "Hello from service-2 over REST"}}'

## communication-busybox-3 ##

curl -X POST 'http://localhost:8083/call' \
 -H 'Content-Type: application/json' \
 -d '{"url": "communication-busybox-1", "payload": {"message": "Hello from service-3 over REST"}}'

curl -X POST 'http://localhost:8083/call' \
 -H 'Content-Type: application/json' \
 -d '{"url": "communication-busybox-2", "payload": {"message": "Hello from service-3 over REST"}}'

## communication-busybox-4 ##

curl -X POST 'http://localhost:8084/send' \
 -H 'Content-Type: application/json' \
 -d "{\"topic\": \"busybox-4-topic-1\", \"key\": \"$(uuidgen)\", \"message\": \"Hello from service-4 through kafka\"}"

curl -X POST 'http://localhost:8084/send' \
 -H 'Content-Type: application/json' \
 -d "{\"topic\": \"busybox-4-topic-2\", \"key\": \"$(uuidgen)\", \"message\": \"Hello from service-4 through kafka\"}"

curl -X POST 'http://localhost:8084/send' \
 -H 'Content-Type: application/json' \
 -d "{\"topic\": \"busybox-2-topic-1\", \"key\": \"$(uuidgen)\", \"message\": \"Hello from service-4 through kafka\"}"

curl -X POST 'http://localhost:8084/call' \
 -H 'Content-Type: application/json' \
 -d '{"url": "communication-busybox-3", "payload": {"message": "Hello from service-4 over REST"}}'

## communication-busybox-5 ##

curl -X POST 'http://localhost:8085/call' \
 -H 'Content-Type: application/json' \
 -d '{"url": "communication-busybox-1", "payload": {"message": "Hello from service-5 over REST"}}'

curl -X POST 'http://localhost:8085/call' \
 -H 'Content-Type: application/json' \
 -d '{"url": "communication-busybox-2", "payload": {"message": "Hello from service-5 over REST"}}'

curl -X POST 'http://localhost:8085/call' \
 -H 'Content-Type: application/json' \
 -d '{"url": "communication-busybox-3", "payload": {"message": "Hello from service-5 over REST"}}'

curl -X POST 'http://localhost:8085/call' \
 -H 'Content-Type: application/json' \
 -d '{"url": "communication-busybox-4", "payload": {"message": "Hello from service-5 over REST"}}'

sleep 5

kill "$cb1_pid"
kill "$cb2_pid"
kill "$cb3_pid"
kill "$cb4_pid"
kill "$cb5_pid"