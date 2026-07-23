PROJECT := {{PROJECT_NAME}}
SCHEME  := {{SCHEME_NAME}}

# If you have the same device installed under several runtimes, xcodebuild
# warns and picks one. Pin it when that matters:
#   make test DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=18.0'
#   make test DESTINATION='id=<simulator-udid>'      # xcrun simctl list devices
DESTINATION ?= platform=iOS Simulator,name=iPhone 16

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: generate
generate: ## Regenerate $(PROJECT).xcodeproj from project.yml
	xcodegen generate

.PHONY: open
open: generate ## Regenerate and open in Xcode
	open $(PROJECT).xcodeproj

.PHONY: build
build: generate ## Build the app
	xcodebuild build -project $(PROJECT).xcodeproj -scheme $(SCHEME) -destination '$(DESTINATION)'

.PHONY: test
test: generate ## Run the tests
	xcodebuild test -project $(PROJECT).xcodeproj -scheme $(SCHEME) -destination '$(DESTINATION)'

.PHONY: lint
lint: ## Check formatting and lint rules
{{LINT_RECIPE}}

.PHONY: format
format: ## Apply formatting in place
{{FORMAT_RECIPE}}

.PHONY: clean
clean: ## Remove build artefacts
	rm -rf DerivedData build $(PROJECT).xcodeproj
