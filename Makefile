PATH=$(shell pwd)/src/bin:$(shell echo $$PATH)

.PHONY: default build clean build-debug prepare test test-docsy test-docuapi push-edge push-release bump enable-qemu

default: clean prepare build

build:
	@make -f target/bundle/Makefile || (tail -50 target/bundle/build.log && exit 1)

clean:
	@rm -rf target

build-debug: src/bin/buildx
	@make -f target/bundle/Makefile DEBUG=true

prepare: src/bin/buildx
	@rm -rf target/bundle
	@ARCH=$$(uname -m); \
	case $$ARCH in \
		aarch64|arm64) PLAT=linux/arm64 ;; \
		x86_64) PLAT=linux/amd64 ;; \
		*) PLAT=linux/amd64 ;; \
	esac; \
	 docker run --rm -i --platform=$$PLAT -v $$(pwd):/work -u $$(id -u) \
		klakegg/docker-project-prepare:edge \
		-t target/bundle || \
    ( echo "Image has no $$PLAT manifest; retrying with linux/amd64..."; \
      docker run --rm -i --platform=linux/amd64 -v $$(pwd):/work -u $$(id -u) \
        klakegg/docker-project-prepare:edge \
        -t target/bundle ) || \
    ( echo "Prepar­er failed on both platforms. If you are on Apple Silicon run: sudo make enable-qemu && make prepare"; exit 1 )
	@sed -i "s:DOCKER_CLI_EXPERIMENTAL=enabled docker buildx:buildx:g" target/bundle/Makefile
#	@sed -i 's:--progress plain \\:--progress plain \\\n                --annotation $(DOCKER_METADATA_OUTPUT_ANNOTATIONS) \\:g' target/bundle/Makefile
	@sed -i "s:--push:--provenance=true --sbom=true --push:g" target/bundle/Makefile

test: test-docsy test-docuapi

test-docsy:
	@rm -rf target/test/docsy
# 	@git clone -b v0.14.3 https://github.com/google/docsy.git target/test/docsy
	@git clone -b $$(curl -s https://api.github.com/repos/google/docsy/releases/latest | jq -r .tag_name) https://github.com/google/docsy.git target/test/docsy
	@docker run --rm -i -v $$(pwd)/target/test/docsy:/src -u $$(id -u) --entrypoint npm floryn90/hugo:ext-alpine install
	@docker run --rm -i -v $$(pwd)/target/test/docsy:/src -u $$(id -u) floryn90/hugo:ext-alpine

test-docuapi:
	@rm -rf target/test/docuapi
# 	@git clone -b v2.5.0 https://github.com/bep/docuapi.git target/test/docuapi
	@git clone -b $$(curl -s https://api.github.com/repos/bep/docuapi/releases/latest | jq -r .tag_name) https://github.com/bep/docuapi.git target/test/docuapi
	@docker run --rm -i -v $$(pwd)/target/test/docuapi:/src -u $$(id -u) --entrypoint npm floryn90/hugo:ext-alpine install
	@docker run --rm -i -v $$(pwd)/target/test/docuapi:/src -u $$(id -u) floryn90/hugo:ext-alpine

push-edge:
	@make -f target/bundle/Makefile push-edge

push-release:
	@make -f target/bundle/Makefile push-stable

bump:
	@RELEASE=$(version) bump

src/bin/buildx:
	@mkdir -p src/bin
	TAG=$$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | jq -r .tag_name); \
	OS=$$(uname -s); ARCH=$$(uname -m); \
	case $$ARCH in \
		x86_64) A=amd64 ;; \
		aarch64|arm64) A=arm64 ;; \
		armv7*|armv6*) A=arm-v7 ;; \
		*) A=amd64 ;; \
	esac; \
	case $$OS in \
		Darwin) PLAT=darwin-$$A ;; \
		Linux) PLAT=linux-$$A ;; \
		*) PLAT=linux-$$A ;; \
	esac; \
	URL="https://github.com/docker/buildx/releases/download/$$TAG/buildx-$$TAG.$$PLAT"; \
	echo "Downloading $$URL"; \
	curl -sL -o src/bin/buildx $$URL; \
	chmod a+x src/bin/buildx
	@docker buildx create --use || true

enable-qemu:
	@sudo docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
