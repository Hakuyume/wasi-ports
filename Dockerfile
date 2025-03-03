FROM debian AS ghc-wasm-meta
RUN apt-get update \
    && apt-get install --yes \
    ca-certificates \
    curl \
    jq \
    make \
    unzip \
    xz-utils \
    zstd
RUN curl https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta/-/raw/master/bootstrap.sh | FLAVOUR=9.12 sh

FROM golang:1.24.0 AS go

FROM ghcr.io/webassembly/wasi-sdk:sha-d94a133 AS wasi-sdk

FROM go AS goreturns
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
    && wasm32-wasi-cabal build
RUN install -Dm644 $(find shellcheck/dist-newstyle -name shellcheck.wasm) /dist/shellcheck-${SHELLCHECK_VERSION}.wasm

FROM go AS shfmt
ARG SHFMT_VERSION
RUN GOOS=wasip1 GOARCH=wasm go install mvdan.cc/sh/v3/cmd/shfmt@v${SHFMT_VERSION}
RUN install -Dm644 bin/wasip1_wasm/shfmt /dist/shfmt-${SHFMT_VERSION}.wasm

FROM scratch
COPY --from=goreturns dist/ ./
COPY --from=jq dist/ ./
COPY --from=shellcheck dist/ ./
COPY --from=shfmt dist/ ./
