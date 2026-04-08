SHELL := /bin/bash

COMPOSE ?= docker compose
SERVICE ?= builder
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: help compose-build compose-up compose-down shell build build-matrix deps package export redroid-push redroid-test redroid-pip clean distclean

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  make compose-build   # builda a imagem Docker do builder' \
	  '  make compose-up      # sobe o container builder em background' \
	  '  make shell           # abre um shell dentro do builder' \
	  '  make build           # executa pipeline completa de build e empacotamento' \
	  '  make build-matrix    # executa build serial para multiplos ABIs' \
	  '  make deps            # compila somente dependencias third-party' \
	  '  make package         # reempacota artefatos a partir do staging atual' \
	  '  make export          # recria checksums/manifests dos artefatos' \
	  '  make redroid-push    # copia runtime minimal para o container Redroid' \
	  '  make redroid-test    # executa smoke test no Redroid' \
	  '  make redroid-pip     # habilita pip e testa instalacao de pacote pure-Python no Redroid' \
	  '  make clean           # limpa build, staging e dist' \
	  '  make distclean       # limpa tambem downloads/cache locais'

compose-build:
	$(COMPOSE) build $(SERVICE)

compose-up:
	$(COMPOSE) up -d $(SERVICE)

compose-down:
	$(COMPOSE) down

shell:
	$(COMPOSE) exec $(SERVICE) bash

build:
	$(COMPOSE) exec $(SERVICE) bash -lc "./scripts/build-all.sh"

build-matrix:
	$(COMPOSE) exec $(SERVICE) bash -lc "./scripts/build-matrix.sh"

deps:
	$(COMPOSE) exec $(SERVICE) bash -lc "./scripts/build-deps.sh"

package:
	$(COMPOSE) exec $(SERVICE) bash -lc "./scripts/package-runtime.sh"

export:
	$(COMPOSE) exec $(SERVICE) bash -lc "./scripts/export-artifacts.sh"

redroid-push:
	./scripts/redroid-push.sh

redroid-test:
	./scripts/redroid-test.sh

redroid-pip:
	./scripts/redroid-enable-pip.sh && ./scripts/redroid-pip-install.sh urllib3

clean:
	./scripts/clean.sh

distclean:
	./scripts/clean.sh --distclean
