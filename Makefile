DOCKER					= docker
DOCKER_COMPOSE	= docker-compose
DOCKERFILE			= Dockerfile
PORT						= 8080
TAG             = sample-kotlin
LINT_IGNORE     = "DL3007"
GRADLEW         = ./gradlew
PACK            = pack
BUILDER_CNF = ./builder/builder.toml
BUILDER_IMG = my-builder:bionic
CONTAINER   = k3d-on-docker-dind

all:
	$(DOCKER_COMPOSE) up -d
	docker exec -it $(CONTAINER) sh /bootstrap/bootstrap.sh	
	export KUBECONFIG=$(PWD)/bootstrap/kubeconfig

clean:
	$(DOCKER_COMPOSE) down

