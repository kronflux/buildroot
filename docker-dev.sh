#!/bin/bash
set -euo pipefail

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Determine container engine
if [[ -n "${CONTAINER_ENGINE:-}" ]]; then
    # Use value from env if set
    ENGINE="$CONTAINER_ENGINE"
    if ! command_exists "$ENGINE"; then
        echo "ERROR: Specified CONTAINER_ENGINE '$ENGINE' is not installed." >&2
        exit 1
    fi
else
    # Auto-detect: prefer podman
    if command_exists "podman"; then
        ENGINE="podman"
    elif command_exists "docker"; then
        ENGINE="docker"
    else
        echo "ERROR: Neither podman nor docker is available." >&2
        exit 1
    fi
fi

# Set user namespace argument only for podman
USERNS_ARG=""
if [[ "$ENGINE" == "podman" ]]; then
    USERNS_ARG="--userns=keep-id"
fi

# Require at least one argument
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 [build|<command>]" >&2
    exit 1
fi

CMD="$1"
shift

# Use -it only if TTY is available (e.g., not in CI)
if [ -t 1 ]; then
  INTERACTIVE="-it"
else
  INTERACTIVE=""
fi

if [[ "$CMD" == "build" ]]; then
    echo "Building image with $ENGINE..."
    "$ENGINE" build \
        --build-arg UID=$(id -u) \
        --build-arg GID=$(id -g) \
        -t aaproxybr .
else
    echo "Running container with $ENGINE: aaproxybr $CMD $*"

    # Detect local aa-proxy-rs source directory.
    # Check AA_PROXY_RS_DIR env var first, then fall back to sibling directory.
    if [[ -z "${AA_PROXY_RS_DIR:-}" ]]; then
        _CANDIDATE="$(cd "$(dirname "$0")/.." && pwd)/aa-proxy-rs"
        if [[ -d "$_CANDIDATE" ]]; then
            AA_PROXY_RS_DIR="$_CANDIDATE"
        fi
    fi

    LOCAL_MOUNTS=""
    if [[ -n "${AA_PROXY_RS_DIR:-}" ]]; then
        if [[ -d "$AA_PROXY_RS_DIR" ]]; then
            echo "Using local aa-proxy-rs source: $AA_PROXY_RS_DIR"
            LOCAL_MOUNTS="-v ${AA_PROXY_RS_DIR}:/app/aa-proxy-rs:z"
        else
            echo "WARNING: AA_PROXY_RS_DIR='$AA_PROXY_RS_DIR' does not exist, ignoring." >&2
        fi
    fi

    "$ENGINE" run $USERNS_ARG $INTERACTIVE --rm \
        -v "$(pwd):/app":z \
        $LOCAL_MOUNTS \
        aaproxybr \
        "$CMD" "$@"
fi
