all: image

CONTAINER_CMD ?=
IMAGE_NAME := micro-osd

ifeq ($(CONTAINER_CMD),)
	CONTAINER_CMD:=$(shell docker version >/dev/null 2>&1 && echo docker)
endif
ifeq ($(CONTAINER_CMD),)
	CONTAINER_CMD:=$(shell podman version >/dev/null 2>&1 && echo podman)
endif

image: Dockerfile micro-osd.sh micro-osd.sh
	$(CONTAINER_CMD) build . -t $(IMAGE_NAME)

.PHONY: image
