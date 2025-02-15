MAKEFLAGS += -j2
OS := $(shell uname;)
SELINUXOPT ?= $(shell test -x /usr/sbin/selinuxenabled && selinuxenabled && echo -Z)
PREFIX ?= /usr/local
BINDIR ?= ${PREFIX}/bin
SHAREDIR ?= ${PREFIX}/share
PYTHON ?= $(shell command -v python3 python|head -n1)
DESTDIR ?= /
PATH := $(PATH):$(HOME)/.local/bin
IMAGE ?= ramalama
GPU ?= cpu

default: help

help:
	@echo "Build Container Image"
	@echo
	@echo "  - make build"
	@echo "  - make build IMAGE=ramalama"
	@echo "  - make multi-arch"
	@echo "  - make multi-arch IMAGE=ramalama"
	@echo
	@echo "Build RAG Container Image"
	@echo
	@echo "  - make build-rag IMAGE=quay.io/ramalama/ramalama GPU=ramalama"
	@echo
	@echo "Build docs"
	@echo
	@echo "  - make docs"
	@echo
	@echo "Install ramalama"
	@echo
	@echo "  - make install"
	@echo
	@echo "Test ramalama"
	@echo
	@echo "  - make test"
	@echo
	@echo "Clean the repository"
	@echo
	@echo "  - make clean"
	@echo


.PHONY: install-requirements
install-requirements:
	pipx install \
			argcomplete~=3.0 \
			black~=25.0 \
			codespell~=2.0 \
			flake8~=7.0 \
			huggingface_hub~=0.28.0 \
			isort~=6.0 \
			wheel~=0.45.0 \

.PHONY: install-completions
install-completions: completions
	install ${SELINUXOPT} -d -m 755 $(DESTDIR)${SHAREDIR}/bash-completion/completions
	install ${SELINUXOPT} -m 644 completions/bash-completion/completions/ramalama \
		$(DESTDIR)${SHAREDIR}/bash-completion/completions/ramalama
	install ${SELINUXOPT} -d -m 755 $(DESTDIR)${SHAREDIR}/fish/vendor_completions.d
	install ${SELINUXOPT} -m 644 completions/fish/vendor_completions.d/ramalama.fish \
		$(DESTDIR)${SHAREDIR}/fish/vendor_completions.d/ramalama.fish
	install ${SELINUXOPT} -d -m 755 $(DESTDIR)${SHAREDIR}/zsh/site
	install ${SELINUXOPT} -m 644 completions/zsh/vendor-completions/_ramalama \
		$(DESTDIR)${SHAREDIR}/zsh/vendor-completions/_ramalama

.PHONY: install-shortnames
install-shortnames:
	install ${SELINUXOPT} -d -m 755 $(DESTDIR)$(SHAREDIR)/ramalama
	install ${SELINUXOPT} -m 644 shortnames/shortnames.conf \
		$(DESTDIR)$(SHAREDIR)/ramalama

.PHONY: completions
completions:
	mkdir -p completions/bash-completion/completions
	register-python-argcomplete --shell bash ramalama > completions/bash-completion/completions/ramalama

	mkdir -p completions/fish/vendor_completions.d
	register-python-argcomplete --shell fish ramalama > completions/fish/vendor_completions.d/ramalama.fish

	mkdir -p completions/zsh/vendor-completions
	-register-python-argcomplete --shell zsh ramalama > completions/zsh/vendor-completions/_ramalama

.PHONY: install
install: docs completions
	RAMALAMA_VERSION=$(RAMALAMA_VERSION) \
	pip install . --no-deps --root $(DESTDIR) --prefix ${PREFIX}

.PHONY: build
build:
	./container_build.sh build $(IMAGE)

.PHONY: build-rm
build-rm:
	./container_build.sh -r build $(IMAGE)

.PHONY: build_multi_arch
build_multi_arch:
	./container_build.sh multi-arch $(IMAGE)

.PHONY: build-rag
build-rag:
	podman build --no-cache --build-arg IMAGE=${IMAGE} --build-arg GPU=${GPU} -t ${IMAGE}-rag container-images/pragmatic

.PHONY: install-docs
install-docs: docs
	make -C docs install

.PHONY: docs
docs:
	make -C docs

.PHONY: lint
lint:
	flake8 *.py ramalama/*.py

.PHONY: check-format
check-format:
	black --check --diff *.py ramalama/*.py
	isort --check --diff *.py ramalama/*.py

.PHONY: format
format:
	black *.py ramalama/*.py
	isort *.py ramalama/*.py

.PHONY: codespell
codespell:
	codespell --dictionary=- -w --skip="*/venv*"

.PHONY: test-run
test-run:
	_RAMALAMA_TEST=local RAMALAMA=$(CURDIR)/bin/ramalama bats -T test/system/030-run.bats
	_RAMALAMA_OPTIONS=--nocontainer _RAMALAMA_TEST=local bats -T test/system/030-run.bats

.PHONY: validate
validate: codespell lint
ifeq ($(OS),Linux)
	hack/man-page-checker
	hack/xref-helpmsgs-manpages
endif

.PHONY: pypi
pypi:   clean
	make docs
	python3 -m build --sdist
	python3 -m build --wheel
	python3 -m twine upload dist/*

.PHONY: bats
bats:
	RAMALAMA=$(CURDIR)/bin/ramalama bats -T test/system/

.PHONY: bats-nocontainer
bats-nocontainer:
	_RAMALAMA_TEST_OPTS=--nocontainer RAMALAMA=$(CURDIR)/bin/ramalama bats -T test/system/

.PHONY: bats-docker
bats-docker:
	_RAMALAMA_TEST_OPTS=--engine=docker RAMALAMA=$(CURDIR)/bin/ramalama bats -T test/system/

.PHONY: ci
ci:
	test/ci.sh

.PHONY: test
test: validate bats bats-nocontainer ci
	make clean
	hack/tree_status.sh

.PHONY: clean
clean:
	@find . -name \*~ -delete
	@find . -name \*# -delete
	@find . -name \*.rej -delete
	@find . -name \*.orig -delete
	rm -rf $$(<.gitignore)
	make -C docs clean
