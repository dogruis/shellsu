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

# Prepare the `shellsu` build and test script
RUN set -eux; \
    { \
        echo '#!/usr/bin/env bash'; \
        echo 'set -Eeuo pipefail -x'; \
        echo 'ARCH="${ARCH:-$(uname -m)}"'; \
        echo 'cp /usr/local/bin/shellsu /usr/local/bin/shellsu-$ARCH'; \
        echo 'file "/usr/local/bin/shellsu-$ARCH"'; \
        echo 'if arch-test "$ARCH"; then'; \
        echo '  try() { for (( i = 0; i < 30; i++ )); do if timeout 1s "$@"; then return 0; fi; done; return 1; }'; \
        echo '  try "/usr/local/bin/shellsu-$ARCH" --version'; \
        echo '  try "/usr/local/bin/shellsu-$ARCH" nobody id'; \
        echo '  try "/usr/local/bin/shellsu-$ARCH" nobody ls -l /proc/self/fd'; \
        echo 'fi'; \
    } > /usr/local/bin/shellsu-build-and-test.sh; \
    chmod +x /usr/local/bin/shellsu-build-and-test.sh

# Disable CGO (not relevant for Bash, but keeping for alignment with original pattern)
ENV CGO_ENABLED 0

# Copy `shellsu` script into the container
WORKDIR /usr/local/bin
COPY shellsu /usr/local/bin/shellsu
RUN chmod +x /usr/local/bin/shellsu

# Test `shellsu` for various architectures
RUN ARCH=amd64    shellsu-build-and-test.sh
RUN ARCH=i386     shellsu-build-and-test.sh
RUN ARCH=armel    shellsu-build-and-test.sh
RUN ARCH=armhf    shellsu-build-and-test.sh
RUN ARCH=arm64    shellsu-build-and-test.sh
RUN ARCH=mips64el shellsu-build-and-test.sh
RUN ARCH=ppc64el  shellsu-build-and-test.sh
RUN ARCH=riscv64  shellsu-build-and-test.sh
RUN ARCH=s390x    shellsu-build-and-test.sh

# Final verification step
RUN set -eux; ls -lAFh /usr/local/bin/shellsu-*; file /usr/local/bin/shellsu-*
