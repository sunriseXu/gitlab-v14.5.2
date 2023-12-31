PREFIX=/usr/local
PKG := gitlab.com/gitlab-org/gitlab/workhorse
BUILD_DIR ?= $(CURDIR)
TARGET_DIR ?= $(BUILD_DIR)/_build
VERSION_STRING := $(shell git describe)
ifeq ($(strip $(VERSION_STRING)),)
VERSION_STRING := v$(shell cat VERSION)
endif
DATE_FMT = +%Y%m%d.%H%M%S
ifdef SOURCE_DATE_EPOCH
	BUILD_TIME := $(shell date -u -d "@$(SOURCE_DATE_EPOCH)" "$(DATE_FMT)" 2>/dev/null || date -u -r "$(SOURCE_DATE_EPOCH)" "$(DATE_FMT)" 2>/dev/null || date -u "$(DATE_FMT)")
else
	BUILD_TIME := $(shell date -u "$(DATE_FMT)")
endif
GOBUILD := go build -ldflags "-X main.Version=$(VERSION_STRING) -X main.BuildTime=$(BUILD_TIME)"
GITALY  := tmp/tests/gitaly/_build/bin/gitaly
GITALY_PID_FILE := gitaly.pid
EXE_ALL := gitlab-resize-image gitlab-zip-cat gitlab-zip-metadata gitlab-workhorse
INSTALL := install
BUILD_TAGS := tracer_static tracer_static_jaeger continuous_profiler_stackdriver

MINIMUM_SUPPORTED_GO_VERSION := 1.11

export GOBIN := $(TARGET_DIR)/bin
export PATH := $(GOBIN):$(PATH)
export GOPROXY ?= https://proxy.golang.org
export GO111MODULE=on

define message
	@echo "### $(1)"
endef


.NOTPARALLEL:

.PHONY:	all
all:	clean-build $(EXE_ALL)

.PHONY: gitlab-resize-image
gitlab-resize-image:
	$(call message,Building $@)
	$(GOBUILD) -tags "$(BUILD_TAGS)" -o $(BUILD_DIR)/$@ $(PKG)/cmd/$@

.PHONY: gitlab-zip-cat
gitlab-zip-cat:
	$(call message,Building $@)
	$(GOBUILD) -tags "$(BUILD_TAGS)" -o $(BUILD_DIR)/$@ $(PKG)/cmd/$@

.PHONY: gitlab-zip-metadata
gitlab-zip-metadata:
	$(call message,Building $@)
	$(GOBUILD) -tags "$(BUILD_TAGS)" -o $(BUILD_DIR)/$@ $(PKG)/cmd/$@

.PHONY: gitlab-workhorse
gitlab-workhorse:
	$(call message,Building $@)
	$(GOBUILD) -tags "$(BUILD_TAGS)" -o $(BUILD_DIR)/$@ $(PKG)

.PHONY:	install
install: $(EXE_ALL)
	$(call message,$@)
	mkdir -p $(DESTDIR)$(PREFIX)/bin/
	cd $(BUILD_DIR) && $(INSTALL) $(EXE_ALL) $(DESTDIR)$(PREFIX)/bin/

.PHONY:	test
test: prepare-tests
	$(call message,$@)
	go test -tags "$(BUILD_TAGS)" ./... ;\
	status="$$?" ;\
	if [ -f "$(GITALY_PID_FILE)" ] ; then \
		echo "Clean up Gitaly server for workhorse integration test" ;\
		kill -9 $$(cat $(GITALY_PID_FILE)) ;\
		rm $(GITALY_PID_FILE) ;\
	else \
		echo "Gitaly integration test not running" ;\
	fi ;\
	exit "$$status"
	@echo SUCCESS

.PHONY:	clean
clean: clean-workhorse clean-build
	$(call message,$@)
	rm -rf testdata/data testdata/scratch

.PHONY:	clean-workhorse
clean-workhorse:
	$(call message,$@)
	rm -f $(EXE_ALL)

.PHONY:	clean-build
clean-build:
	$(call message,$@)
	rm -rf $(TARGET_DIR)

.PHONY:	prepare-tests
prepare-tests:	run-gitaly
prepare-tests:	testdata/data/group/test.git $(EXE_ALL)
prepare-tests:	testdata/scratch

.PHONY: run-gitaly
run-gitaly: gitaly.pid

$(GITALY_PID_FILE): gitaly.toml
	@{ \
	if [ -z "$${GITALY_ADDRESS+x}" ] ; then \
		echo "To run gitaly integration tests set GITALY_ADDRESS=tcp://127.0.0.1:8075" ; \
	else \
		cd .. ; \
		GITALY_TESTING_NO_GIT_HOOKS=1 GITALY_PID_FILE=workhorse/$(GITALY_PID_FILE) $(GITALY) workhorse/gitaly.toml ; \
	fi \
	} &

gitaly.toml: ../tmp/tests/gitaly/config.toml
	sed -e 's/^socket_path.*$$/listen_addr = "0.0.0.0:8075"/;s/^\[auth\]$$//;s/^token.*$$//;s/^internal_socket_dir.*$$//' \
		$< > $@

testdata/data/group/test.git:
	$(call message,$@)
	git clone --quiet --bare https://gitlab.com/gitlab-org/gitlab-test.git $@

testdata/scratch:
	mkdir -p testdata/scratch

.PHONY: verify
verify: lint vet detect-context detect-assert check-formatting staticcheck deps-check

.PHONY: lint
lint:
	$(call message,Verify: $@)
	go install golang.org/x/lint/golint
	@_support/lint.sh ./...

.PHONY: vet
vet:
	$(call message,Verify: $@)
	@go vet ./...

.PHONY: detect-context
detect-context:
	$(call message,Verify: $@)
	_support/detect-context.sh

.PHONY: detect-assert
detect-assert:
	$(call message,Verify: $@)
	_support/detect-assert.sh

.PHONY: check-formatting
check-formatting: install-goimports
	$(call message,Verify: $@)
	@_support/fmt.sh check

# Megacheck will tailor some responses given a minimum Go version, so pass that through the CLI
# Additionally, megacheck will not return failure exit codes unless explicitly told to via the
# `-simple.exit-non-zero` `-unused.exit-non-zero` and `-staticcheck.exit-non-zero` flags
.PHONY: staticcheck
staticcheck:
	$(call message,Verify: $@)
	go install honnef.co/go/tools/cmd/staticcheck
	@ $(GOBIN)/staticcheck -go $(MINIMUM_SUPPORTED_GO_VERSION) ./...

# In addition to fixing imports, goimports also formats your code in the same style as gofmt
# so it can be used as a replacement.
.PHONY: fmt
fmt: install-goimports
	$(call message,$@)
	@_support/fmt.sh

.PHONY:	goimports
install-goimports:
	$(call message,$@)
	go install golang.org/x/tools/cmd/goimports

.PHONY: deps-check
deps-check:
	go mod tidy
	@if git diff --quiet --exit-code -- go.mod go.sum; then \
		echo "go.mod and go.sum are ok"; \
	else \
		echo ""; \
		echo "go.mod and go.sum are modified, please commit them";\
		exit 1; \
	fi;
