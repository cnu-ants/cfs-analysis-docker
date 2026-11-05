# Infer official Linux binary is x86_64. Run on non-x86 hosts with binfmt/QEMU.
# Build this image separately from both cFS and IKOS.
FROM ubuntu:24.04

ARG INFER_VERSION=1.3.0
# Official SHA256 from https://github.com/facebook/infer/releases/tag/v1.3.0
ARG INFER_SHA256=02be62ba931cb43e2d42bbf7abf4bd9a410cf8464cce5453934e25c90a825850
ARG GCC_APT_VERSION=13.3.0-6ubuntu2~24.04.1

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    CC=/usr/bin/gcc-13 \
    CXX=/usr/bin/g++-13 \
    INFER_EXPECTED_VERSION=${INFER_VERSION} \
    PATH=/opt/infer/bin:${PATH}

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils git build-essential cmake make \
      python3 file pkg-config rsync jq \
      libgmp10 libsqlite3-0 libtinfo6 libncurses6 zlib1g \
      "gcc-13=${GCC_APT_VERSION}" "g++-13=${GCC_APT_VERSION}"; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    curl -fL --retry 3 --retry-delay 2 \
      "https://github.com/facebook/infer/releases/download/v${INFER_VERSION}/infer-linux-x86_64-v${INFER_VERSION}.tar.xz" \
      -o /tmp/infer.tar.xz; \
    echo "${INFER_SHA256}  /tmp/infer.tar.xz" | sha256sum -c -; \
    mkdir -p /opt; \
    tar -xJf /tmp/infer.tar.xz -C /opt; \
    ln -s "/opt/infer-linux-x86_64-v${INFER_VERSION}" /opt/infer; \
    test -x /opt/infer/bin/infer; \
    rm -f /tmp/infer.tar.xz

COPY scripts/prepare-analysis.sh /usr/local/bin/prepare-analysis.sh
RUN chmod +x /usr/local/bin/prepare-analysis.sh && \
    dpkg-query -W -f='${Package}=${Version}\n' | sort > /toolchain-package-manifest.txt

# The official binary bundles its C/C++ frontend (LLVM 21 in Infer v1.3.0).
RUN mkdir -p /cFS /analysis-work /results
WORKDIR /analysis-work
CMD ["sleep", "infinity"]
