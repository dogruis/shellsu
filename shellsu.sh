#!/bin/bash
set -Eeuo pipefail

# Script Metadata
VERSION="1.0"
SCRIPT_NAME="$(basename "$0")"
LICENSE_TEXT="Apache-2.0 (see https://github.com/tianon/gosu)"

# Helper Functions
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME user-spec command [args...]
   eg: $SCRIPT_NAME tianon bash
       $SCRIPT_NAME nobody:root bash -c 'whoami && id'
       $SCRIPT_NAME 1000:1 id

$SCRIPT_NAME version: $VERSION
$SCRIPT_NAME license: $LICENSE_TEXT
EOF
}

version() {
    echo "$SCRIPT_NAME version: $VERSION"
    echo "Bash script on $(uname -s)/$(uname -m)"
}

error_exit() {
    echo "Error: $*" >&2
    exit 1
}

# Parse and validate user:group spec
parse_user_spec() {
    local spec="$1"
    USER="${spec%%:*}"
    GROUP="${spec#*:}"
    [[ "$USER" == "$GROUP" ]] && GROUP=""

    id "$USER" &>/dev/null || error_exit "User '$USER' does not exist."
    if [[ -n "$GROUP" ]]; then
        getent group "$GROUP" &>/dev/null || error_exit "Group '$GROUP' does not exist."
    fi
}

# Switch user and group, then execute the command
execute_as_user() {
    local user="$1"
    local group="$2"
    shift 2
    local cmd=("$@")

    # Resolve group ID if specified
    if [[ -n "$group" ]]; then
        GROUP_ID=$(getent group "$group" | cut -d: -f3)
        sg "$group" <<EOF
exec su -s /bin/bash -c "$(printf '%q ' "${cmd[@]}")" "$user"
EOF
    else
        exec su -s /bin/bash -c "$(printf '%q ' "${cmd[@]}")" "$user"
    fi
}

# Main Script Logic
main() {
    if [[ "$#" -lt 2 ]]; then
        usage
        exit 1
    fi

    case "$1" in
        --help | -h)
            usage
            exit 0
            ;;
        --version | -v)
            version
            exit 0
            ;;
    esac

    USER_SPEC="$1"
    shift
    COMMAND=("$@")

    parse_user_spec "$USER_SPEC"
    execute_as_user "$USER" "$GROUP" "${COMMAND[@]}"
}

main "$@"
