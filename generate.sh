#! /usr/bin/env sh
set -eux
cd $(dirname $0)

GORETURNS_REV=16fc3d8
JQ_VERSION=1.7.1
SHELLCHECK_VERSION=0.10.0
SHFMT_VERSION=3.10.0

IIDFILE=$(mktemp)
docker buildx build \
    --build-arg=GORETURNS_REV=${GORETURNS_REV} \
    --build-arg=JQ_VERSION=${JQ_VERSION} \
    --build-arg=SHELLCHECK_VERSION=${SHELLCHECK_VERSION} \
    --build-arg=SHFMT_VERSION=${SHFMT_VERSION} \
    --iidfile ${IIDFILE} \
    --load \
    .

CID=$(docker create $(cat ${IIDFILE}) true)
mkdir -p dist
docker cp ${CID}:./ dist/

build_python() {
    NAME=$1
    VERSION=$2
    WASM=$3

    NAME=${NAME} VERSION=${VERSION} envsubst < templates/pyproject.toml |
        install -Dm644 /dev/stdin build/${NAME}-python/pyproject.toml
    install -Dm644 templates/__init__.py build/${NAME}-python/src/${NAME}_wasi/__init__.py
    install -Dm644 dist/${WASM} build/${NAME}-python/src/${NAME}_wasi/main.wasm

    (cd build/${NAME}-python && uv build --out-dir=../../dist)
}

build_python goreturns 0.0.0+${GORETURNS_REV} goreturns-${GORETURNS_REV}.wasm
build_python jq ${JQ_VERSION} jq-${JQ_VERSION}.wasm
build_python shellcheck ${SHELLCHECK_VERSION} shellcheck-${SHELLCHECK_VERSION}.wasm
build_python shfmt ${SHFMT_VERSION} shfmt-${SHFMT_VERSION}.wasm
