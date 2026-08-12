COMPOSE_FILE = srcs/docker-compose.yml
ENV_FILE = srcs/.env
DATA_DIR = $(HOME)/data

all: up

prepare:
	mkdir -p $(DATA_DIR)/mariadb
	mkdir -p $(DATA_DIR)/wordpress

build:
	docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build

up: prepare
	docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d --build

down:
	docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down

clean: down
	docker system prune -af

fclean: clean
	docker volume rm srcs_mariadb_data srcs_wordpress_data 2>/dev/null || true
	sudo rm -rf $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

re: fclean up

logs:
	docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs -f

status:
	docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps

.PHONY: all prepare build up down clean fclean re logs status