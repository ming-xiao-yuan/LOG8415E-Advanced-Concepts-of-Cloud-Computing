#!/bin/bash

# Set environment variables for non-interactive frontend and PATH
export DEBIAN_FRONTEND=noninteractive
export PATH=/opt/mysqlcluster/home/mysqlc/bin:$PATH

{
    # Update and upgrade the system packages
    sudo apt-get update -y
    sudo apt-get upgrade -y

    # Create a directory structure for MySQL Cluster
    sudo mkdir -p /opt/mysqlcluster/home
    cd /opt/mysqlcluster/home

    # Download MySQL Cluster package
    MYSQL_CLUSTER_URL="http://dev.mysql.com/get/Downloads/MySQL-Cluster-7.2/mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz"
    sudo wget $MYSQL_CLUSTER_URL

    # Extract the downloaded package
    sudo tar xvf mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz

    # Create a symbolic link to the extracted directory for easier reference
    sudo ln -s mysql-cluster-gpl-7.2.1-linux2.6-x86_64 mysqlc

    # Set environment variables for MySQL Cluster and update the system PATH
    echo 'export MYSQLC_HOME=/opt/mysqlcluster/home/mysqlc' | sudo tee /etc/profile.d/mysqlc.sh
    echo 'export PATH=$MYSQLC_HOME/bin:$PATH' | sudo tee -a /etc/profile.d/mysqlc.sh
    
    # Reload the profile to apply the new PATH
    source /etc/profile.d/mysqlc.sh

    # Install additional required packages
    sudo apt-get update && sudo apt-get -y install libncurses5

    # Create directories for configuration, data for MySQLD and NDB
    sudo mkdir -p /opt/mysqlcluster/deploy
    cd /opt/mysqlcluster/deploy
    sudo mkdir conf mysqld_data ndb_data

    # Go to the configuration directory
    cd conf

    # Create and write the MySQLD configuration file
    MYSQLD_CONFIG="[mysqld]
    ndbcluster
    datadir=/opt/mysqlcluster/deploy/mysqld_data
    basedir=/opt/mysqlcluster/home/mysqlc
    port=3306"

    # Write the configuration to my.cnf
    echo "$MYSQLD_CONFIG" | sudo tee /opt/mysqlcluster/deploy/conf/my.cnf > /dev/null

    # Source the IP addresses
    source /tmp/ip_addresses.sh

    # Define the path to your config.ini file
    CONFIG_FILE="/opt/mysqlcluster/deploy/conf/config.ini"

    # Start writing to the config file
    echo "[ndb_mgmd]" > $CONFIG_FILE
    echo "hostname=${MANAGER_DNS}" >> $CONFIG_FILE
    echo "datadir=/opt/mysqlcluster/deploy/ndb_data" >> $CONFIG_FILE
    echo "nodeid=1" >> $CONFIG_FILE
    echo "" >> $CONFIG_FILE

    echo "[ndbd default]" >> $CONFIG_FILE
    echo "noofreplicas=3" >> $CONFIG_FILE
    echo "datadir=/opt/mysqlcluster/deploy/ndb_data" >> $CONFIG_FILE
    echo "" >> $CONFIG_FILE

    # Add each worker node
    NODEID=2
    for WORKER_DNS in "${WORKER_DNS[@]}"
    do
        echo "[ndbd]" >> $CONFIG_FILE
        echo "hostname=${WORKER_DNS}" >> $CONFIG_FILE
        echo "nodeid=${NODEID}" >> $CONFIG_FILE
        echo "" >> $CONFIG_FILE
        ((NODEID++))
    done

    echo "[mysqld]" >> $CONFIG_FILE
    echo "nodeid=50" >> $CONFIG_FILE

    # Go back to MySQLC directory
    cd /opt/mysqlcluster/home/mysqlc

    # Initialize MySQL data directory
    sudo scripts/mysql_install_db --no-defaults --datadir=/opt/mysqlcluster/deploy/mysqld_data

    # Start the MySQL Cluster Management Node
    sudo /opt/mysqlcluster/home/mysqlc/bin/ndb_mgmd -f /opt/mysqlcluster/deploy/conf/config.ini --initial --configdir=/opt/mysqlcluster/deploy/conf/ --ndb-nodeid=1


    # Wait for a predetermined period for nodes to connect
    echo "Waiting for nodes to connect..."
    sleep 180  # Wait for 180 seconds (3 minutes)
    echo "Continuing with the assumption that nodes are connected."
    
    sudo /opt/mysqlcluster/home/mysqlc/bin/ndb_mgm -e show

    sudo mkdir -p /opt/mysqlcluster/deploy/mysqld_data
    sudo chown -R root:root /opt/mysqlcluster/deploy/mysqld_data

    /opt/mysqlcluster/home/mysqlc/bin/mysqld --defaults-file=/opt/mysqlcluster/deploy/conf/my.cnf --basedir=/opt/mysqlcluster/home/mysqlc --user=root &


    # Wait for MySQL to start
    echo "Waiting for MySQL to start..."
    sleep 60

    cd /tmp

    echo "Start Sakila installation at $(date)"

    # Sakila Database URL
    SAKILA_DB_URL="https://downloads.mysql.com/docs/sakila-db.tar.gz"

    # Download and extract the Sakila database
    echo "Downloading Sakila Database..."
    wget -q ${SAKILA_DB_URL} -O sakila-db.tar.gz
    tar -xzf sakila-db.tar.gz
    cd sakila-db

    # Load Sakila schema and data into MySQL
    echo "Loading Sakila Schema and Data into MySQL..."
    /opt/mysqlcluster/home/mysqlc/bin/mysql -u root -e "source sakila-schema.sql;"
    /opt/mysqlcluster/home/mysqlc/bin/mysql -u root -e "source sakila-data.sql;"

    # Verify tables in the Sakila database
    echo "Verifying tables in Sakila Database..."
    /opt/mysqlcluster/home/mysqlc/bin/mysql -u root -e "USE sakila; SHOW FULL TABLES;"

    # Clean up downloaded files
    cd ..
    rm -rf sakila-db sakila-db.tar.gz

    echo "Sakila installation completed at $(date)"

    echo "Start Sysbench benchmarking at $(date)"

    # Sysbench configuration
    MYSQL_HOST="127.0.0.1"
    MYSQL_PORT=3306

    # MySQL credentials and database details
    MYSQL_USER="root"
    MYSQL_DB="sakila"
    MYSQL_PASSWORD=""

    # Sysbench configuration
    SYSBENCH_TABLES=10
    SYSBENCH_TABLE_SIZE=10000
    SYSBENCH_THREADS=4
    SYSBENCH_TIME=60  # duration of the test in seconds

    # Install Sysbench
    echo "Installing Sysbench..."
    sudo apt-get update -y
    sudo apt-get install -y sysbench

    # Prepare the Sysbench test environment
    echo "Preparing the Sysbench test environment..."
    sysbench /usr/share/sysbench/oltp_read_write.lua --mysql-db=$MYSQL_DB --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWORD --db-driver=mysql --mysql-host=$MYSQL_HOST --mysql-port=$MYSQL_PORT --tables=$SYSBENCH_TABLES --table-size=$SYSBENCH_TABLE_SIZE prepare

    # Run the Sysbench benchmark
    echo "Running the Sysbench benchmark..."
    sysbench /usr/share/sysbench/oltp_read_write.lua --mysql-db=$MYSQL_DB --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWORD --db-driver=mysql --mysql-host=$MYSQL_HOST --mysql-port=$MYSQL_PORT --tables=$SYSBENCH_TABLES --table-size=$SYSBENCH_TABLE_SIZE --threads=$SYSBENCH_THREADS --time=$SYSBENCH_TIME run

    # Clean up after the test
    echo "Cleaning up..."
    sysbench /usr/share/sysbench/oltp_read_write.lua --mysql-db=$MYSQL_DB --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWORD --db-driver=mysql --mysql-host=$MYSQL_HOST --mysql-port=$MYSQL_PORT --tables=$SYSBENCH_TABLES --table-size=$SYSBENCH_TABLE_SIZE cleanup

    echo "Finish Sysbench benchmarking at $(date)"

    # Grant privileges
    /opt/mysqlcluster/home/mysqlc/bin/mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;"

    # Create database
    /opt/mysqlcluster/home/mysqlc/bin/mysql -u root -e "CREATE DATABASE main_db;"

    # Verify databases creation
    echo "Databases created. Verifying creation..."
    /opt/mysqlcluster/home/mysqlc/bin/mysql -u root -e "SHOW DATABASES;" | grep -E 'main_db'
    echo "Verification complete. Database main_db is created."

    # Create direct_table in main_db
    /opt/mysqlcluster/home/mysqlc/bin/mysql -u root -e "
    USE main_db;
    CREATE TABLE direct_table (
        id INT AUTO_INCREMENT PRIMARY KEY,
        column1 VARCHAR(255),
        column2 VARCHAR(255)
    );"

    # Create random_table in main_db
    /opt/mysqlcluster/home/mysqlc/bin/mysql -u root -e "
    USE main_db;
    CREATE TABLE random_table (
        id INT AUTO_INCREMENT PRIMARY KEY,
        column1 VARCHAR(255),
        column2 VARCHAR(255)
    );"

    # Create customized_table in main_db
    /opt/mysqlcluster/home/mysqlc/bin/mysql -u root -e "
    USE main_db;
    CREATE TABLE customized_table (
        id INT AUTO_INCREMENT PRIMARY KEY,
        column1 VARCHAR(255),
        column2 VARCHAR(255)
    );"

    echo "Database and tables created successfully."

    # Verification
    /opt/mysqlcluster/home/mysqlc/bin/mysql -u root -e "SHOW DATABASES;"
    /opt/mysqlcluster/home/mysqlc/bin/mysql -u root -e "USE main_db; SHOW TABLES;"

    echo "Verification complete."
    echo "Manager script finished."

} >> /var/log/progress.log 2>&1
