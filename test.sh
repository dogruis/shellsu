#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    echo "usage: $0 [--platform] shellsu-binary"
    echo "   eg: $0 ./shellsu-amd64"
    echo "       $0 --debian ./shellsu-amd64"
}

df='Dockerfile.test-alpine'
case "${1:-}" in
    --alpine | --debian)
        df="Dockerfile.test-${1#--}"
        shift
        ;;
esac

shellsu="${1:-}"
shift || { usage >&2; exit 1; }
[ -f "$shellsu" ] || { usage >&2; exit 1; }

trap '{ set +x; echo; echo FAILED; echo; } >&2' ERR

set -x

dir="$(mktemp -d -t shellsu-test-XXXXXXXXXX)"
base="$(basename "$dir")"
img="shellsu-test:$base"
trap "rm -rf '$dir'" EXIT
cp -T "$df" "$dir/Dockerfile"
cp -T "$shellsu" "$dir/shellsu"
docker build -t "$img" "$dir"
rm -rf "$dir"
trap - EXIT

trap "docker rm -f '$base' > /dev/null; docker rmi -f '$img' > /dev/null" EXIT

# using explicit "--init=false" in case dockerd is running with "--init" (because that will skew our process numbers)
docker run -d --init=false --name "$base" "$img" shellsu root sleep 1000
sleep 1 # give it plenty of time to get through "shellsu" and into the "sleep"
[ "$(docker top "$base" | wc -l)" = 2 ]
# "docker top" should have only two lines
# -- ps headers and a single line for the single process running in the container
