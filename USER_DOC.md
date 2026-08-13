# User Documentation

This document explains, in simple terms, how an end user or administrator can use the Inception infrastructure once it has been built and started.

---

## Services Provided

The stack is composed of three services working together behind a single entry point:

| Service | Role |
|---|---|
| **NGINX** | The only entry point to the infrastructure. Serves the website over HTTPS on port 443. |
| **WordPress + PHP-FPM** | Runs the WordPress website (pages, articles, administration panel). |
| **MariaDB** | Stores all the website's data (articles, users, settings). |

WordPress and MariaDB are never reachable directly from outside the infrastructure — every request goes through NGINX first.

---

## Starting and Stopping the Project

All commands below are run from the root of the repository, where the `Makefile` is located.

**Start (build and launch) the whole infrastructure:**

```bash
make
```

**Stop the infrastructure** (containers are stopped, data is kept):

```bash
make down
```

**Restart the infrastructure after a stop:**

```bash
make up
```

**Reset the infrastructure completely** (stops and removes the project's containers and networks, removes unused Docker resources via `docker system prune -af`, and deletes the project's named volumes and the stored data under `/home/mabdelha/data` — use with caution, this deletes the WordPress database and files):

```bash
make fclean
```

**Rebuild everything from scratch:**

```bash
make re
```

---

## Accessing the Website and the Administration Panel

Once the infrastructure is running, open a browser and go to:

```text
https://mabdelha.42.fr
```

The browser may display a certificate warning the first time — this is expected, since the project uses a self-signed TLS certificate rather than one issued by a public certificate authority. You can safely proceed (e.g. "Advanced" → "Proceed anyway", the exact wording depends on the browser).

The WordPress site should load directly. The WordPress installation page should never appear, since WordPress is installed and configured automatically when the containers start.

The site is reachable only over HTTPS on port 443:

```bash
curl http://mabdelha.42.fr      # must fail, port 80 is not exposed
curl -k https://mabdelha.42.fr  # must return the site's HTML
```

To access the **WordPress administration panel**, go to:

```text
https://mabdelha.42.fr/wp-admin
```

Log in with the administrator account described below.

---

## Locating and Managing Credentials

All sensitive credentials are stored locally as plain text files in the `secrets/` directory at the root of the repository:

```text
secrets/
├── mysql_password.txt          # application database user password
├── mysql_root_password.txt     # database root password
├── wp_admin_password.txt       # WordPress administrator password
└── wp_user_password.txt        # WordPress regular user password
```

The corresponding usernames and the domain name are defined as environment variables in `srcs/.env` (for example `MYSQL_USER`, `WP_ADMIN_USER`, `WP_USER`, `DOMAIN_NAME`).

Neither `secrets/` nor `srcs/.env` are committed to Git — both must be present locally for the project to work.

The WordPress administrator account name never contains "admin" or "administrator", as required by the subject. Check `srcs/.env` for the exact value of `WP_ADMIN_USER`.

**Changing a password:** the initialization scripts only run their setup logic the first time (they detect that the database or WordPress is already installed and skip re-initialization on subsequent starts). Simply editing a file in `secrets/` and running `make up`/`make re` will **not** update the password of an already-existing database or WordPress installation. To actually apply a new password, the existing persistent data must be reset:

```bash
make fclean   # removes the named volumes and all stored data
make up       # re-initializes everything with the new credentials from secrets/
```

**Warning:** `make fclean` permanently deletes the existing WordPress site and MariaDB database.

---

## Checking That the Services Are Running Correctly

**Check that all three containers are up:**

```bash
docker compose -f srcs/docker-compose.yml ps
```

`mariadb`, `wordpress`, and `nginx` should all be listed with a status of `Up`.

**Check the logs of a specific service:**

```bash
docker compose -f srcs/docker-compose.yml logs mariadb
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs nginx
```

**Check that the website responds:**

```bash
curl -k https://mabdelha.42.fr
```

This should return the HTML of the WordPress homepage.

**Check that a container restarts automatically after a crash:**

```bash
docker kill mariadb
sleep 5
docker compose -f srcs/docker-compose.yml ps
```

The `mariadb` container should automatically restart and return to an `Up` state, according to its `restart: always` policy defined in `srcs/docker-compose.yml`. The short `sleep` here is only to give Docker a moment to restart the container before checking — it is a manual verification step, not part of any container's entrypoint (the subject's restriction on `sleep`-based hacks applies to entrypoints used to keep a container artificially alive, not to this kind of check).

---

## Checking Persistence After a Reboot

Because WordPress and MariaDB data are stored in named volumes under `/home/mabdelha/data/`, the data must still be there after a full reboot of the virtual machine, not only after a container restart.

1. Make a visible change on the site (for example, edit a page or add a comment as a regular user) and confirm it appears on `https://mabdelha.42.fr`.
2. Reboot the virtual machine:

   ```bash
   sudo reboot
   ```

3. Once the virtual machine is back up, relaunch the project:

   ```bash
   make up
   ```

4. Confirm that all three containers are running and that the change made in step 1 is still visible on the website.

If any of these checks fail, see `DEV_DOC.md` for lower-level debugging commands.