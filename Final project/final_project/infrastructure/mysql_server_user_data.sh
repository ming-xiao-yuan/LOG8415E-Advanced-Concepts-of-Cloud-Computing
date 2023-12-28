#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# # MySQL Server installation script
{
    # Update all installed packages and their dependencies to their latest versions
    sudo apt-get update -y
    sudo apt-get upgrade -y

    # Install expect
    sudo apt-get install expect -y
    echo "Start MySQL Server installation at $(date)"

    # Install MySQL Community Server
    sudo apt-get install mysql-server -y

    # Start the MySQL server service
    sudo systemctl start mysql

    # Wait for MySQL to fully start up
    sleep 10

    sudo expect -f - <<-EOF
    spawn mysql_secure_installation

    # Interaction for setting up VALIDATE PASSWORD component
    expect "Press y|Y for Yes, any other key for No:"
    send "y\r"
    expect "Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG:"
    send "0\r"

    # MySQL uses auth_socket by default, so no need to change the root password
    # Skip the password setting for root
    # The script automatically continues to the next step

    # Remove anonymous users
    expect "Remove anonymous users? (Press y|Y for Yes, any other key for No) :"
    send "y\r"

    # Disallow root login remotely
    expect "Disallow root login remotely? (Press y|Y for Yes, any other key for No) :"
    send "y\r"

    # Remove test database
    expect "Remove test database and access to it? (Press y|Y for Yes, any other key for No) :"
    send "y\r"

    # Reload privilege tables
    expect "Reload privilege tables now? (Press y|Y for Yes, any other key for No) :"
    send "y\r"

    expect eof
EOF

    # Check the current status of the MySQL server service
    sudo systemctl status mysql

    echo "Finish MySQL Server installation at $(date)"

    echo "Start Sakila installation at $(date)"

    # Sakila Database URL
    SAKILA_DB_URL="https://downloads.mysql.com/docs/sakila-db.tar.gz"

    # Download and extract the Sakila database
    echo "Downloading Sakila Database..."
    wget -q ${SAKILA_DB_URL} -O sakila-db.tar.gz
    tar -xzf sakila-db.tar.gz
    cd sakila-db

    # Populate the Sakila database into MySQL
    echo "Populating Sakila Database..."
    sudo mysql < sakila-schema.sql
    sudo mysql < sakila-data.sql

    # Show tables in the Sakila database
    echo "Showing tables in Sakila Database..."
    sudo mysql -e "USE sakila; SHOW FULL TABLES;"

    # Clean up downloaded files
    cd ..
    rm -rf sakila-db sakila-db.tar.gz

    echo "Finish Sakila installation at $(date)"

    echo "Start Sysbench benchmarking at $(date)"

    # MySQL credentials and database details
    MYSQL_USER="root"  # or another user if you have created one
    MYSQL_DB="sakila"  # Sysbench creates its own database for testing
    MYSQL_PASSWORD=""  # Leave empty if using auth_socket

    # Sysbench configuration
    SYSBENCH_TABLES=10
    SYSBENCH_TABLE_SIZE=10000
    SYSBENCH_THREADS=4
    SYSBENCH_TIME=60  # duration of the test in seconds

    # Install Sysbench (if it's not already installed)
    echo "Installing Sysbench..."
    sudo apt-get update -y
    sudo apt-get install -y sysbench

    # Prepare the Sysbench test environment
    echo "Preparing the Sysbench test environment..."
    sysbench /usr/share/sysbench/oltp_read_write.lua --mysql-db=$MYSQL_DB --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWORD --db-driver=mysql --tables=$SYSBENCH_TABLES --table-size=$SYSBENCH_TABLE_SIZE prepare

    # Run the Sysbench benchmark
    echo "Running the Sysbench benchmark..."
    sysbench /usr/share/sysbench/oltp_read_write.lua --mysql-db=$MYSQL_DB --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWORD --db-driver=mysql --tables=$SYSBENCH_TABLES --table-size=$SYSBENCH_TABLE_SIZE --threads=$SYSBENCH_THREADS --time=$SYSBENCH_TIME run

    # Clean up after the test
    echo "Cleaning up..."
    sysbench /usr/share/sysbench/oltp_read_write.lua --mysql-db=$MYSQL_DB --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWORD --db-driver=mysql --tables=$SYSBENCH_TABLES --table-size=$SYSBENCH_TABLE_SIZE cleanup

    echo "Finish Sysbench benchmarking at $(date)"


} >> /var/log/progress.log 2>&1
