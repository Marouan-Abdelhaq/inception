#!/bin/bash

set -e

mkdir -p /etc/nginx/ssl


if [ ! -f "/etc/nginx/ssl/certificate.crt" ] || [ ! -f "/etc/nginx/ssl/private.key" ]; then

    echo "Generating SSL certificate..."

    openssl req -x509 \
        -nodes \
        -newkey rsa:4096 \
        -keyout /etc/nginx/ssl/private.key \
        -out /etc/nginx/ssl/certificate.crt \
        -days 365 \
        -subj "/CN=${DOMAIN_NAME}"

    echo "SSL certificate generated!"

else

    echo "SSL certificate already exists."

fi


echo "Starting Nginx..."

exec nginx -g "daemon off;"