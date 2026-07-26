FROM debian:bookworm

RUN apt update && apt install -y mariadb-server && apt clean

COPY tools/setup.sh /setup.sh

RUN chmod +x /setup.sh

ENTRYPOINT ["/setup.sh"]
