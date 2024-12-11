#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    echo "usage: $0 [--alpine | --debian] shellsu"
    echo "   eg: $0 --debian ./shellsu"
    echo "       $0 --alpine ./shellsu"
}

df='Dockerfile.test-alpine'
case "${1:-}" in
    --alpine | --debian)
        df="Dockerfile.test-${1#--}"
        shift
        ;;
esac

shellsu="${1:-}"
shift || { echo "Error: Missing shellsu script argument." >&2; usage >&2; exit 1; }
[ -f "$shellsu" ] || { echo "Error: shellsu script '$shellsu' does not exist." >&2; usage >&2; exit 1; }

echo "Verifying Dockerfile: $df"
[ -f "$df" ] || { echo "Error: Dockerfile '$df' does not exist." >&2; exit 1; }

dir="$(mktemp -d -t shellsu-test-XXXXXXXXXX)"
base="$(basename "$dir")"
img="shellsu-test:$base"
trap "rm -rf '$dir'" EXIT

echo "Using temporary directory: $dir"
echo "Docker image will be tagged as: $img"
echo "Copying shellsu script '$shellsu' to $dir/shellsu"
echo "Copying Dockerfile '$df' to $dir/Dockerfile"

cp -T "$df" "$dir/Dockerfile" || { echo "Error: Failed to copy Dockerfile to '$dir/Dockerfile'." >&2; exit 1; }
cp -T "$shellsu" "$dir/shellsu" || { echo "Error: Failed to copy '$shellsu' to '$dir/shellsu'." >&2; exit 1; }

echo "Building Docker image '$img' using Dockerfile '$df'..."
docker build -t "$img" "$dir" || { echo "Error: Failed to build Docker image '$img'." >&2; exit 1; }
rm -rf "$dir"  # Clean up the temporary directory
trap - EXIT

trap "docker rm -f '$base' > /dev/null; docker rmi -f '$img' > /dev/null" EXIT

echo "Testing shellsu script with --help and --version..."
docker run --rm "$img" /usr/local/bin/shellsu --help || { echo "Error: Failed to run '/usr/local/bin/shellsu --help' inside the container." >&2; exit 1; }
docker run --rm "$img" /usr/local/bin/shellsu --version || { echo "Error: Failed to run '/usr/local/bin/shellsu --version' inside the container." >&2; exit 1; }

echo "Running the shellsu script with sleep for basic functionality check..."
docker run -d --init=false --name "$base" "$img" /usr/local/bin/shellsu root sleep 1000 || { echo "Error: Failed to start container with '/usr/local/bin/shellsu root sleep 1000'." >&2; exit 1; }

sleep 1  # Allow some time for the script to run
echo "Checking process count..."
process_count=$(docker top "$base" | wc -l)
if [ "$process_count" -ne 2 ]; then
    echo "Error: Unexpected number of processes in container (expected 2, found $process_count)." >&2
    exit 1
fi

echo "Test passed successfully!"
