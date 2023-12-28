import subprocess
from flask import Flask, request, jsonify
from sshtunnel import SSHTunnelForwarder
import mysql.connector
import os
import random
import threading


app = Flask(__name__)

# Configuration for the MySQL Manager Node
manager_db_config = {
    "host": os.environ.get(
        "MANAGER_DNS", "Unknown"
    ),  # Manager IP from environment variable
    "user": "root",  # MySQL username
    "password": "",  # MySQL password
    "database": "main_db",  # Database name
}

# Retrieve and validate the list of worker DNS addresses from environment variables
worker_dns_list = os.environ.get("WORKER_DNS", "").split(",")
app.logger.warning("Worker DNS list is: {}".format(worker_dns_list))
if not worker_dns_list:
    raise ValueError("Worker DNS list is empty or not set")

# Global variables for SSH tunnels and request counters
random_ssh_tunnel = None
customized_ssh_tunnel = None
ping_times = None
random_request_counter = 0


def create_ssh_tunnel(worker_node):
    """
    Creates an SSH tunnel to the specified worker node.

    Args:
        worker_node (str): The worker node address to create an SSH tunnel to.

    Returns:
        SSHTunnelForwarder: An active SSH tunnel instance or None if failed.
    """
    global ssh_tunnel_port
    try:
        tunnel = SSHTunnelForwarder(
            (manager_db_config["host"], 22),
            ssh_username="ubuntu",
            ssh_pkey="/etc/proxy/my_terraform_key",
            remote_bind_address=(worker_node, 3306),
            local_bind_address=("127.0.0.1", 9000),
        )
        tunnel.start()
        app.logger.warning("Successfully establish SSH tunnel.")
        return tunnel
    except Exception as e:
        app.logger.error(f"Failed to establish SSH tunnel: {e}")
        return None


