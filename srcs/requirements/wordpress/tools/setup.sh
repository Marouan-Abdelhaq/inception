#!/bin/bash
set -e

cd /var/www/html

MYSQL_PASSWORD=$(cat /run/secrets/mysql_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

echo "Waiting for MariaDB database connection..."
MAX_RETRIES=30
retry_count=0
until mariadb -h mariadb -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; do
	retry_count=$((retry_count + 1))
	if [ "$retry_count" -ge "$MAX_RETRIES" ]; then
		echo "Error: could not reach MariaDB after ${MAX_RETRIES} attempts, aborting." >&2
		exit 1
	fi
	sleep 2
done
echo "MariaDB is ready and accessible!"

if [ ! -f /var/www/html/wp-config.php ]; then
	echo "Initializing WordPress installation..."

	wp core download --allow-root

	wp config create --dbname="${MYSQL_DATABASE}" --dbuser="${MYSQL_USER}" --dbpass="${MYSQL_PASSWORD}" --dbhost="mariadb:3306" --allow-root

	wp core install --url="https://${DOMAIN_NAME}" --title="${WP_TITLE}" --admin_user="${WP_ADMIN_USER}" --admin_password="${WP_ADMIN_PASSWORD}" --admin_email="${WP_ADMIN_EMAIL}" --allow-root

	if ! wp user get "${WP_USER}" --allow-root >/dev/null 2>&1; then
		wp user create "${WP_USER}" "${WP_USER_EMAIL}" --role=author --user_pass="${WP_USER_PASSWORD}" --allow-root
	fi

	echo "WordPress successfully configured!"
else
	echo "WordPress is already installed and configured."
fi

echo "Starting PHP-FPM..."
exec php-fpm8.2 -F