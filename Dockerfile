ARG GORETURNS_REV=16fc3d8
ARG JQ_VERSION=1.7.1
ARG SHELLCHECK_VERSION=0.10.0
ARG SHFMT_VERSION=3.10.0

FROM debian AS ghc-wasm-meta
RUN apt-get update \
    && apt-get install --yes \
    ca-certificates \
    curl \
    git \
    jq \
    make \
    unzip \
    xz-utils \
    zstd
RUN git clone https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta.git \
    && cd ghc-wasm-meta \
    && git checkout 92ff0eb8541eb0a6097922e3532c3fd44d2f7db4 \
    && FLAVOUR=9.12 exec ./setup.sh

FROM golang:1.24.0 AS golang

FROM ghcr.io/webassembly/wasi-sdk:sha-d94a133 AS wasi-sdk

FROM golang AS goreturns
ARG GORETURNS_REV
RUN GOOS=wasip1 GOARCH=wasm go install github.com/sqs/goreturns@${GORETURNS_REV}
RUN install -Dm644 bin/wasip1_wasm/goreturns /dist/goreturns-${GORETURNS_REV}.wasm

FROM wasi-sdk AS jq
RUN apt-get update && apt-get install --yes git
ARG JQ_VERSION
RUN git clone --branch=jq-${JQ_VERSION} --depth=1 --recurse-submodules https://github.com/jqlang/jq.git
RUN cd jq \
    && autoreconf --install \
    && CFLAGS=-D_WASI_EMULATED_SIGNAL LDFLAGS=-lwasi-emulated-signal \
    ./configure --host=wasm32 --target=wasm32-wasi --with-oniguruma=builtin \
    && make
RUN install -Dm644 jq/jq /dist/jq-${JQ_VERSION}.wasm

FROM ghc-wasm-meta AS shellcheck
RUN apt-get update && apt-get install --yes git
ARG SHELLCHECK_VERSION
RUN git clone --branch=v${SHELLCHECK_VERSION} --depth=1 --recurse-submodules https://github.com/koalaman/shellcheck.git
RUN cd shellcheck \
    && ./striptests \
    && . ~/.ghc-wasm/env \
    && wasm32-wasi-cabal configure -O2 \
    && wasm32-wasi-cabal build
RUN install -Dm644 $(find shellcheck/dist-newstyle -name shellcheck.wasm) /dist/shellcheck-${SHELLCHECK_VERSION}.wasm

FROM golang AS shfmt
ARG SHFMT_VERSION
RUN GOOS=wasip1 GOARCH=wasm go install mvdan.cc/sh/v3/cmd/shfmt@v${SHFMT_VERSION}
RUN install -Dm644 bin/wasip1_wasm/shfmt /dist/shfmt-${SHFMT_VERSION}.wasm

FROM ghcr.io/astral-sh/uv:0.6.4-bookworm-slim AS package-python
RUN apt-get update && apt-get install --yes gettext
COPY package-python/ package-python/

FROM package-python AS goreturns-python
COPY --from=goreturns dist/ src/
ARG GORETURNS_REV
RUN sh package-python/build.sh goreturns 0.0.0+${GORETURNS_REV} src/*.wasm /dist/

FROM package-python AS jq-python
COPY --from=jq dist/ src/
ARG JQ_VERSION
RUN sh package-python/build.sh jq ${JQ_VERSION} src/*.wasm /dist/

FROM package-python AS shellcheck-python
COPY --from=shellcheck dist/ src/
ARG SHELLCHECK_VERSION
RUN sh package-python/build.sh shellcheck ${SHELLCHECK_VERSION} src/*.wasm /dist/

FROM package-python AS shfmt-python
COPY --from=shfmt dist/ src/
ARG SHFMT_VERSION
RUN sh package-python/build.sh shfmt ${SHFMT_VERSION} src/*.wasm /dist/

FROM scratch

COPY --from=goreturns dist/ ./
COPY --from=jq dist/ ./
COPY --from=shellcheck dist/ ./
COPY --from=shfmt dist/ ./

COPY --from=goreturns-python dist/ ./
COPY --from=jq-python dist/ ./
COPY --from=shellcheck-python dist/ ./
COPY --from=shfmt-python dist/ ./
