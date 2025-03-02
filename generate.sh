#! /usr/bin/env sh
set -eux
cd $(dirname $0)

GORETURNS_REV=16fc3d8
JQ_VERSION=1.7.1

IIDFILE=$(mktemp)
docker buildx build \
    --build-arg=GORETURNS_REV=${GORETURNS_REV} \
    --build-arg=JQ_VERSION=${JQ_VERSION} \
    --iidfile ${IIDFILE} \
    --load \
    .

CID=$(docker create $(cat ${IIDFILE}) true)
mkdir -p dist
docker cp ${CID}:./ dist/

pyproject() {
    NAME=$1
    VERSION=$2
    WASM=$3

    NAME=${NAME} VERSION=${VERSION} envsubst < templates/pyproject.toml |
        install -Dm644 /dev/stdin dist/${NAME}/pyproject.toml
    install -Dm644 templates/__init__.py dist/${NAME}/src/${NAME}_wasi/__init__.py
    install -Dm644 dist/${WASM} dist/${NAME}/src/${NAME}_wasi/main.wasm
}

pyproject goreturns 0.0.0+${GORETURNS_REV} goreturns-${GORETURNS_REV}.wasm
pyproject jq ${JQ_VERSION} jq-${JQ_VERSION}.wasm
