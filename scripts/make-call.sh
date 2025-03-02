#!/usr/bin/env bash

curl -X POST 'http://localhost:8080/call' \
 -H 'Content-Type: application/json' \
 -d '{"url": "demo-app-1-communication-busybox-1", "payload": {"message": "Hello from curl through istio"}}'

curl -X POST 'http://localhost:8080/send' \
 -H 'Content-Type: application/json' \
 -d '{"topic": "busybox-1-topic-1", "message": "Hello service-2 through kafka"}'