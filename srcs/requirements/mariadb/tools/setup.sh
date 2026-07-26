#!/bin/bash

mkdir -p /run/mysqld

chown -R mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql



if [ ! -d "/var/lib/mysql/mysql" ]; then

	echo "First start"

	mariadbd --user=mysql --skip-networking &

	until mariadb-admin ping >/dev/null 2>&1
	do
		sleep 1
	done

	mariadb -u root << EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';

GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';

ALTER USER 'roor'@'localhost' IDENTIFIED BY '${};

FLUSH PRIVILEGES;
EOF

	mysqladmin -u root shutdown

else
	echo "Database already initialized"
fi

exec mariadbd --user=mysql
