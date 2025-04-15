# Makefile for project management

# Default shell
SHELL := /bin/bash

# Help target
help:
	@echo "Available targets:"
	@echo "  diff <from_branch> <to_branch>  - Generate diff between two branches"
	@echo "    Example: make diff project dev"
	@echo "  update-swagger                  - Fetch and format latest Swagger API docs"
	@echo "  coreclearforce                  - Clear client database state to start from scratch"
	@echo "  app1                            - Run Flutter app on device at 127.0.0.1:6555"

# Diff target that takes two branch parameters
diff: _check_args
	@./projects/getDiff.sh $(ARG1) $(ARG2)

_check_args:
	@if [ "$(words $(MAKECMDGOALS))" -lt "3" ]; then \
		echo "Usage: make diff <from_branch> <to_branch>"; \
		echo "Example: make diff project dev"; \
		exit 1; \
	fi
	$(eval ARG1 := $(word 2,$(MAKECMDGOALS)))
	$(eval ARG2 := $(word 3,$(MAKECMDGOALS)))

# Update Swagger docs
update-swagger:
	@mkdir -p api-docs
	@echo "Fetching latest Swagger docs..."
	@echo "// Generated on $$(date)" > api-docs/swagger.json
	@curl -s https://docs.mycredex.app/develop/swagger.json/ | jq '.' >> api-docs/swagger.json
	@echo "Swagger docs updated in api-docs/swagger.json"

# Clear client database state
coreclearforce:
	@echo "Clearing client database state..."
	@cd vimbisopay_app && dart run lib/scripts/clear_db.dart
	@echo "Client database state cleared successfully."

# Catch-all target to handle the branch parameters
%:
	@:

# Run Flutter app on device at 127.0.0.1:6555
app1:
	@cd vimbisopay_app && flutter run -d 127.0.0.1:6555

.PHONY: help diff update-swagger coreclearforce app1
