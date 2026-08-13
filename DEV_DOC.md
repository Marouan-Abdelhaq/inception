# Developer Documentation

This document describes how a developer can set up, build, run, and maintain the Inception project.

---

## Requirements

* A Linux virtual machine (Debian or Alpine, penultimate stable version).
* Docker Engine and the Docker Compose plugin installed on that VM.
* `make`, `git`, and `openssl` installed.

---

## Repository Layout

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
├── secrets/                    # git-ignored, must exist locally
│   ├── mysql_password.txt
│   ├── mysql_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env                    # git-ignored, must exist locally
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/
        │   └── tools/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/
        │   └── tools/
        └── wordpress/
            ├── Dockerfile
            ├── .dockerignore
            ├── conf/
            └── tools/
```

---

## Setting Up the Environment From Scratch

### Configuration Files and Secrets

Both `srcs/.env` and everything under `secrets/` are intentionally excluded from version control (see `.gitignore`), since they hold sensitive or environment-specific values. They are not included in the repository and must be created manually on any machine that clones this project.

**`srcs/.env`** — non-sensitive configuration, for example:

```env
DOMAIN_NAME=mabdelha.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

WP_TITLE=Inception
WP_ADMIN_USER=mainadm
WP_ADMIN_EMAIL=admin@mabdelha.42.fr
WP_USER=secondary_user
WP_USER_EMAIL=user@mabdelha.42.fr
```

**`secrets/`** — one password per file, no trailing content beyond the password itself:

```bash
openssl rand -base64 16 > secrets/mysql_password.txt
openssl rand -base64 16 > secrets/mysql_root_password.txt
openssl rand -base64 16 > secrets/wp_admin_password.txt
openssl rand -base64 16 > secrets/wp_user_password.txt
```

These files are referenced in `srcs/docker-compose.yml` under each service's `secrets:` section, and mounted read-only inside the containers at `/run/secrets/<name>` at runtime. They are never baked into an image layer and never passed as plain build arguments.

### Domain Resolution

Add the project domain to the local hosts resolution, pointing to the VM's IP address:

```bash
echo "<VM_IP> mabdelha.42.fr" | sudo tee -a /etc/hosts
```

---

## Dockerfile Requirements to Keep in Mind

Each service's Dockerfile is checked individually during evaluation, so the following must always hold:

* One Dockerfile per service, non-empty, none missing.
* `FROM` must pin an explicit, penultimate stable version — for example `FROM alpine:3.19` or `FROM debian:bookworm`, never a bare `alpine`, a bare `debian`, or the `latest` tag.
* No ready-made service image is pulled (no `FROM wordpress`, `FROM nginx`, `FROM mariadb`, and so on) — only the base OS image is allowed from outside.
* The built image name must match the service name exactly.
* No password is ever hardcoded in a Dockerfile — only read from environment variables or from `/run/secrets/*` at runtime.
* No entrypoint or script uses an infinite-loop pattern such as `tail -f`, `sleep infinity`, or `while true`.

To confirm the whole stack was set up correctly through Compose, without any crash:

```bash
docker compose -f srcs/docker-compose.yml ps
```

---

## Building and Launching the Project

All operations go through the `Makefile`, which wraps `docker compose` calls on `srcs/docker-compose.yml`.

| Command | Effect |
|---|---|
| `make` / `make all` | Prepares data directories, builds all images, and starts every container in the background. |
| `make build` | Builds (or rebuilds) images without starting any container. |
| `make up` | Builds if needed and starts all containers. |
| `make down` | Stops all containers, keeps volumes/data intact. |
| `make clean` | Stops and removes the project containers and networks, then removes unused Docker resources (`docker system prune -af`) — this does not necessarily remove every image or container on the host, only unused ones. |
| `make fclean` | `clean` + removes the named volumes and the data stored under `/home/mabdelha/data`. |
| `make re` | `fclean` followed by `up` — full rebuild from scratch. |
| `make logs` | Follows the logs of all running containers. |
| `make status` | Shows the current status of all containers (`docker compose ps`). |

`docker compose build` only compiles images. `docker compose up --build` compiles the images (if needed) and creates the network, the volumes, and starts the containers — this is why `make up`/`make` use `up --build` rather than chaining `build` then `up` manually.

You can also call Docker Compose directly, bypassing the Makefile, for finer control:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d --build
```

---

## Managing Containers and Volumes

**List running containers:**

```bash
docker compose -f srcs/docker-compose.yml ps
```

**Enter a running container's shell:**

```bash
docker exec -it mariadb sh
docker exec -it wordpress bash
docker exec -it nginx sh
```

**View logs of one specific service:**

```bash
docker compose -f srcs/docker-compose.yml logs -f wordpress
```

**List Docker networks / inspect the project's network:**

```bash
docker network ls
docker network inspect <network_name>
```

**List Docker volumes / inspect the two named volumes:**

```bash
docker volume ls
docker volume inspect <mariadb_volume_name>
docker volume inspect <wordpress_volume_name>
```

**Force a rebuild of a single service** (for example, after editing its Dockerfile):

```bash
docker compose -f srcs/docker-compose.yml build wordpress
docker compose -f srcs/docker-compose.yml up -d wordpress
```

**Test crash recovery** (containers must restart automatically):

```bash
docker kill mariadb
sleep 5
docker compose -f srcs/docker-compose.yml ps
```

---

## Where Project Data Is Stored and How It Persists

The project uses two Docker named volumes for persistent data — they are referenced by name in each service's `volumes:` section, not declared as direct bind mounts:

* `mariadb_data` → mounted inside the MariaDB container at `/var/lib/mysql`.
* `wordpress_data` → mounted inside both the WordPress and NGINX containers at `/var/www/html` (shared, so NGINX can serve the WordPress files).

Both volumes are configured with the Docker `local` volume driver and `driver_opts` (`type: none`, `o: bind`) in their top-level `volumes:` definition in `srcs/docker-compose.yml`, so their data physically lives under:

```text
/home/mabdelha/data/mariadb
/home/mabdelha/data/wordpress
```

on the host machine. This is a named volume with a host-backed storage location configured at the volume level — distinct from a bind mount, which would instead be declared directly in a service's `volumes:` list (e.g. `- /home/mabdelha/data/mariadb:/var/lib/mysql`).

**Why this matters:** the writable layer of a container is destroyed when the container is removed (`docker rm`, or implicitly by `docker compose down` followed by recreation). Because the database files and the WordPress installation live in named volumes instead, they survive `docker compose down && docker compose up`, container recreation, and image rebuilds. Only `make fclean` (or a manual `docker volume rm`) actually deletes this persisted data.

**Verifying persistence manually:**

```bash
# Write test data
docker exec -it mariadb mariadb -u root -p -e \
  "CREATE TABLE IF NOT EXISTS wordpress.test42 (id INT); INSERT INTO wordpress.test42 VALUES (42);"

# Restart everything
make down && make up

# Confirm the data survived
docker exec -it mariadb mariadb -u root -p -e "SELECT * FROM wordpress.test42;"
```

**Verifying persistence across a full VM reboot:**

```bash
sudo reboot
# once back up:
make up
docker compose -f srcs/docker-compose.yml ps   # all three containers should be Up again
```

Since the named volumes store their data on the host filesystem under `/home/mabdelha/data`, this data survives a VM reboot as long as `make up` is re-run afterwards. Docker itself does not start containers automatically on boot unless explicitly configured to; this project relies on manually running `make up` after a reboot.

---

## Startup Scripts (Idempotency)

Each of the three services uses its `tools/setup.sh` script as the container's Docker `ENTRYPOINT` (all three Dockerfiles use `ENTRYPOINT ["/setup.sh"]`, consistently). Each script performs initialization only when needed, then hands off to the real service process with `exec`, so that process becomes PID 1 and receives signals such as `SIGTERM` on `docker stop` correctly:

* **MariaDB** — on first start (detected by the absence of `/var/lib/mysql/mysql`), initializes the data directory with `mariadb-install-db`, then runs `mariadbd --bootstrap` to create the database, the application user, and set the root password from `/run/secrets/*`. Bootstrap mode executes the SQL synchronously in the foreground (fed via stdin) and exits on its own once done — it never opens a network socket and does not require a background process. On subsequent starts it skips initialization entirely. Ends with `exec mariadbd --user=mysql`.
* **WordPress** — waits for MariaDB to accept connections (bounded to 30 attempts, roughly one minute, before aborting with an error — not an unbounded loop), then, only if `/var/www/html/wp-config.php` does not already exist, downloads WordPress via WP-CLI, creates `wp-config.php`, runs `wp core install`, and creates the second user. Ends with `exec php-fpm8.2 -F`.
* **NGINX** — generates a self-signed TLS certificate only if `/etc/nginx/ssl/certificate.crt` and `/etc/nginx/ssl/private.key` do not already exist. Ends with `exec nginx -g "daemon off;"`.

No infinite-loop pattern (`tail -f`, `sleep infinity`, `while true`) is used to keep any container alive, and no service is started as a background process (`&`) inside an entrypoint script — MariaDB's initialization uses bootstrap mode instead of a temporary backgrounded daemon, and WordPress's wait-for-database loop is bounded to a fixed number of retries rather than looping indefinitely. Each script terminates in `exec`ing the real, foreground service process.