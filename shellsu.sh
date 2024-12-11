#!/bin/bash
set -Eeuo pipefail

# Script Metadata
VERSION="1.0"
SCRIPT_NAME="$(basename "$0")"
LICENSE_TEXT="MIT (see https://github.com/dogruis/shellsu)"

# Helper Functions
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME user-spec command [args...]
   eg: $SCRIPT_NAME dogruis bash
       $SCRIPT_NAME nobody:root bash -c 'whoami && id'
       $SCRIPT_NAME 1000:1 id

Options:
  --help, -h           Show this help message
  --version, -v        Show version information

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

# Check if the script is insecure (no setuid/setgid bit)
check_insecure() {
    if [[ "${SHELLSU_INSECURE_FLAG:-}" != "I've seen things you people wouldn't believe. Attack ships on fire off the shoulder of Orion. I watched C-beams glitter in the dark near the Tannhäuser Gate. All those moments will be lost in time, like tears in rain. Time to die." ]]; then
        # Check if the script has setuid or setgid permissions
        if [[ -u "$0" ]]; then
            error_exit "$0 appears to be installed with the 'setuid' bit set, which is extremely insecure and unsupported! Use 'sudo' or 'su' instead."
        elif [[ -g "$0" ]]; then
            error_exit "$0 appears to be installed with the 'setgid' bit set, which is not great and unsupported! Use 'sudo' or 'su' instead."
        fi
    fi
}

# Function to set up the user and group context
setup_user() {
    local user_spec="$1"
    local user_name
    local user_uid
    local user_gid
    local user_home
    local group_ids=()

    # Parse user_spec (format: user[:group])
    IFS=':' read -r user group <<< "$user_spec"

    # Resolve user info from /etc/passwd
    if [[ "$user" =~ ^[0-9]+$ ]]; then
        # If user is numeric UID, resolve it
        user_entry=$(getent passwd | awk -F: -v uid="$user" '$3 == uid {print}')
    else
        # If user is a name, fetch entry
        user_entry=$(getent passwd "$user")
    fi

    if [[ -z "$user_entry" ]]; then
        error_exit "User '$user' not found"
    fi

    user_name=$(echo "$user_entry" | cut -d: -f1)
    user_uid=$(echo "$user_entry" | cut -d: -f3)
    user_gid=$(echo "$user_entry" | cut -d: -f4)
    user_home=$(echo "$user_entry" | cut -d: -f6)

    # Resolve group info if a specific group is provided
    if [[ -n "$group" ]]; then
        if [[ "$group" =~ ^[0-9]+$ ]]; then
            group_entry=$(getent group | awk -F: -v gid="$group" '$3 == gid {print}')
        else
            group_entry=$(getent group "$group")
        fi
        if [[ -z "$group_entry" ]]; then
            error_exit "Group '$group' not found"
        fi
        user_gid=$(echo "$group_entry" | cut -d: -f3)
    fi

    # Resolve supplementary groups
    group_ids=($(id -G "$user_name"))

    # Set user and group IDs
    if ! setpriv --reuid="$user_uid" --regid="$user_gid" --init-groups true; then
        error_exit "Failed to switch to user '$user_name' and group '$group'"
    fi

    # Set HOME environment variable
    export HOME="$user_home"
}

# Function to switch to user and group and execute command
run_cmd_as_user() {
    spec="$1"
    shift
    cmd=("$@")

    # Setup the user environment
    setup_user "$spec"

    # Execute the command as the specified user and group
    execve "${cmd[@]}"
}

# Main function to execute the script logic
main() {
    echo "Entering main function"  # Debug: Entry point
    check_insecure
    echo "Finished check_insecure" # Debug: After check_insecure
    # Handle the command-line arguments
    echo "Number of arguments: $#"
    echo "Arguments: $@"

    echo "First argument: $1"
    if [[ $# -lt 1 ]]; then # Only one argument (script name)
        echo "Number of arguments is less than 1: $#" # Debug: Argument count
        usage >&2
        exit 1
    elif [[ $# -ge 1 ]]; then
        echo "Number of arguments is greater than or equal to 1: $#" # Debug: Argument count
        case "$1" in
            "--help" | "-h" | "-?")
                echo "Help option selected" # Debug: Help option
                usage
                exit 0
                ;;
            "--version" | "-v")
                echo "Version option selected" # Debug: Version option
                version
                exit 0
                ;;
        esac
    fi

    unset HOME

    echo "Calling run_cmd_as_user with arguments: $@" # Debug: Before calling run_cmd_as_user
    # Call the user switching and command execution function
    run_cmd_as_user "$@"
    echo "Returned from run_cmd_as_user" # Debug: After run_cmd_as_user
}

# Call the main function
main "$@"
