##############################
## Container Image commands ##
##############################

BASIC_IMG := buggy-basic
SCRATCH_IMG := buggy-scratch
DELVE_IMG := buggy-with-delve
LOCAL_HTTP_PORT := 8080
BASIC_IMAGE_CONTAINER_NAME := basic-image

# Build basic container image.
.PHONY: build-image
build-image:
	docker build --rm -f build/Dockerfile-basic -t $(BASIC_IMG):latest .

.PHONY: remove-build-image
remove-build-image:
	docker rmi $(BASIC_IMG):latest .

.PHONY: run-basic-image
run-basic-image: build-image
	docker run -it --name $(BASIC_IMAGE_CONTAINER_NAME) --detach -p $(LOCAL_HTTP_PORT):8080 --rm $(BASIC_IMG)

.PHONY: kill-basic-image
.IGNORE: kill-basic-image
kill-basic-image:
	docker kill basic-image

.PHONY: curl-app
curl-app:
	curl localhost:$(LOCAL_HTTP_PORT)/foo/bar

# Copy dlv binary into basic container.
.PHONY: copy-dlv-to-container
copy-dlv-to-container:
	docker cp $$(which dlv) $$(docker ps -aqf "ancestor=$(BASIC_IMG)"):/dlv

# Exec dlv within basic container.
.PHONY: exec-dlv-basic-container
exec-dlv-basic-container: copy-dlv-to-container
	docker exec -it $$(docker ps -aqf "ancestor=$(BASIC_IMG)") /dlv attach 1


# to fix the following error:
#  docker exec -it $(docker ps -aqf "ancestor=buggy-basic") /dlv attach 1
#     Could not attach to pid 1: this could be caused by a kernel security setting, try writing "0" to /proc/sys/kernel/yama/ptrace_scope
#     make: *** [Makefile:35: exec-dlv-basic-container] Error 1
# @@@ NOTE:
#    Changes a setting a global level. Not recommended for PROD environments
#    A better approach is to use the  'run-basic-image-with-ptrace' target
.PHONY: change-ptrace-yama
change-ptrace-yama:
	echo "0" | sudo tee /proc/sys/kernel/yama/ptrace_scope

.PHONY: reset-ptrace-yama
reset-ptrace-yama:
	echo "1" | sudo tee /proc/sys/kernel/yama/ptrace_scope

# Run basic image with ptrace SYS_CAP.
.PHONY: run-basic-image-with-ptrace
run-basic-image-with-ptrace: kill-basic-image build-image
	docker run --name $(BASIC_IMAGE_CONTAINER_NAME)  -it --detach --rm -p $(LOCAL_HTTP_PORT):8080 --cap-add=SYS_PTRACE $(BASIC_IMG)

# Exec dlv within basic container, using substitute path config.
.PHONY: exec-dlv-basic-container-with-src
exec-dlv-basic-container-with-src: run-basic-image-with-ptrace copy-dlv-to-container
	docker cp $$(pwd) $$(docker ps -aqf "ancestor=$(BASIC_IMG)"):/src
	docker cp /usr/local/go $$(docker ps -aqf "ancestor=$(BASIC_IMG)"):/goroot
	docker exec -it $$(docker ps -aqf "ancestor=$(BASIC_IMG)") /dlv --init=/src/hack/delve-container-initfile attach 1

.PHONY: build-scratch-image
build-scratch-image:
	docker build --rm -f build/Dockerfile-scratch -t $(SCRATCH_IMG):latest .

.PHONY: build-debug-image
build-debug-image:
	docker build --rm -f build/Dockerfile-debug -t buggy-debug:latest .

# Run scratch image.
.PHONY: run-scratch-image
run-scratch-image:
	docker run -it --detach -p $(LOCAL_HTTP_PORT):8080 --name=buggy-scratch --rm $(SCRATCH_IMG)

# Debug scratch image.
.PHONY: debug-scratch-image
debug-scratch-image:
	docker run -it --cap-add=SYS_PTRACE --rm --pid="container:buggy-scratch" buggy-debug /bin/bash
