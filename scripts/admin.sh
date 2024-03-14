#!/usr/bin/env bash
set -eou pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

help() {
    cat << EOT
Project admin scripts to either update the thin-edge.io version

USAGE
    $0 <COMMAND> [OPTIONS]

COMMANDS
    $0 update_version          Update the BB layer for thin-edge.io to the latest version
EOT
}

TEDGE_CHANNEL="dev"
TEDGE_PACKAGE="thinedge/tedge-$TEDGE_CHANNEL"

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
    tedge_version=$(get_latest_version "$TEDGE_PACKAGE" "arm64")
    echo "Latest thin-edge.io version: $tedge_version in ($TEDGE_PACKAGE)"

    # Generate file from a template
    output_file="$SCRIPT_DIR/../Formula/tedge.rb"
    TEMPLATE_FILE="$SCRIPT_DIR/tedge.rb.template"

    AARCH64_URL=$(get_tedge_url "$TEDGE_PACKAGE" "arm64" "$tedge_version")
    AARCH64_SHA256=$(get_tedge_sha256_checksum "$TEDGE_PACKAGE" "arm64" "$tedge_version")

    X86_64_URL=$(get_tedge_url "$TEDGE_PACKAGE" "amd64" "$tedge_version")
    X86_64_SHA256=$(get_tedge_sha256_checksum "$TEDGE_PACKAGE" "amd64" "$tedge_version")

    # Update template variables
    TEMPLATE=$(cat "$TEMPLATE_FILE")

    # Version
    TEMPLATE="${TEMPLATE//\{\{VERSION\}\}/$tedge_version}"

    # arm64
    TEMPLATE="${TEMPLATE//\{\{AARCH64_URL\}\}/$AARCH64_URL}"
    TEMPLATE="${TEMPLATE//\{\{AARCH64_SHA256\}\}/$AARCH64_SHA256}"

    # amd64
    TEMPLATE="${TEMPLATE//\{\{X86_64_URL\}\}/$X86_64_URL}"
    TEMPLATE="${TEMPLATE//\{\{X86_64_SHA256\}\}/$X86_64_SHA256}"

    echo "Writing file: $output_file" >&2
    echo '# Code generated: DO NOT EDIT' > "$output_file"
    echo "$TEMPLATE" | tee -a "$output_file"
}

REST_ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
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
        get_latest_version "$TEDGE_PACKAGE" "arm64"
        ;;
    *)
        echo "Unknown command: $COMMAND" >&2
        exit 1
        ;;
esac
