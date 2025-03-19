from flask import Flask, request, jsonify
from confluent_kafka import Producer, Consumer, KafkaException
import requests
import os
import threading
import json
import logging

#tracing
from opentelemetry import trace
from opentelemetry.baggage import set_baggage, get_baggage
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import (
    BatchSpanProcessor
)
from opentelemetry.sdk.resources import Resource
#from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.confluent_kafka import ConfluentKafkaInstrumentor
from opentelemetry.propagate import extract, inject
from werkzeug.datastructures import Headers

app = Flask(__name__)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
)

service_id: str= os.getenv("SERVICE_ID","default")

resource = Resource.create(attributes={"service.name": service_id})

trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

jaeger_exporter = OTLPSpanExporter(endpoint="http://jaeger-collector:4317", insecure=True)
span_processor = BatchSpanProcessor(jaeger_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Flask és Requests instrumentálása
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()
ConfluentKafkaInstrumentor().instrument()

# Kafka configuration
KAFKA_BROKER = os.getenv("KAFKA_BROKER", "localhost:9092")
KNOWN_KAFKA_TOPICS_TO_CONSUME = os.getenv("CONSUME_KAFKA_TOPIC", "").split(",")
KNOWN_KAFKA_TOPICS_TO_PRODUCE = os.getenv("PRODUCE_KAFKA_TOPIC", "").split(",")
KAFKA_GROUP_ID=os.getenv("KAFKA_GROUP_ID", "default-group")

KNOWN_SERVICES_TO_CALL = os.getenv("HOSTS","localhost").split(",")

ENABLE_DYNAMIC_COMMUNICATION = os.getenv("DYNAMIC_COMMUNICATION", False)

logging.info(f"Known topics to consume: {','.join(KNOWN_KAFKA_TOPICS_TO_CONSUME)}")
logging.info(f"Known topics to produce: {','.join(KNOWN_KAFKA_TOPICS_TO_PRODUCE)}")
logging.info(f"Known hosts: {','.join(KNOWN_SERVICES_TO_CALL)}")


def kafka_consumer(topic_):
    consumer = Consumer({
        "bootstrap.servers": KAFKA_BROKER,
        "group.id": KAFKA_GROUP_ID,
        "auto.offset.reset": "earliest"
    })
    consumer.subscribe([topic_])

    logging.info(f"Consumer thread started for topic: {topic_}")
    try:
        while True:
            msg = consumer.poll(1.0)
            if msg is not None and msg.error() is None:
                # Trace header-ek kinyerése (propagáció producer -> consumer között)
                headers = dict(msg.headers() or [])

                # Trace propagáció
                context = extract(headers)

                # OpenTelemetry span létrehozása
                with tracer.start_as_current_span(f"consume_{topic_}", context=context) as span:
                        message_value = msg.value().decode("utf-8")
                        span.set_attribute("message", message_value)
                        span.set_attribute("kafka.topic", topic_)
                        logging.info(f"Received message: {message_value}")
    except(KeyboardInterrupt):
        logging.info(f"Consuming stopped for consumer: {consumer}, stopping...")
    finally:
        consumer.close()


threads = []
for topic_to_consume in KNOWN_KAFKA_TOPICS_TO_CONSUME:
    thread = threading.Thread(target=kafka_consumer, args=(topic_to_consume,), daemon=True)
    thread.start()
    threads.append(thread)

producer = Producer({"bootstrap.servers": KAFKA_BROKER})

@app.route("/consume", methods=["POST"])
def start_consume():
    data = request.json
    topic: str = data.get("topic")
    if ENABLE_DYNAMIC_COMMUNICATION and topic not in KNOWN_KAFKA_TOPICS_TO_CONSUME:
        logging.info(f"Starting to consume new topic: '{topic}'")
        thread_ = threading.Thread(target=kafka_consumer, args=(topic,), daemon=True)
        thread_.start()
        threads.append(thread_)

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
    key: str = data.get("key")
    if ENABLE_DYNAMIC_COMMUNICATION or (topic in KNOWN_KAFKA_TOPICS_TO_PRODUCE and message != ""):
        produce_message(key, message, topic)
        return jsonify({"status": "Message sent", "topic": topic})
    else:
        logging.info(f"Not known topic: '{topic}', message not produced")
        return jsonify({"status": "Message not sent"}), 404


def produce_message(key, message, topic):
    logging.info(f"Producing message: '{message}' to '{topic}' topic")
    with tracer.start_as_current_span(f"produce_{topic}") as span:
        span.set_attribute("message", message)
        span.set_attribute("kafka.topic", topic)

        # Trace context propagálása Kafka header-ekbe
        carrier = {}
        inject(carrier)

        producer.produce(topic, key=key, value=message, headers=list(carrier.items()))
        producer.flush()


@app.route("/call", methods=["POST"])
def rest_call():
    data = request.json
    target_url: str = data.get("url")
    if not target_url:
        return jsonify({"error": "No target URL provided"}), 400

    if not ENABLE_DYNAMIC_COMMUNICATION and not target_url in KNOWN_SERVICES_TO_CALL:
        return jsonify({"error": "Not known service"}), 404

    payload = data.get("payload", {})
    context = extract(request.headers)

    with tracer.start_as_current_span(f"calling_{target_url}", context=context) as span:
        span.set_attribute("http.method", "POST")
        span.set_attribute("http.url", f"http://{target_url}:8080/receive")
        span.set_attribute("payload", json.dumps(payload))

        logging.info(f"Calling '{target_url}' with payload '{payload}'")

        # Trace propagáció a kimenő kéréshez
        headers= {"X-Service-id": service_id}
        inject(headers)

        response = requests.post(f"http://{target_url}:8080/receive", json=payload, headers=headers)

        span.set_attribute("http.status_code", response.status_code)
        return jsonify({"response": response.json()})


@app.route("/receive", methods=["POST"])
def receive_message():
    context = extract(request.headers)
    sender_service_id = request.headers.get("X-Service-id")

    with tracer.start_as_current_span(f"receive_{sender_service_id}", context=context) as span:
        data = request.json
        span.set_attribute("message", json.dumps(data))

        logging.info(f"Received REST message: {json.dumps(data)}")
    return jsonify({"status": "Received"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
    app.logger.setLevel(logging.INFO)
