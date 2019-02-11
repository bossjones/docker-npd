FROM debian:stretch-slim

ARG DEBIAN_FRONTEND=noninteractive

COPY clean-apt /usr/bin
COPY clean-install /usr/bin

ENV GOSU_VERSION=1.10

# gcc for cgo
RUN apt-get update && apt-get install -y --no-install-recommends \
		g++ \
		gcc \
		libc6-dev \
		make \
		pkg-config \
	&& rm -rf /var/lib/apt/lists/*

ENV GOLANG_VERSION 1.11.5

RUN set -eux; \
	\
# this "case" statement is generated via "update.sh"
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		amd64) goRelArch='linux-amd64'; goRelSha256='ff54aafedff961eb94792487e827515da683d61a5f9482f668008832631e5d25' ;; \
		armhf) goRelArch='linux-armv6l'; goRelSha256='b26b53c94923f78955236386fee0725ef4e76b6cb47e0df0ed0c0c4724e7b198' ;; \
		arm64) goRelArch='linux-arm64'; goRelSha256='6ee9a5714444182a236d3cc4636e74cfc5e24a1bacf0463ac71dcf0e7d4288ed' ;; \
		i386) goRelArch='linux-386'; goRelSha256='acd8e05f8d3eed406e09bb58eab89de3f0a139d4aef15f74adeed2d2c24cb440' ;; \
		ppc64el) goRelArch='linux-ppc64le'; goRelSha256='66e83152c68cb35d41f21453377d6a811585c9e01a6ac54b19f7a6e2cbb3d1f5' ;; \
		s390x) goRelArch='linux-s390x'; goRelSha256='56209e5498c64a8338cd6f0fe0c2e2cbf6857c0acdb10c774894f0cc0d19f413' ;; \
		*) goRelArch='src'; goRelSha256='bc1ef02bb1668835db1390a2e478dcbccb5dd16911691af9d75184bbe5aa943e'; \
			echo >&2; echo >&2 "warning: current architecture ($dpkgArch) does not have a corresponding Go binary release; will be building from source"; echo >&2 ;; \
	esac; \
	\
	url="https://golang.org/dl/go${GOLANG_VERSION}.${goRelArch}.tar.gz"; \
	wget -O go.tgz "$url"; \
	echo "${goRelSha256} *go.tgz" | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	if [ "$goRelArch" = 'src' ]; then \
		echo >&2; \
		echo >&2 'error: UNIMPLEMENTED'; \
		echo >&2 'TODO install golang-any from jessie-backports for GOROOT_BOOTSTRAP (and uninstall after build)'; \
		echo >&2; \
		exit 1; \
	fi; \
	\
	export PATH="/usr/local/go/bin:$PATH"; \
	go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# SOURCE: https://docs.fluentd.org/v1.0/articles/before-install
# net.core.somaxconn = 1024
# net.core.netdev_max_backlog = 5000
# net.core.rmem_max = 16777216
# net.core.wmem_max = 16777216
# net.ipv4.tcp_wmem = 4096 12582912 16777216
# net.ipv4.tcp_rmem = 4096 12582912 16777216
# net.ipv4.tcp_max_syn_backlog = 8096
# net.ipv4.tcp_slow_start_after_idle = 0
# net.ipv4.tcp_tw_reuse = 1
# net.ipv4.ip_local_port_range = 10240 65535

# && curl -L https://toolbelt.treasuredata.com/sh/install-debian-stretch-td-agent3.sh | sh && \

# 1. Install & configure dependencies.
# 2. Install fluentd via ruby.
# 3. Remove build dependencies.
# 4. Cleanup leftover caches & files.
RUN BUILD_DEPS="libsystemd0 bash" \
    && clean-install $BUILD_DEPS \
                     ca-certificates \
                     sudo \
                     vim \
                     tar \
                     wget \
    && update-ca-certificates \
    && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && clean-apt \
    # Ensure fluent has enough file descriptors
    && ulimit -n 65536

RUN curl -L 'https://github.com/kubernetes/node-problem-detector/archive/v0.6.2.tar.gz' > /usr/local/src/node-problem-detector.tar.gz

RUN test -h /etc/localtime && rm -f /etc/localtime && cp /usr/share/zoneinfo/UTC /etc/localtime || true


# FIXME: ENABLE THIS
# ADD ./bin/node-problem-detector /node-problem-detector
# ADD ./bin/log-counter /home/kubernetes/bin/log-counter
# ADD config /config
# ENTRYPOINT ["/node-problem-detector", "--system-log-monitors=/config/kernel-monitor.json"]


ARG BUILD_DATE
ARG VCS_REF
ARG BUILD_VERSION

# Labels.
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.name="bossjones/node-problem-detector"
LABEL org.label-schema.vcs-ref=$VCS_REF
LABEL org.label-schema.vendor="TonyDark Industries"
LABEL org.label-schema.version=$BUILD_VERSION
LABEL maintainer="jarvis@theblacktonystark.com"
