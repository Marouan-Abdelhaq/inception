_This project has been created as part of the 42 curriculum by mabdelha._

# Inception

## Description

Inception is a system administration project whose goal is to set up a small web infrastructure entirely with Docker, using Docker Compose, inside a dedicated virtual machine.

The infrastructure is composed of three custom-built services, each running in its own dedicated container:

- **NGINX** — the only entry point to the infrastructure, serving HTTPS traffic on port 443 with TLSv1.2/TLSv1.3 and forwarding PHP requests to WordPress through FastCGI.
- **WordPress + PHP-FPM** — a WordPress installation running with PHP-FPM. This container does not contain NGINX.
- **MariaDB** — the database server used by WordPress. This container does not contain NGINX.

The three services communicate through a dedicated Docker network.

Two persistent Docker named volumes are used:

- One volume for the MariaDB database.
- One volume for the WordPress website files.

These are declared as Docker named volumes rather than direct bind mounts in the service definitions. They use the Docker `local` volume driver together with `driver_opts` (`type: none`, `o: bind`), so that their data is physically stored on the host machine under:

```text
/home/mabdelha/data/
```

as required by the subject.

The entire infrastructure is executed inside a virtual machine, as required by the Inception subject.

Each service has its own Dockerfile and its own dedicated container. All three images are built locally from `debian:bookworm`, and are explicitly named `nginx`, `wordpress`, and `mariadb` in `docker-compose.yml` (matching their corresponding service names, as required by the subject). Ready-made WordPress, NGINX, or MariaDB Docker images are not used — only the base Debian image comes from outside the project — and the `latest` tag is not used.

The project domain is:

```text
mabdelha.42.fr
```

and points to the local IP address of the virtual machine.

---

## Project Structure

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/
│   ├── mysql_password.txt
│   ├── mysql_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        └── wordpress/
            ├── Dockerfile
            ├── conf/
            └── tools/
```

The directory structure separates the three services and their respective Dockerfiles, configuration files, and startup scripts.

The `secrets/` directory shown above represents the local project structure. It contains sensitive credentials and is **not committed to Git** — the files listed must be created locally on any machine running the project (see the Installation section below).

The `.env` file contains non-sensitive configuration values such as the domain name, database name, and usernames. It is also excluded from Git and must be created locally.

---

## Service Sources

The project uses three services built locally from custom Dockerfiles.

### NGINX

The NGINX image is built from `debian:bookworm`. NGINX is installed and configured manually.

The configuration:

- enables HTTPS;
- allows TLSv1.2 and TLSv1.3;
- listens only on port 443;
- mounts the same `wordpress_data` named volume as the WordPress container, to serve the website files;
- forwards PHP requests to PHP-FPM through FastCGI.

### WordPress + PHP-FPM

The WordPress image is built from `debian:bookworm`.

WordPress is downloaded and installed during the container initialization using WP-CLI.

PHP-FPM is installed and configured to listen on port 9000 inside the Docker network.

NGINX communicates with this service through FastCGI.

NGINX is not installed in this container.

### MariaDB

The MariaDB image is built from `debian:bookworm`.

MariaDB is installed and configured manually.

The initialization script:

- initializes the database when necessary;
- creates the WordPress database;
- creates the WordPress database user;
- grants the required privileges;
- starts MariaDB as the main container process.

NGINX is not installed in this container.

No ready-made WordPress, NGINX, or MariaDB Docker images are used.

---

## Design Choices and Comparisons

### Virtual Machines vs Docker

A virtual machine virtualizes an entire computer and runs a complete guest operating system on top of a hypervisor. This generally requires more resources because each VM has its own operating system and kernel.

Docker containers share the host operating system's kernel while isolating processes, filesystems, networks, and resources. Containers are therefore generally lighter and faster to start than virtual machines.

Docker uses Linux mechanisms such as namespaces and cgroups to provide isolation and resource management.

In this project, the complete infrastructure runs inside a virtual machine because this is required by the 42 subject. Docker is then used inside that VM to isolate the different services.

### Secrets vs Environment Variables

Environment variables are useful for configuration values that are not sensitive, such as:

- domain name;
- database name;
- usernames.

These values are stored in `srcs/.env`.

Sensitive information such as passwords should not be stored directly in the repository or Dockerfiles.

Docker secrets provide a way to provide sensitive information to containers as files, normally available under:

```text
/run/secrets/
```

In this project, passwords are stored locally in the `secrets/` directory and are ignored by Git.

This separation makes it possible to keep normal configuration in environment variables while keeping credentials outside the Git repository.

### Docker Network vs Host Network

With `network: host`, a container shares the host's network stack directly. This removes the network isolation provided by Docker and can expose container services directly through the host network.

This project instead uses a dedicated Docker bridge network.

The containers can communicate with each other through the Docker network using their service names, while only the required external port is published.

Only NGINX exposes a port to the host:

```text
443
```

The project does not use:

- `network: host`;
- `links:`;
- `--link`.

### Docker Volumes vs Bind Mounts

A bind mount directly maps a specific host directory into a container by declaring the host path directly in the service's `volumes:` section.

A Docker named volume is managed by Docker and is referenced by a volume name in the service definition; its actual storage location is configured separately, at the volume's own definition level.

The subject requires Docker named volumes for the MariaDB database and WordPress files.

This project therefore uses two named volumes, declared as `mariadb_data` and `wordpress_data` and referenced by name in each service:

```text
mariadb_data
wordpress_data
```

Their storage is configured with the `local` volume driver and `driver_opts` (`type: none`, `o: bind`), so their data physically lives under:

```text
/home/mabdelha/data/
```

on the host machine. This is a named volume with a bind-backed storage location, not a direct bind mount declared in the service's `volumes:` list — the distinction matters because named volumes are managed and referenced through Docker (inspectable via `docker volume inspect`, portable across service definitions), while a bind mount would tie the container directly to a host path with no Docker-managed abstraction in between.

This allows the data to survive container removal and recreation.

---

## Architecture

```text
                    Browser
                       |
                       | HTTPS :443
                       |
                       v
              +----------------+
              |     NGINX      |
              |   TLS 1.2/1.3  |
              +----------------+
                       |
                       | FastCGI :9000
                       |
                       v
              +----------------+
              |   WordPress    |
              |    PHP-FPM     |
              +----------------+
                       |
                       | MySQL/MariaDB
                       |
                       v
              +----------------+
              |    MariaDB     |
              +----------------+

              Docker Network
        ───────────────────────────

