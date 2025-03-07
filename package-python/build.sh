#! /usr/bin/env sh
set -eux

NAME=$1
VERSION=$2
WASM=$3
OUT_DIR=$4

ASSET_DIR=$(dirname $0)
BUILD_DIR=$(mktemp -d)

NAME=${NAME} VERSION=${VERSION} envsubst < ${ASSET_DIR}/pyproject.toml |
    install -Dm644 /dev/stdin ${BUILD_DIR}/pyproject.toml
install -Dm644 ${ASSET_DIR}/__init__.py ${BUILD_DIR}/src/${NAME}_wasi/__init__.py
install -Dm644 ${WASM} ${BUILD_DIR}/src/${NAME}_wasi/main.wasm

uv --directory=${BUILD_DIR} build --out-dir=${OUT_DIR} --wheel
rm ${OUT_DIR}/.gitignore
