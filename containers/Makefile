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

### Kubernetes

.PHONY: run-kind
run-kind:
	k8s/create_kind_cluster.sh

.PHONY: tag-buggy-scratch-image-kind
tag-buggy-scratch-image-kind: build-scratch-image
	docker tag buggy-scratch:latest buggy-scratch:v1-kind

.PHONY: tag-buggy-debug-image-kind
tag-buggy-debug-image-kind: build-debug-image
	docker tag buggy-debug:latest buggy-debug:v1-kind

.PHONY: kind-load-buggy-scratch
kind-load-buggy-scratch:
	kind load docker-image --name debug buggy-scratch:v1-kind

.PHONY: kind-load-buggy-debug
kind-load-buggy-debug:
	kind load docker-image --name debug buggy-debug:v1-kind

.PHONY: deploy-buggy-scratch
deploy-buggy-scratch: 
	kubectl apply -f k8s/deploy.yaml

.PHONY: undeploy-buggy-scratch
undeploy-buggy-scratch: 
	kubectl delete -f k8s/deploy.yaml

.PHONY: kubectl-port-forward-2345
kubectl-port-forward-2345:
	kubectl port-forward svc/buggy-scratch 2345:2345

.PHONY: kubectl-port-forward-8080
kubectl-port-forward-8080:
	kubectl port-forward svc/buggy-scratch 8080:8080

KIND_NODE ?= $(shell kubectl get node -o "custom-columns=INTERNAL_IP:.status.addresses[].address" --no-headers | tail -1)
NODE_PORT ?= 32080
CURL_URL := "$(KIND_NODE):$(NODE_PORT)"
.PHONY: curl-app-kind
curl-app-kind:
	curl $(CURL_URL)

DEBUG_POD_CONTAINER := buggy-debug
.PHONY: debug-buggy-scrath-k8s
debug-buggy-scrath-k8s:
	dlv connect 127.0.0.1:2345 --init=./hack/delve-local-initfile

.PHONY: exec-scratch-k8s-add-debug
exec-scratch-k8s-add-debug:
	$(eval SCRATCH_POD := $(shell kubectl get pods -l app=buggy-scratch -o jsonpath='{.items[0].metadata.name}'))
	echo "pod: $(SCRATCH_POD)"
	kubectl debug -it pod/$(SCRATCH_POD) --image=buggy-debug:v1-kind --container=buggy-debug \
	 --target=buggy-scratch -- bash

.PHONY: exec-dlv-scratch-k8s-cp-src
exec-dlv-scratch-k8s-cp-src:
	$(eval SCRATCH_POD=$(shell kubectl get pods -l app=buggy-scratch -o jsonpath='{.items[0].metadata.name}'))
	kubectl cp $$(pwd) $(SCRATCH_POD):/src -c buggy-debug
	kubectl cp /usr/local/go $(SCRATCH_POD):/goroot -c buggy-debug
	#kubectl debug -it pod/$(SCRATCH_POD) --image=buggy-debug:v1-kind --container=buggy-debug --target=buggy-scratch -- \
	#	/dlv attach 1 --headless --listen=0.0.0.0:2345 --api-version=2 --accept-multiclient

.PHONY: exec-dlv-debug-k8s-reattach
exec-dlv-debug-k8s-reattach:
	$(eval SCRATCH_POD=$(shell kubectl get pods -l app=buggy-scratch -o jsonpath='{.items[0].metadata.name}'))
	kubectl attach $(SCRATCH_POD) -c buggy-debug -n default -i -t -- \
		/dlv attach 1 --headless --listen=0.0.0.0:2345 --api-version=2 --accept-multiclient


