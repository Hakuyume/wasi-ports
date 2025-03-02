#! /usr/bin/env sh
set -eux
cd $(dirname $0)

REV=16fc3d8
REL=1

docker run \
       --env=GOOS=wasip1 \
       --env=GOARCH=wasm \
       --rm \
       golang:1.24.0 \
       sh -euxc \
       "go install github.com/sqs/goreturns@${REV} && cat bin/wasip1_wasm/goreturns" > goreturns.wasm

cp goreturns.wasm src/goreturns_wasi/goreturns.wasm
echo "__version__ = \"0.0.0+${REV}.${REL}\"" > src/goreturns_wasi/_version.py
