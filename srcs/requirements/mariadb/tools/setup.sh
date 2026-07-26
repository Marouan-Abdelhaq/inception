#!/bin/bash

mkdir -p /run/mysqld

chown -R mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

MYSQL_ROOT_PASSWORD=$(cat /run/secrets/mysql_root_password)
MYSQL_PASSWORD=$(cat /run/secrets/mysql_password)

if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then

	echo "First start"

	mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null

	mariadbd --user=mysql --skip-networking &

	until mariadb-admin ping >/dev/null 2>&1
	do
		sleep 1
	done

	mariadb -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

FLUSH PRIVILEGES;
EOF

	mariadb-admin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

else
	echo "Database already initialized"
fi

exec mariadbd --user=mysql
