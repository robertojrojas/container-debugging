#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

KIND_CNF_FILE=${KIND_CNF_FILE:-${SCRIPT_DIR}/kind-1master-2nodes.yaml}
KIND_VER=${KIND_VER:-v1.35.0}
kind create cluster --config ${KIND_CNF_FILE} --image=kindest/node:${KIND_VER}

