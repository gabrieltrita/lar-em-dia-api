SLUG := $(shell sed -n 's/^ *slug: *//p' config/app.yml)
SERVICE := $(SLUG)-api$(if $(DESTINATION),-$(DESTINATION))
ROLE ?= web
DEPLOY_SSH_USER ?= root

.PHONY: bash

bash:
	@test -n "$(DEPLOY_HOST)" || { echo "Set DEPLOY_HOST (export DEPLOY_HOST=... or make bash DEPLOY_HOST=...)"; exit 1; }
	ssh -t $(DEPLOY_SSH_USER)@$(DEPLOY_HOST) 'container=$$(docker ps -q --filter label=service=$(SERVICE) --filter label=role=$(ROLE) --filter status=running | head -n 1); test -n "$$container" || { echo "No running $(SERVICE) $(ROLE) container"; exit 1; }; docker exec -it $$container bash'
