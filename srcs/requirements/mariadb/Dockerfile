FROM debian:bookworm

RUN apt update && apt install -y mariadb-server && apt clean && rm -rf /var/lib/apt/lists/* && rm -rf /var/lib/mysql/*

COPY conf/mariadb.conf /etc/mysql/mariadb.conf.d/99-custom.cnf

COPY tools/setup.sh /setup.sh

RUN chmod +x /setup.sh

ENTRYPOINT ["/setup.sh"]
