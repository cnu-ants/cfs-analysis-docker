# IKOS image (independent of cFS and Infer); Ubuntu 24.04 arm64/amd64.
# The Ubuntu Noble binary package installs the analyzer and Clang 14.
FROM ubuntu:24.04

ARG IKOS_APT_VERSION=3.2-3
ARG LLVM14_APT_VERSION=1:14.0.6-19build4
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    CC=/usr/bin/clang-14 \
    CXX=/usr/bin/clang++-14 \
    IKOS_EXPECTED_APT_VERSION=${IKOS_APT_VERSION} \
    LLVM14_EXPECTED_APT_VERSION=${LLVM14_APT_VERSION}

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates git build-essential cmake make python3 \
      python3-pip pkg-config file binutils rsync jq \
      "ikos=${IKOS_APT_VERSION}" \
      "clang-14=${LLVM14_APT_VERSION}" \
      "llvm-14=${LLVM14_APT_VERSION}" \
      "llvm-14-tools=${LLVM14_APT_VERSION}" \
      "llvm-14-dev=${LLVM14_APT_VERSION}"; \
    rm -rf /var/lib/apt/lists/*

COPY scripts/prepare-analysis.sh /usr/local/bin/prepare-analysis.sh
RUN chmod +x /usr/local/bin/prepare-analysis.sh && \
    test "$(dpkg-query -W -f='${Version}' ikos)" = "$IKOS_EXPECTED_APT_VERSION" && \
    test "$(dpkg-query -W -f='${Version}' clang-14)" = "$LLVM14_EXPECTED_APT_VERSION" && \
    test "$(dpkg-query -W -f='${Version}' llvm-14)" = "$LLVM14_EXPECTED_APT_VERSION" && \
    command -v ikos && command -v ikos-scan && \
    dpkg-query -W -f='${Package}=${Version}\n' | sort > /toolchain-package-manifest.txt

# /cFS is mounted read-only; copy source to /analysis-work/cFS before recompiling.
RUN mkdir -p /cFS /analysis-work /results
WORKDIR /analysis-work
CMD ["sleep", "infinity"]
