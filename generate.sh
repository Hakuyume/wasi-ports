#! /usr/bin/env sh
set -eux
cd $(dirname $0)

IIDFILE=$(mktemp)
docker buildx build --iidfile ${IIDFILE} --load .

CID=$(docker create $(cat ${IIDFILE}) true)
docker cp ${CID}:dist/ ./
