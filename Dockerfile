FROM golang:1.24.0 AS goreturns
ARG GORETURNS_REV
RUN GOOS=wasip1 GOARCH=wasm go install github.com/sqs/goreturns@${GORETURNS_REV}
RUN install -Dm644 bin/wasip1_wasm/goreturns /dist/goreturns-${GORETURNS_REV}.wasm

FROM ghcr.io/webassembly/wasi-sdk:sha-d94a133 AS jq
RUN apt-get update && apt-get install --yes git
ARG JQ_VERSION
RUN git clone --branch=jq-${JQ_VERSION} --depth=1 --recurse-submodules https://github.com/jqlang/jq.git
RUN cd jq \
    && autoreconf --install \
    && CFLAGS=-D_WASI_EMULATED_SIGNAL LDFLAGS=-lwasi-emulated-signal \
    ./configure --host=wasm32 --target=wasm32-wasi --with-oniguruma=builtin \
    && make
RUN install -Dm644 jq/jq /dist/jq-${JQ_VERSION}.wasm

FROM scratch
COPY --from=goreturns dist/ ./
COPY --from=jq dist/ ./
