FROM debian:bookworm

RUN apt update && apt install -y php-fpm php-mysql curl mariadb-client && apt clean

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp

RUN mkdir -p /run/php /var/www/html

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/setup.sh /setup.sh

RUN chmod +x /setup.sh

ENTRYPOINT ["/setup.sh"]
