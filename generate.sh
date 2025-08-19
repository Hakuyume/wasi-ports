#! /usr/bin/env sh
set -eux
cd $(dirname $0)

docker buildx build --output=type=local,dest=dist .
