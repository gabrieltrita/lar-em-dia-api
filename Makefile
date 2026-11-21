ROLE ?= web
SERVICE_SUFFIX := -api$(if $(DESTINATION),-$(DESTINATION))

.PHONY: bash

bash:
	@container=$$(docker ps --filter label=role=$(ROLE) --filter status=running --format '{{.ID}} {{.Label "service"}}' | awk '$$2 ~ /$(SERVICE_SUFFIX)$$/ { print $$1; exit }'); \
	test -n "$$container" || { echo "No running *$(SERVICE_SUFFIX) $(ROLE) container"; exit 1; }; \
	docker exec -it $$container bash
