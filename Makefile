# Makefile for project management

# Default shell
SHELL := /bin/bash

# Help target
help:
	@echo "Available targets:"
	@echo "  diff <from_branch> <to_branch>  - Generate diff between two branches"
	@echo "    Example: make diff project dev"

# Diff target that takes two branch parameters
diff:
	@if [ "$(words $(MAKECMDGOALS))" -ne "3" ]; then \
		echo "Usage: make diff <from_branch> <to_branch>"; \
		echo "Example: make diff project dev"; \
		exit 1; \
	fi
	@./projects/getDiff.sh $(word 2,$(MAKECMDGOALS)) $(word 3,$(MAKECMDGOALS))

# Catch-all target to handle the branch parameters
%:
	@:

.PHONY: help diff
