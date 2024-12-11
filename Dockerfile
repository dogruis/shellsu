# Use a minimal Linux distribution with bash
FROM debian:bookworm-slim

# Install necessary dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        arch-test \
        file \
        bash \
    ; \
    rm -rf /var/lib/apt/lists/*

# Set environment variable for build flags
ENV BUILD_FLAGS="-v"

# Prepare the `bashsu` build and test script
RUN set -eux; \
    { \
        echo '#!/usr/bin/env bash'; \
        echo 'set -Eeuo pipefail -x'; \
        echo 'ARCH="${ARCH:-$(uname -m)}"'; \
        echo 'cp /usr/local/bin/bashsu /usr/local/bin/bashsu-$ARCH'; \
        echo 'file "/usr/local/bin/bashsu-$ARCH"'; \
        echo 'if arch-test "$ARCH"; then'; \
        echo '  try() { for (( i = 0; i < 30; i++ )); do if timeout 1s "$@"; then return 0; fi; done; return 1; }'; \
        echo '  try "/usr/local/bin/bashsu-$ARCH" --version'; \
        echo '  try "/usr/local/bin/bashsu-$ARCH" nobody id'; \
        echo '  try "/usr/local/bin/bashsu-$ARCH" nobody ls -l /proc/self/fd'; \
        echo 'fi'; \
    } > /usr/local/bin/bashsu-build-and-test.sh; \
    chmod +x /usr/local/bin/bashsu-build-and-test.sh

# Disable CGO (not relevant for Bash, but keeping for alignment with original pattern)
ENV CGO_ENABLED 0

# Copy `bashsu` script into the container
WORKDIR /usr/local/bin
COPY bashsu /usr/local/bin/bashsu
RUN chmod +x /usr/local/bin/bashsu

# Test `bashsu` for various architectures
RUN ARCH=amd64    bashsu-build-and-test.sh
RUN ARCH=i386     bashsu-build-and-test.sh
RUN ARCH=armel    bashsu-build-and-test.sh
RUN ARCH=armhf    bashsu-build-and-test.sh
RUN ARCH=arm64    bashsu-build-and-test.sh
RUN ARCH=mips64el bashsu-build-and-test.sh
RUN ARCH=ppc64el  bashsu-build-and-test.sh
RUN ARCH=riscv64  bashsu-build-and-test.sh
RUN ARCH=s390x    bashsu-build-and-test.sh

# Final verification step
RUN set -eux; ls -lAFh /usr/local/bin/bashsu-*; file /usr/local/bin/bashsu-*
