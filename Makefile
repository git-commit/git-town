.DEFAULT_GOAL := spec
date := $(shell TZ=UTC date -u '+%Y-%m-%d')

build:  # builds for the current platform
	go install -ldflags "-X github.com/git-town/git-town/src/cmd.version=v0.0.0-test -X github.com/git-town/git-town/src/cmd.buildDate=today"

build-release: cross-compile  # builds the artifacts for a new release
	package/debian/make_deb.sh

cross-compile:  # builds the binary for all platforms
	go get github.com/mitchellh/gox
	gox -ldflags "-X github.com/git-town/git-town/src/cmd.version=${TRAVIS_TAG} -X github.com/git-town/git-town/src/cmd.buildDate=${date}" \
			-output "dist/{{.Dir}}-${TRAVIS_TAG}-{{.OS}}-{{.Arch}}"

cuke: build   # runs the new Godog-based feature tests
	godog --concurrency=$(shell nproc --all) --format=progress --strict features/git-town features/git-town-alias features/git-town-append features/git-town-config features/git-town-hack features/git-town-install-fish-autocompletion features/git-town-kill features/git-town-main_branch features/git-town-new-branch-push-flag features/git-town-new-pull-request features/git-town-offline-mode features/git-town-perennial_branches features/git-town-prepend features/git-town-prune-branches features/git-town-pull_branch_strategy features/git-town-rename-branch features/git-town-repo features/git-town-set-parent-branch features/git-town-ship features/git-town-sync features/git-town-version

deploy:  # deploys the website
	git checkout gh-pages
	git pull
	git checkout master
	git pull --rebase
	tools/harp/node_modules/.bin/harp compile website/ _www
	git checkout gh-pages
	cp -r _www/* .
	rm -rf _www
	git add -A
	git commit
	git push
	git checkout master

fix: fix-go fix-md  # auto-fixes lint issues in all languages

fix-go:  # auto-fixes all Go lint issues
	gofmt -s -w ./src ./test

fix-md:  # auto-fixes all Markdown lint issues
	tools/prettier/node_modules/.bin/prettier --write .

help:  # prints all make targets
	@cat Makefile | grep '^[^ ]*:' | grep -v '.PHONY' | grep -v help | sed 's/:.*#/#/' | column -s "#" -t

lint: lint-go lint-md   # lints all the source code

lint-go:  # lints the Go files
	golangci-lint run --enable-all -D dupl -D lll -D gochecknoglobals -D gochecknoinits -D goconst -D wsl -D gomnd src/... test/...

lint-md:   # lints the Markdown files
	tools/prettier/node_modules/.bin/prettier -l .
	tools/text-runner/node_modules/.bin/text-run --offline

setup: setup-go  # the setup steps necessary on developer machines
	bundle install
	cd tools/harp && yarn install
	cd tools/text-runner && yarn install

setup-go:
	GO111MODULE=on go get github.com/cucumber/godog/cmd/godog@v0.9.0
	curl -sfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh| sh -s -- -b $(shell go env GOPATH)/bin v1.23.8

stats:  # shows code statistics
	@find . -type f | grep -v '\./node_modules/' | grep -v '\./vendor/' | grep -v '\./.git/' | xargs scc

test: lint unit cuke  # runs all the tests
.PHONY: test

test-go: build unit cuke lint-go  # runs all tests for Golang

test-md: lint-md   # runs all Markdown tests

u:  # runs only the unit tests for changed code
	go test -timeout 5s ./src/... ./test/...

unit:  # runs all the unit tests with race detector
	go test -count=1 -timeout 20s -race ./src/... ./test/...

update:  # updates all dependencies
	go get -u ./...
	go mod tidy
	go mod vendor
