#!/bin/bash

set -e

mkdir -p /etc/nginx/ssl


if [ ! -f "/etc/nginx/ssl/certificate.crt" ] || [ ! -f "/etc/nginx/ssl/private.key" ]; then

    echo "Generating SSL certificate..."

    cat > /tmp/openssl.cnf <<EOF
[req]
distinguished_name=req_distinguished_name
x509_extensions=v3_req

[req_distinguished_name]

[v3_req]
basicConstraints=CA:FALSE
subjectAltName=DNS:${DOMAIN_NAME}
EOF


    openssl req -x509 -nodes \
    -newkey rsa:4096 \
    -keyout /etc/nginx/ssl/private.key \
    -out /etc/nginx/ssl/certificate.crt \
    -days 365 \
    -subj "/C=MA/ST=Rabat/L=Rabat/O=42/OU=Inception/CN=${DOMAIN_NAME}" \
    -config /tmp/openssl.cnf


    echo "SSL certificate generated!"

else
    echo "SSL certificate already exists."
fi


echo "Starting Nginx..."

exec nginx -g "daemon off;"
