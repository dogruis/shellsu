# Use a minimal Linux distribution with bash
FROM debian:bookworm-slim

# Install necessary dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        file \
        bash \
        login \
    ; \
    rm -rf /var/lib/apt/lists/*

# Set environment variable for build flags
ENV BUILD_FLAGS="-v"

# Copy `shellsu` script into the container
WORKDIR /usr/local/bin
COPY shellsu.sh /usr/local/bin/shellsu
RUN chmod +x /usr/local/bin/shellsu

# Test `shellsu` to verify functionality
RUN set -eux; \
    shellsu --help; \
    shellsu --version

# Final verification step (list files and check permissions)
RUN set -eux; ls -lAFh /usr/local/bin/shellsu; file /usr/local/bin/shellsu
