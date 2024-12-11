#!/usr/bin/env bash
set -e

# Navigate to the directory containing this script
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

set -x

# Build the Docker image
docker build --no-cache --pull -t shellsu .

rm -f shellsu* SHA256SUMS*

docker run --rm --entrypoint cat shellsu /usr/local/bin/shellsu > shellsu

chmod +x shellsu

sha256sum shellsu | tee SHA256SUMS

file shellsu
ls -lFh shellsu SHA256SUMS

"./shellsu" --help
