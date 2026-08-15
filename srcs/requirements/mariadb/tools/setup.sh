#!/bin/bash
set -e

mkdir -p /run/mysqld

chown -R mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

MYSQL_ROOT_PASSWORD=$(cat /run/secrets/mysql_root_password)
MYSQL_PASSWORD=$(cat /run/secrets/mysql_password)

if [ ! -d "/var/lib/mysql/mysql" ]; then

	echo "First start: initializing MariaDB data directory"

	mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null

	echo "Bootstrapping database, user and privileges"

	mariadbd --user=mysql --bootstrap --datadir=/var/lib/mysql <<-EOSQL
		CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
		CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
		GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
		ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
		FLUSH PRIVILEGES;
	EOSQL

	echo "Database initialized"

else
	echo "Database already initialized"
fi

echo "Starting MariaDB"
exec mariadbd --user=mysql