#!/usr/bin/env bash
set -eou pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

help() {
    cat << EOT
Project admin scripts to either update the thin-edge.io version

USAGE
    $0 <COMMAND> [OPTIONS]

COMMANDS
    $0 update_version          Update the homewbrew formula for thin-edge.io to the latest version
EOT
}

get_latest_version() {
    repo="$1"
    arch="$2"
    cloudsmith ls pkg "$repo" -q "tag:latest AND name:tedge-macos-$arch AND format:raw" -F json -l 1 \
    | jq -r '.data[] | .version'
}

get_tedge_sha256_checksum() {
    repo="$1"
    arch="$2"
    version="$3"
    cloudsmith ls pkg "$repo" -q "version:^$version$ AND name:tedge-macos-$arch AND format:raw" -F json -l 1 \
    | jq -r '.data[] | .files[0].checksum_sha256'
}

get_tedge_url() {
    repo="$1"
    arch="$2"
    version="$3"
    cloudsmith ls pkg "$repo" -q "version:^$version$ AND name:tedge-macos-$arch AND format:raw" -F json -l 1 \
    | jq -r '.data[] | .files[0].cdn_url'
}


update_version() {
    # Install tooling if missing
    if ! [ -x "$(command -v cloudsmith)" ]; then
        echo 'Install cloudsmith cli' >&2
        if command -v pip3 &>/dev/null; then
            pip3 install --upgrade cloudsmith-cli
        elif command -v pip &>/dev/null; then
            pip install --upgrade cloudsmith-cli
        else
            echo "Could not install cloudsmith cli. Reason: pip3/pip is not installed"
            exit 2
        fi
    fi

    echo "Updating version" >&2
    # thin-edge.io
    package_version=$(get_latest_version "$REPO" "arm64")
    echo "Latest thin-edge.io version: $package_version in ($REPO)"

    # Get template variables

    AARCH64_URL=$(get_tedge_url "$REPO" "arm64" "$package_version")
    AARCH64_SHA256=$(get_tedge_sha256_checksum "$REPO" "arm64" "$package_version")

    X86_64_URL=$(get_tedge_url "$REPO" "amd64" "$package_version")
    X86_64_SHA256=$(get_tedge_sha256_checksum "$REPO" "amd64" "$package_version")

    export VERSION="$package_version"
    export AARCH64_URL
    export AARCH64_SHA256
    export X86_64_URL
    export X86_64_SHA256

    # Generate files from templates
    expand_templates "$SCRIPT_DIR/../Formula" scripts/*.template.*

    # return version (so it can be used by the caller)
    echo "$package_version"
}

expand_templates() {
    OUTPUT_DIR="$1"
    shift

    while [ $# -gt 0 ]; do
        TEMPLATE_FILE="$1"
        OUTPUT_FILE="$OUTPUT_DIR/$(basename "$TEMPLATE_FILE" | sed 's/.template//g')"
        shift

        echo "Generating file from template: $TEMPLATE_FILE" >&2

        # shellcheck disable=SC2016
        CONTENTS=$(envsubst '$VERSION,$AARCH64_URL,$AARCH64_SHA256,$X86_64_URL,$X86_64_SHA256' < "$TEMPLATE_FILE")

        echo "Writing file: $OUTPUT_FILE" >&2
        echo '# Code generated: DO NOT EDIT' > "$OUTPUT_FILE"
        echo "$CONTENTS" | tee -a "$OUTPUT_FILE"
    done
}

REPO="thinedge/tedge-main"

REST_ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --repo)
            REPO="$2"
            shift
            ;;
        --help|-h)
            help
            exit 0
            ;;
        --*|-*)
            echo "Unknown option: $1" >&2
            help
            exit 1
            ;;
        *)
            REST_ARGS+=("$1")
            ;;
    esac
    shift
done

if [ ${#REST_ARGS[@]} -gt 0 ]; then
    set -- "${REST_ARGS[@]}"
fi

if [ $# -eq 0 ]; then
    echo "Missing required argument" >&2
    help
    exit 1
fi

COMMAND="$1"
case "$COMMAND" in
    update_version)
        update_version
        ;;
    latest_version)
        get_latest_version "$REPO" "arm64"
        ;;
    *)
        echo "Unknown command: $COMMAND" >&2
        exit 1
        ;;
esac
