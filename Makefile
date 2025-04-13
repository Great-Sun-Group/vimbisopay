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

# Diff target that takes two branch parameters
diff:
	@if [ "$(words $(MAKECMDGOALS))" -ne "3" ]; then \
		echo "Usage: make diff <from_branch> <to_branch>"; \
		echo "Example: make diff project dev"; \
		exit 1; \
	fi
	@./projects/getDiff.sh $(word 2,$(MAKECMDGOALS)) $(word 3,$(MAKECMDGOALS))

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

.PHONY: help diff update-swagger coreclearforce