Persistent storage:

/home/mabdelha/data/
├── mariadb/
└── wordpress/
```

NGINX is the only service accessible from outside the Docker network.

---

# Instructions

## Requirements

The project must be run inside a Linux virtual machine.

Required software:

- Debian or Alpine virtual machine;
- Docker Engine;
- Docker Compose;
- `make`.

The base images used by the project must comply with the subject's requirement regarding the penultimate stable version of Debian or Alpine.

---

## Installation

Clone the repository:

```bash
git clone <repository_url> inception
cd inception
```

Make sure that the local configuration and secret files are available.

The following files must not contain publicly exposed credentials:

```text
srcs/.env
secrets/
```

Add the project domain to the VM's host resolution:

```bash
echo "<VM_IP> mabdelha.42.fr" | sudo tee -a /etc/hosts
```

Replace `<VM_IP>` with the IP address of the virtual machine.

---

## Build and Start

The complete infrastructure can be built and started using:

```bash
make
```

The Makefile prepares the required directories, builds the Docker images, and starts the services through Docker Compose.

You can also use Docker Compose directly:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d --build
```

---

## Access the Website

Open:

```text
https://mabdelha.42.fr
```

The NGINX container is the only entry point to the infrastructure and exposes port:

```text
443
```

The TLS certificate is self-signed, so the browser may display a certificate warning.

The WordPress installation page should not appear because WordPress is automatically installed and configured during initialization.

HTTP on port 80 is not exposed.

---

## Useful Commands

Check the containers:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Display logs:

```bash
docker compose -f srcs/docker-compose.yml logs
```

Display logs for a specific service:

```bash
docker compose -f srcs/docker-compose.yml logs mariadb
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs nginx
```

Stop the infrastructure:

```bash
make down
```

Display Docker networks:

```bash
docker network ls
```

Display Docker volumes:

```bash
docker volume ls
```

Inspect a volume:

```bash
docker volume inspect <volume_name>
```

---

# Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/reference/compose-file/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [Docker Networking Documentation](https://docs.docker.com/engine/network/)
- [Docker Volumes Documentation](https://docs.docker.com/engine/storage/volumes/)
- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)
- [WP-CLI Documentation](https://wp-cli.org/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [PHP-FPM Documentation](https://www.php.net/manual/en/install.fpm.php)
- _The Linux Command Line_ — William Shotts

---

## AI Usage

AI was used as a learning, explanation, review, and verification assistant during the development of this project.

The AI assistant's role was **not to replace the student's work**, but to help understand the technologies and verify the implementation.

AI assistance was used for the following tasks:

### Learning and understanding

The AI assistant was used to explain the concepts required for the project, including:

- Docker;
- Docker images;
- Docker containers;
- Dockerfiles;
- Docker Compose;
- Docker networks;
- Docker volumes;
- bind mounts;
- environment variables;
- Docker secrets;
- PID 1 and container processes;
- MariaDB;
- WordPress;
- PHP-FPM;
- FastCGI;
- NGINX;
- TLS/SSL.

The explanations focused on understanding **what each component is, how it works, and why it is used** in the Inception architecture.

### Project planning

AI assistance was used to help organize the implementation steps and verification process, including:

- planning the order in which services should be implemented;
- identifying configuration tasks;
- preparing testing procedures;
- checking the project against the mandatory requirements.

### Code and configuration review

The AI assistant was used to review and explain parts of the implementation, including:

- Dockerfiles;
- Docker Compose configuration;
- MariaDB initialization scripts;
- WordPress initialization scripts;
- NGINX configuration;
- PHP-FPM configuration;
- Makefile rules.

The code was then manually implemented, tested, and adapted by the student.

### Debugging and verification

AI assistance was also used to analyze errors and command outputs during development, such as:

- container startup problems;
- MariaDB initialization;
- database persistence;
- WordPress persistence;
- PHP-FPM configuration;
- Docker networking;
- volume persistence;
- NGINX and TLS configuration.

The final implementation was tested manually using Docker and Docker Compose commands.

### Documentation

AI assistance was used to review the README and documentation structure and to ensure that the required information from the 42 subject was covered.

All AI suggestions were reviewed, understood, tested, and adapted manually before being used.
