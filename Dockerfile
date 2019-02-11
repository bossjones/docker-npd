FROM debian:stretch-slim

ARG DEBIAN_FRONTEND=noninteractive

COPY clean-apt /usr/bin
COPY clean-install /usr/bin

ENV RBSPY_RELEASE="https://github.com/rbspy/rbspy/releases/download/v0.3.3/rbspy-v0.3.3-x86_64-unknown-linux-musl.tar.gz" \
    RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR="1.2" \
    GOSU_VERSION=1.10 \
    JEMALLOC_VERSION=4.5.0

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


RUN test -h /etc/localtime && rm -f /etc/localtime && cp /usr/share/zoneinfo/UTC /etc/localtime || true


# FIXME
ADD ./bin/node-problem-detector /node-problem-detector
ADD ./bin/log-counter /home/kubernetes/bin/log-counter
ADD config /config
ENTRYPOINT ["/node-problem-detector", "--system-log-monitors=/config/kernel-monitor.json"]


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
