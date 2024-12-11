#!/bin/bash
set -e

# Navigate to the directory containing this script
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

set -x

# Build the Docker image
docker build --pull -t shellsu .

# Clean up any pre-existing artifacts
rm -f shellsu* SHA256SUMS*

# Extract the `shellsu` binaries from the built image
docker run --rm shellsu sh -c 'cd /go/bin && tar -c shellsu*' | tar -xv

# Generate SHA256 checksums for the extracted files
sha256sum shellsu* | tee SHA256SUMS

# Inspect the extracted files
file shellsu*
ls -lFh shellsu* SHA256SUMS*

# Run the built binary to verify functionality
"./shellsu-$(dpkg --print-architecture)" --help
