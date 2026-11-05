# Unmodified NASA cFS build / runtime image, multi-platform: amd64 or arm64.
# The compiler versions below are pinned as exact Ubuntu binary-package revisions.
FROM ubuntu:24.04

ARG CFS_REF=v7.0.2-rc1-oss
ARG GCC_APT_VERSION=13.3.0-6ubuntu2~24.04.1
ARG LLVM_APT_VERSION=1:18.1.3-1ubuntu1

ENV TZ=Etc/UTC \
    CC=/usr/bin/gcc-13 \
    CXX=/usr/bin/g++-13 \
    TOOLCHAIN_GCC_APT_VERSION=${GCC_APT_VERSION} \
    TOOLCHAIN_LLVM_APT_VERSION=${LLVM_APT_VERSION}

# Exact GCC/Clang/LLVM package revisions are pinned below. Do not set a
# global APT::Snapshot here: it caused an empty package candidate set when
# building the arm64 Ubuntu 24.04 image (all packages became unavailable).
# Other APT dependencies are not frozen; record their actual versions.
RUN set -eux; \
    apt-get update; \
    apt-cache policy gcc-13 clang-18; \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends \
      ca-certificates git build-essential libc6-dev cmake make python3 jq file pkg-config lcov binutils \
      "gcc-13=${GCC_APT_VERSION}" \
      "g++-13=${GCC_APT_VERSION}" \
      "clang-18=${LLVM_APT_VERSION}" \
      "llvm-18=${LLVM_APT_VERSION}" \
      "llvm-18-tools=${LLVM_APT_VERSION}"; \
    rm -rf /var/lib/apt/lists/*

COPY scripts/cfs-smoke-test.sh scripts/cfs-unit-tests.sh scripts/verify-toolchain.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh && \
    /usr/local/bin/verify-toolchain.sh && \
    dpkg-query -W -f='${Package}=${Version}\n' | sort > /toolchain-package-manifest.txt

# cFS bundle and every Git submodule come from the chosen tag, unmodified.
RUN git clone --branch "$CFS_REF" --recurse-submodules \
      https://github.com/nasa/cFS.git /cFS
WORKDIR /cFS
RUN git rev-parse HEAD > /cfs-bundle-commit.txt && \
    git submodule status --recursive > /cfs-submodules.txt

# CC/CXX force the intended GCC 13 compiler for cFS's native_std target.
RUN make native_std.prep && \
    make native_std.install && \
    test -x build-native_std/exe/cpu1/core-cpu1 && \
    readelf -h build-native_std/exe/cpu1/core-cpu1 | grep Machine && \
    find build-native_std -name compile_commands.json -print \
      > /cfs-compilation-databases.txt && \
    test -s /cfs-compilation-databases.txt

RUN { \
      date -u '+Built UTC: %Y-%m-%dT%H:%M:%SZ'; \
      printf 'APT snapshot: disabled (toolchain package revisions pinned)\n'; \
      gcc-13 --version | head -n 1; \
      clang-18 --version | head -n 1; \
      opt-18 --version | head -n 1; \
      cat /cfs-bundle-commit.txt; \
    } > /cfs-build-metadata.txt

WORKDIR /cFS/build-native_std/exe/cpu1
CMD ["./core-cpu1"]
