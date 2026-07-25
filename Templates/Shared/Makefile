PROJECT := {{PROJECT_NAME}}
SCHEME  := {{SCHEME_NAME}}

# What xcodebuild is pointed at. With CocoaPods this is the workspace
# `pod install` produces — building the project directly leaves the pods out.
CONTAINER := {{CONTAINER_FILE}}
CONTAINER_FLAG := {{CONTAINER_FLAG}}

{{DESTINATION_BLOCK}}

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: generate
generate: ## Regenerate $(CONTAINER) from project.yml
{{GENERATE_RECIPE}}

.PHONY: open
open: generate ## Regenerate and open in Xcode
	open $(CONTAINER)

.PHONY: build
build: generate ## Build the app
	xcodebuild build $(CONTAINER_FLAG) $(CONTAINER) -scheme $(SCHEME) \
		-destination '$(BUILD_DESTINATION)'

.PHONY: test
test: generate ## Run the tests
	xcodebuild test $(CONTAINER_FLAG) $(CONTAINER) -scheme $(SCHEME) \
		-destination '$(DESTINATION)'

.PHONY: lint
lint: ## Check formatting and lint rules
{{LINT_RECIPE}}

.PHONY: format
format: ## Apply formatting in place
{{FORMAT_RECIPE}}

.PHONY: clean
clean: ## Remove build artefacts
	rm -rf {{CLEAN_ARTEFACTS}}
