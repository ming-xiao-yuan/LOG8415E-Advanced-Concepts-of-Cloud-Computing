import os
from flask import Flask, request, jsonify
import logging
import threading
import json
from requests import post

app = Flask(__name__)
lock = threading.Lock()
request_queue = []

# Handlers

def update_test_json_with_ips(worker_ips):
    # For this example, we're assuming each IP is sequentially assigned to two containers
    with lock:
        with open("test.json", "r") as file:
            data = json.load(file)

        # Map each IP to two containers
        for i, ip in enumerate(worker_ips):
            data[f"container{i*2+1}"]["ip"] = ip
            data[f"container{i*2+2}"]["ip"] = ip

        # Write the updated data back to the file
        with open("test.json", "w") as file:
            json.dump(data, file, indent=4)

    # Print the updated test.json to the logs
    app.logger.info("Updated test.json with new IPs:")
    app.logger.info(json.dumps(data, indent=4))


def send_requests_to_container(container_id, container_info, incoming_request_data):
    app.logger.info(
        f"Sending request to {container_id} with data:{incoming_request_data}..."
    )
    container_ip = container_info["ip"]
    container_port = container_info["port"]
    container_url = "http://" + container_ip + ":" + container_port + "/run_model"

    post(url=container_url, data=incoming_request_data)

    app.logger.info(f"Received response from {container_id}.")


def update_container_status(container_id, status):
    with lock:
        with open("test.json", "r") as f:
            data = json.load(f)
        data[container_id]["status"] = status
        with open("test.json", "w") as f:
            json.dump(data, f)


def find_free_container(data):
    for container_id, container_info in data.items():
        if container_info["status"] == "free":
            return container_id
    return None


def process_request_in_container(free_container, data, request_data):
    if free_container:
        update_container_status(free_container, "busy")
        send_requests_to_container(free_container, data[free_container], request_data)
        update_container_status(free_container, "free")
    else:
        request_queue.append(request_data)


def process_request(incoming_request_data):
    with lock:
        with open("test.json", "r") as f:
            data = json.load(f)

    # Process the incoming request data
    free_container = find_free_container(data)
    process_request_in_container(
        free_container=free_container, data=data, request_data=incoming_request_data
    )
    
    # Showcase the amount of requests in the queue
    app.logger.info(f"{len(request_queue)} requests remaining in queue")
 
    # Process items in the request queue
    while request_queue:
        if not request_queue:
            break
        
        # Dequeue the first request
        current_request = request_queue.pop(0)
        free_container = find_free_container(data)

        process_request_in_container(
            free_container=free_container, data=data, request_data=current_request
        )
        
        
# Routes

@app.route("/health_check", methods=["GET"])
def health_check():
    return "<h1>Hello, I am the orchestrator instance {} and I am running!</h1>".format(
        os.environ["INSTANCE_ID_EC2"]
    )


@app.route("/receive_ips_from_workers", methods=["POST"])
def receive_ips():
    worker_ips = request.get_json()

    if worker_ips:
        app.logger.info("Received worker IPs:")
        for ip in worker_ips:
            app.logger.info(ip)
        try:
            update_test_json_with_ips(worker_ips)
        except Exception as e:
            app.logger.error(f"Failed to update test.json: {e}")
            return jsonify({"error": "Failed to update test.json"}), 500
    else:
        app.logger.warning("No worker IPs received")
        return jsonify({"error": "No worker IPs received"}), 400

    return jsonify({"message": "Worker IPs received and test.json updated"}), 200


@app.route("/new_request", methods=["POST"])
def new_request():
    incoming_request_data = request.json
    threading.Thread(target=process_request, args=(incoming_request_data,)).start()
    return jsonify({"message": "Request received and processing started."})

@app.route("/workers_info", methods=["GET"])
def get_workers_status():
        with open("test.json", "r") as file:
            data = json.load(file)
    
        workers_info = json.dumps(data, indent=4)
        return jsonify({"workers info": json.loads(workers_info)})


if __name__ == "__main__":
    app.logger.setLevel(logging.INFO)
    app.run(host="0.0.0.0", port=80)