def ping_worker_node(worker_node):
    """
    Pings a worker node and returns the response time.

    Args:
        worker_node (str): The worker node to ping.

    Returns:
        float: The ping time in milliseconds or infinity if ping fails.
    """
    try:
        response = subprocess.run(
            ["ping", "-c", "1", worker_node],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        output = response.stdout.decode()
        time_taken = output.split("time=")[1].split(" ms")[0]
        return float(time_taken)
    except Exception as e:
        app.logger.error(f"Ping to {worker_node} failed: {e}")
        return float("inf")


def initialize_random_ssh_tunnel():
    """
    Initializes a random SSH tunnel at startup.
    """
    global random_ssh_tunnel
    chosen_worker_node = random.choice(worker_dns_list)
    app.logger.warning("Random chosen worker node is: {}".format(chosen_worker_node))
    random_ssh_tunnel = create_ssh_tunnel(chosen_worker_node)
    app.logger.warning("Random ssh tunnel established.")


# Start the thread to initialize a random SSH tunnel
threading.Thread(target=initialize_random_ssh_tunnel).start()


@app.route("/health_check", methods=["GET"])
def health_check():
    """
    Health check endpoint.

    Returns:
        str: A simple message indicating the status of the application.
    """
    return "<h1>Hello, I am the proxy app {} and I am running! I have the manager DNS it's {}.</h1>".format(
        os.environ.get("PROXY_DNS", "Unknown"), manager_db_config["host"]
    )


@app.route("/populate_tables", methods=["POST"])
def populate_tables():
    """
    Endpoint to populate tables with data.

    Returns:
        Response: A JSON response indicating success or failure.
    """
    request_counter = 0
    data = request.json
    sql_template = data.get("sql")
    table_names = ["direct_table", "random_table", "customized_table"]

    if not sql_template:
        return jsonify({"error": "No SQL query provided"}), 400

    # Determine the target table based on the request counter
    target_table = table_names[(request_counter // 20) % len(table_names)]
    sql = sql_template.format(table=target_table)

    # Initialize 'conn' and 'cursor' as None
    conn = None
    cursor = None

    try:
        conn = mysql.connector.connect(**manager_db_config)
        cursor = conn.cursor()
        cursor.execute(sql)

        conn.commit()
        result = {"message": f"Insert query executed successfully in {target_table}"}

        # Increment and reset the request counter
        request_counter = (request_counter + 1) % 60

        return jsonify(result)
    except mysql.connector.Error as err:
        return jsonify({"error": str(err)}), 500
    finally:
        # Close cursor and connection if they were successfully created
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()


@app.route("/fetch_direct", methods=["POST"])
def fetch_direct():
    """
    Endpoint for fetching data directly.

    Returns:
        Response: A JSON response with fetched data or an error message.
    """
    data = request.json
    sql = data.get("sql")

    if not sql:
        return jsonify({"error": "No SQL query provided"}), 400

    # Initialize 'conn' and 'cursor' as None
    conn = None
    cursor = None

    try:
        with mysql.connector.connect(**manager_db_config) as conn:
            with conn.cursor() as cursor:
                cursor.execute(sql)
                result = cursor.fetchall()
        return jsonify(result)
    except mysql.connector.Error as err:
        return jsonify({"error": str(err)}), 500


@app.route("/fetch_random", methods=["POST"])
def fetch_random():
    """
    Endpoint for fetching data from a randomly chosen node.

    Returns:
        Response: A JSON response with fetched data or an error message.
    """
    global random_ssh_tunnel, random_request_counter
    data = request.json
    sql = data.get("sql")

    if not sql:
        return jsonify({"error": "No SQL query provided"}), 400

    if random_ssh_tunnel is None or not random_ssh_tunnel.is_active:
        return jsonify({"error": "SSH tunnel is not established"}), 500

    conn = None
    cursor = None  # Initialize cursor to None

    # Use the existing SSH tunnel for the database connection
    manager_tunnel = {
        "host": manager_db_config["host"],
        "user": "root",
        "password": "",
        "database": "main_db",
    }
    try:
        with mysql.connector.connect(**manager_tunnel) as conn:
            with conn.cursor() as cursor:
                cursor.execute(sql)
                result = cursor.fetchall()

        random_request_counter += 1
        if random_request_counter >= 20:
            close_random_ssh_tunnel()
        return jsonify(result)
    except mysql.connector.Error as err:
        return jsonify({"error": "MySQL Error: {}".format(str(err))}), 500


def close_random_ssh_tunnel():
    """
    Closes the random SSH tunnel after 20 requests.
    """
    global random_ssh_tunnel, random_request_counter
    if random_ssh_tunnel and random_ssh_tunnel.is_active:
        random_ssh_tunnel.stop()
        random_ssh_tunnel = None
        random_request_counter = 0
        app.logger.warning("Random request tunnel is being closed.")


def initialize_customized_ssh_tunnel():
    """
    Initializes a customized SSH tunnel based on the lowest ping time.
    """
    global ping_times, customized_ssh_tunnel
    if ping_times is None:
        ping_times = {node: ping_worker_node(node) for node in worker_dns_list}

    # Create a new SSH tunnel for customized requests
    if customized_ssh_tunnel is None or not customized_ssh_tunnel.is_active:
        chosen_node = min(ping_times, key=ping_times.get)
        customized_ssh_tunnel = create_ssh_tunnel(chosen_node)
        app.logger.warning("Customized chosen node is: {}".format(chosen_node))


@app.route("/fetch_customized", methods=["POST"])
def fetch_customized():
    """
    Endpoint for fetching data from the node with the lowest ping time.

    Returns:
        Response: A JSON response with fetched data or an error message.
    """
    data = request.json
    sql = data.get("sql")

    if not sql:
        return jsonify({"error": "No SQL query provided"}), 400

    conn = None
    cursor = None

    try:
        initialize_customized_ssh_tunnel()

        if not customized_ssh_tunnel or not customized_ssh_tunnel.is_active:
            return jsonify({"error": "SSH tunnel is not established"}), 500

        manager_tunnel = {
            "host": manager_db_config["host"],
            "user": "root",
            "password": "",
            "database": "main_db",
        }

        with mysql.connector.connect(**manager_tunnel) as conn:
            with conn.cursor() as cursor:
                cursor.execute(sql)
                result = cursor.fetchall()
        return jsonify(result)
    except mysql.connector.Error as err:
        return jsonify({"error": "MySQL Error: {}".format(str(err))}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
