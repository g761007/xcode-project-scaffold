PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build in debug
	swift build

.PHONY: test
test: ## Run the test suite
	swift test

.PHONY: lint
lint: ## Check formatting and lint rules (requires swiftformat and swiftlint)
	swiftformat --lint .
	swiftlint --strict

.PHONY: format
format: ## Apply formatting in place
	swiftformat .

.PHONY: release
release: ## Build in release
	swift build -c release

.PHONY: install
install: release ## Build and install xscaffold into $(BINDIR)
	@mkdir -p "$(BINDIR)"
	@install -m 0755 "$$(swift build -c release --show-bin-path)/xscaffold" "$(BINDIR)/xscaffold"
	@echo "Installed xscaffold to $(BINDIR)/xscaffold"
	@command -v xscaffold >/dev/null 2>&1 \
		|| echo "Warning: $(BINDIR) is not on your PATH."

.PHONY: clean
clean: ## Remove build artefacts
	swift package clean
	rm -rf .build
