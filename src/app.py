from flask import Flask, request, jsonify
from confluent_kafka import Producer, Consumer, KafkaException
import requests
import os
import threading
import json

app = Flask(__name__)

# Kafka configuration
KAFKA_BROKER = os.getenv("KAFKA_BROKER", "localhost:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "default-topic")


def kafka_consumer():
    consumer = Consumer({
        "bootstrap.servers": KAFKA_BROKER,
        "group.id": "my-group",
        "auto.offset.reset": "earliest"
    })
    consumer.subscribe([KAFKA_TOPIC])
    while True:
        msg = consumer.poll(1.0)
        if msg is not None and msg.error() is None:
            print(f"Received message: {msg.value().decode('utf-8')}")


threading.Thread(target=kafka_consumer, daemon=True).start()

producer = Producer({"bootstrap.servers": KAFKA_BROKER})


@app.route("/send", methods=["POST"])
def send_message():
    data = request.json
    topic = data.get("topic", KAFKA_TOPIC)
    message = data.get("message", "Hello")
    producer.produce(topic, message.encode("utf-8"))
    producer.flush()
    return jsonify({"status": "Message sent", "topic": topic})


@app.route("/call", methods=["POST"])
def rest_call():
    data = request.json
    target_url = data.get("url")
    if not target_url:
        return jsonify({"error": "No target URL provided"}), 400

    response = requests.post(target_url, json=data.get("payload", {}))
    return jsonify({"response": response.json()})


@app.route("/receive", methods=["POST"])
def receive_message():
    data = request.json
    print(f"Received REST message: {json.dumps(data)}")
    return jsonify({"status": "Received"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
