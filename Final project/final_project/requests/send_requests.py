import os
import requests

# Fetch the GATEKEEPER_DNS environment variable
gatekeeper_dns = os.environ.get("GATEKEEPER_DNS")
print("Gatekeeper dns is: {}".format(gatekeeper_dns))
if not gatekeeper_dns:
    raise ValueError("GATEKEEPER_DNS environment variable not set")

# Defining the URLs for different operations in the Gatekeeper service
GATEKEEPER_POPULATE_URL = f"http://{gatekeeper_dns}/populate_tables"
GATEKEEPER_DIRECT_URL = f"http://{gatekeeper_dns}/fetch_direct"
GATEKEEPER_RANDOM_URL = f"http://{gatekeeper_dns}/fetch_random"
GATEKEEPER_CUSTOMIZED_URL = f"http://{gatekeeper_dns}/fetch_customized"


# Function to send write SQL requests to a specified table
def send_write_sql_requests(table_name, num_requests):
    # SQL query template for inserting data into the specified table
    write_query = f"INSERT INTO {table_name} (column1, column2) VALUES ('column1_value', 'column2_value')"
    print(f"Starting to send write requests to {table_name}...")

    # Loop to send the specified number of write requests
    for i in range(num_requests):
        # Sending the write request and checking for success or failure
        response = requests.post(GATEKEEPER_POPULATE_URL, json={"sql": write_query})
        if response.status_code != 200:
            print(f"Error executing query for {table_name}: {write_query}")
        else:
            print(f"Write request {i+1}/{num_requests} to {table_name} successful.")

    print(f"Completed sending {num_requests} write SQL requests to {table_name}.")


# Function to send read requests to the direct_table
def send_read_sql_requests_direct():
    # SQL query for fetching data from direct_table
    read_query = "SELECT * FROM direct_table LIMIT 1"
    print("Starting to send read direct requests to direct_table...")

    # Loop to send 20 read requests
    for i in range(20):
        # Sending the read request and handling the response
        response = requests.post(GATEKEEPER_DIRECT_URL, json={"sql": read_query})
        if response.status_code != 200:
            print(f"Error executing direct read query: {read_query}")
        else:
            # Extract and print the response data
            response_data = response.json()
            print(
                f"Read direct request {i+1}/20 to direct_table successful. Response: {response_data}"
            )

    print("Completed sending 20 read SQL requests to direct_table.")


# Function to send read requests to the random_table
def send_read_sql_requests_random():
    # SQL query to read data from the random table.
    read_query = "SELECT * FROM random_table LIMIT 1"
    print("Starting to send random read requests to random_table...")

    for i in range(20):
        # Send SQL read query to the Gatekeeper server.
        response = requests.post(GATEKEEPER_RANDOM_URL, json={"sql": read_query})
        if response.status_code != 200:
            print(f"Error executing random read query: {read_query}")
        else:
            # Extract and print the response data
            response_data = response.json()
            print(
                f"Read random request {i+1}/20 to random_table successful. Response: {response_data}"
            )

    print("Completed sending 20 random read SQL requests to random_table.")


# Function to send read requests to the customized_table
def send_read_sql_requests_customized():
    # SQL query to read data from the customized table.
    read_query = "SELECT * FROM customized_table LIMIT 1"
    print("Starting to send customized read requests to customized_table...")

    for i in range(20):
        # Send SQL read query to the Gatekeeper server.
        response = requests.post(GATEKEEPER_CUSTOMIZED_URL, json={"sql": read_query})
        if response.status_code != 200:
            print(f"Error executing customized read query: {read_query}")
        else:
            # Extract and print the response data
            response_data = response.json()
            print(
                f"Read customized request {i+1}/20 to customized_table successful. Response: {response_data}"
            )

    print("Completed sending 20 customized read SQL requests to customized_table.")


def main():
    print("Script started. Sending SQL write requests...")

    # Send write requests for each table.
    for table in ["direct_table", "random_table", "customized_table"]:
        send_write_sql_requests(table, 20)

    print("Finish populating tables.")

    # Sending read requests to direct_table.
    print(
        "===================================DIRECT HIT==================================="
    )
    # Send read requests to direct_table
    send_read_sql_requests_direct()
    print("Script completed. All direct requests have been sent.")
    print(
        "===================================DIRECT HIT FINISHED==================================="
    )

    print(
        "===================================RANDOM HIT==================================="
    )

    # Sending read requests to random_table.
    send_read_sql_requests_random()
    print("Script completed. All radndom requests have been sent.")
    print(
        "===================================RANDOM HIT FINISHED==================================="
    )

    # Sending read requests to customized_table.
    print(
        "===================================CUSTOMIZED HIT==================================="
    )
    send_read_sql_requests_customized()
    print(
        "===================================CUSTOMIZED HIT FINISHED==================================="
    )


if __name__ == "__main__":
    main()
