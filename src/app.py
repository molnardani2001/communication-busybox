from flask import Flask, request, jsonify
from confluent_kafka import Producer, Consumer, KafkaException
import requests
import os
import threading
import json
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
)


app = Flask(__name__)

# Kafka configuration
KAFKA_BROKER = os.getenv("KAFKA_BROKER", "localhost:9092")
KNOWN_KAFKA_TOPICS_TO_CONSUME = os.getenv("CONSUME_KAFKA_TOPIC", "").split(",")
KNOWN_KAFKA_TOPICS_TO_PRODUCE = os.getenv("PRODUCE_KAFKA_TOPIC", "").split(",")
KAFKA_GROUP_ID=os.getenv("KAFKA_GROUP_ID", "default-group")

KNOWN_SERVICES_TO_CALL = os.getenv("HOSTS","").split(",")


def kafka_consumer(topic_):
    consumer = Consumer({
        "bootstrap.servers": KAFKA_BROKER,
        "group.id": KAFKA_GROUP_ID,
        "auto.offset.reset": "earliest"
    })
    consumer.subscribe([topic_])

    logging.info(f"Consumer thread started for topic: {topic_}")

    while True:
        msg = consumer.poll(1.0)
        if msg is not None and msg.error() is None:
            logging.info(f"[{topic_}] Received message: {msg.value().decode('utf-8')}")


threads = []
for topic_to_consume in KNOWN_KAFKA_TOPICS_TO_CONSUME:
    thread = threading.Thread(target=kafka_consumer, args=(topic_to_consume,), daemon=True)
    thread.start()
    threads.append(thread)

producer = Producer({"bootstrap.servers": KAFKA_BROKER})

# The diploma thesis relies on proper configuration by Helm templating.
# Because of this, only deployment time known services and topics should be called/produced
# However in modern software technology solutions (e.g. Hooks, Async REST API-s), it is a common practice
# to pass a topic name or hostname in a parameter of a request and the answer will come back there and not as a result of
# this handler
# This is also going to be an important section of my Thesis work
@app.route("/send", methods=["POST"])
def send_message():
    data = request.json
    topic: str = data.get("topic")
    message: str = data.get("message")
    if topic in KNOWN_KAFKA_TOPICS_TO_PRODUCE and message != "":
        logging.info(f"Producing message: '{message}' to '{topic}' topic")
        producer.produce(topic, message.encode("utf-8"))
        producer.flush()
        return jsonify({"status": "Message sent", "topic": topic})
    else:
        logging.info(f"Not known topic: '{topic}', message not produced")
        return jsonify({"status": "Message not sent"}), 404


@app.route("/call", methods=["POST"])
def rest_call():
    data = request.json
    target_url = data.get("url")
    if not target_url:
        return jsonify({"error": "No target URL provided"}), 400

    if not target_url in KNOWN_SERVICES_TO_CALL:
        return jsonify({"error": "Not known service"}), 404

    payload = data.get("payload", {})

    logging.info(f"Calling '{target_url}' with payload '{payload}'")
    response = requests.post(target_url, json=payload)
    return jsonify({"response": response.json()})


@app.route("/receive", methods=["POST"])
def receive_message():
    data = request.json
    logging.info(f"Received REST message: {json.dumps(data)}")
    return jsonify({"status": "Received"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
    app.logger.setLevel(logging.INFO)
