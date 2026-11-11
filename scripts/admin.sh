#!/usr/bin/env bash
set -eou pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

help() {
    cat << EOT
Project admin scripts to either update the thin-edge.io version

USAGE
    $0 <COMMAND> [OPTIONS]

COMMANDS
    $0 update_version          Update the homebrew formula for thin-edge.io to the latest version
    $0 pin_extras [FILE...]    Pin the extras/* resources to the latest commit which changed extras/,
                               update their checksums and bump the formula revision
                               if a checksum changed (default: all formulas)
EOT
}

get_latest_version() {
    repo="$1"
    package="$2"
    arch="$3"
    cloudsmith ls pkg "$repo" -q "tag:latest AND name:$package-macos-$arch AND format:raw" -F json -l 1 \
    | jq -r '.data[] | .version'
}

get_package_sha256_checksum() {
    repo="$1"
    package="$2"
    arch="$3"
    version="$4"
    cloudsmith ls pkg "$repo" -q "version:^$version$ AND name:$package-macos-$arch AND format:raw" -F json -l 1 \
    | jq -r '.data[] | .files[0].checksum_sha256'
}

get_package_url() {
    repo="$1"
    package="$2"
    arch="$3"
    version="$4"
    cloudsmith ls pkg "$repo" -q "version:^$version$ AND name:$package-macos-$arch AND format:raw" -F json -l 1 \
    | jq -r '.data[] | .files[0].cdn_url'
}

generate_formula() {
    repo="$1"
    package="$2"
    templates="$3"

     # thin-edge.io
    package_version=$(get_latest_version "$repo" "$package" "arm64")
    echo "Latest thin-edge.io version: $package_version in ($repo)" >&2

    # Get template variables

    AARCH64_URL=$(get_package_url "$repo" "$package" "arm64" "$package_version")
    AARCH64_SHA256=$(get_package_sha256_checksum "$repo" "$package" "arm64" "$package_version")

    X86_64_URL=$(get_package_url "$repo" "$package" "amd64" "$package_version")
    X86_64_SHA256=$(get_package_sha256_checksum "$repo" "$package" "amd64" "$package_version")

    export VERSION="$package_version"
    export AARCH64_URL
    export AARCH64_SHA256
    export X86_64_URL
    export X86_64_SHA256

    # Generate files from templates
    expand_templates "$SCRIPT_DIR/../Formula" "$templates"
    echo "$VERSION"
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

    # official release
    official_version=$(generate_formula "$REPO" "tedge" scripts/tedge.template.rb)

    # main branch release
    main_version=$(generate_formula "$REPO_MAIN" "tedge" scripts/tedge-main.template.rb)

    # tedge-p11-server - official release
    _tedge_p11_server_version=$(generate_formula "$REPO" "tedge-p11-server" scripts/tedge-p11-server.template.rb)
    # tedge-p11-server - main branch release
    _tedge_p11_server_main_version=$(generate_formula "$REPO_MAIN" "tedge-p11-server" scripts/tedge-p11-server-main.template.rb)

    # pin the extras/* resources of the non-generated formulas (bumping their revision if needed)
    pin_extras

    # return version (so it can be used by the caller)
    printf 'release=%s, main=%s\n' "$official_version" "$main_version"
}

get_extras_ref() {
    # Latest commit which changed the extras folder. Resources are downloaded from this
    # commit so that later changes to extras/ can't invalidate the checksums of published formulas
    git -C "$SCRIPT_DIR/.." log -1 --format=%H -- extras/
}

resolve_extras_ref() {
    EXTRAS_REF="${EXTRAS_REF:-$(get_extras_ref)}"
    if [ -z "$EXTRAS_REF" ]; then
        echo "Could not determine the commit of the extras folder. A full git history is required (e.g. fetch-depth: 0)" >&2
        exit 1
    fi

    # The commit must be available on GitHub, otherwise the formula can't be installed
    if [ "${ALLOW_UNPUSHED_EXTRAS:-0}" != 1 ] && [ -z "$(git -C "$SCRIPT_DIR/.." branch -r --contains "$EXTRAS_REF" --list origin/main)" ]; then
        echo "The extras commit ($EXTRAS_REF) is not on origin/main. Push it first, or set ALLOW_UNPUSHED_EXTRAS=1" >&2
        exit 1
    fi
    export EXTRAS_REF
}

pin_extras_file() {
    # Rewrite every extras/* resource url to point to an immutable commit (instead of a branch)
    # and set its sha256 to the checksum of the file at that commit.
    # The sha256 line must directly follow the url line.
    # shellcheck disable=SC2016
    REPO_DIR="$SCRIPT_DIR/.." perl -i -pe '
        BEGIN { use Digest::SHA qw(sha256_hex); $ref = $ENV{EXTRAS_REF}; $dir = $ENV{REPO_DIR}; }
        if (m{url\s+"https://raw\.githubusercontent\.com/thin-edge/homebrew-tedge/[^/"]+/(extras/[^"]+)"}) {
            my $path = $1;
            die "$ARGV:$.: url without a following sha256\n" if $pending;
            my $contents = `git -C "$dir" show "$ref:$path"`;
            die "$ARGV:$.: $path does not exist in commit $ref\n" if $?;
            $sha = sha256_hex($contents);
            s{(homebrew-tedge/)[^/"]+(/extras/)}{$1$ref$2};
            $pending = 1;
            next;
        }
        if ($pending) {
            s{sha256\s+"[^"]*"}{sha256 "$sha"} or die "$ARGV:$.: expected sha256 after extras url\n";
            $pending = 0;
        }
        if (eof) { die "$ARGV: url without a following sha256\n" if $pending; close ARGV; }
    ' "$1"
}

get_formula_version() {
    perl -ne 'if (/^\s*version\s+"([^"]+)"/) { print $1; exit }' "$1"
}

get_formula_revision() {
    perl -ne 'if (/^\s*revision\s+(\d+)\s*$/) { print $1; $found = 1; exit } END { print 0 unless $found }' "$1"
}

set_formula_revision() {
    # Set the formula revision (0 removes it). The revision is placed after the version
    # shellcheck disable=SC2016
    REVISION="$2" perl -i -ne '
        next if /^\s*revision\s+\d+\s*$/;
        print;
        if (!$done && /^(\s*)version\s+"/) { print "$1revision $ENV{REVISION}\n" if $ENV{REVISION} > 0; $done = 1 }
    ' "$1"
}

normalize_formula() {
    # Ignore the revision and the extras commit, so a new extras commit only counts as a change
    # if the content of a file used by the formula changed (which is reflected in its sha256)
    perl -pe 's{^\s*revision\s+\d+\s*\n}{}; s{(homebrew-tedge/)[^/"]+(/extras/)}{$1REF$2}' "$1"
}

update_revision() {
    # Set the revision of a new formula based on the existing (published) formula, so that users
    # get an upgrade when the packaging changes without a new upstream version:
    #  * new version     => no revision (Homebrew convention)
    #  * same version    => existing revision if nothing else changed, otherwise existing revision + 1
    CURRENT_FILE="$1"
    NEW_FILE="$2"
    if [ ! -f "$CURRENT_FILE" ]; then
        set_formula_revision "$NEW_FILE" 0
        return
    fi

    current_revision=$(get_formula_revision "$CURRENT_FILE")
    if [ "$(get_formula_version "$CURRENT_FILE")" != "$(get_formula_version "$NEW_FILE")" ]; then
        set_formula_revision "$NEW_FILE" 0
    elif cmp -s <(normalize_formula "$CURRENT_FILE") <(normalize_formula "$NEW_FILE"); then
        set_formula_revision "$NEW_FILE" "$current_revision"
    else
        echo "Formula changed without a new version, bumping revision: $(basename "$CURRENT_FILE") ($current_revision => $((current_revision + 1)))" >&2
        set_formula_revision "$NEW_FILE" "$((current_revision + 1))"
    fi
}

write_formula() {
    # Pin extras, set the revision and replace the existing formula
    NEW_FILE="$1"
    OUTPUT_FILE="$2"
    pin_extras_file "$NEW_FILE"
    update_revision "$OUTPUT_FILE" "$NEW_FILE"
    cat "$NEW_FILE" > "$OUTPUT_FILE"
    rm -f "$NEW_FILE"
}

pin_extras() {
    # Pin the extras/* resources of existing formulas (default: all formulas) and bump the revision if needed
    resolve_extras_ref
    if [ $# -eq 0 ]; then
        set -- "$SCRIPT_DIR"/../Formula/*.rb
    fi

    echo "Pinning extras resources to commit: $EXTRAS_REF" >&2
    for FILE in "$@"; do
        TMP_FILE=$(mktemp "${TMPDIR:-/tmp}/formula.XXXXXX")
        cp "$FILE" "$TMP_FILE"
        write_formula "$TMP_FILE" "$FILE"
    done
}

expand_templates() {
    OUTPUT_DIR="$1"
    shift
    resolve_extras_ref

    while [ $# -gt 0 ]; do
        TEMPLATE_FILE="$1"
        OUTPUT_FILE="$OUTPUT_DIR/$(basename "$TEMPLATE_FILE" | sed 's/.template//g')"
        shift

        echo "Generating file from template: $TEMPLATE_FILE" >&2

        # shellcheck disable=SC2016
        CONTENTS=$(envsubst '$VERSION,$AARCH64_URL,$AARCH64_SHA256,$X86_64_URL,$X86_64_SHA256,$DEVELOP_VERSION,$DEVELOP_AARCH64_URL,$DEVELOP_AARCH64_SHA256,$DEVELOP_X86_64_URL,$DEVELOP_X86_64_SHA256' < "$TEMPLATE_FILE")

        echo "Writing file: $OUTPUT_FILE" >&2
        TMP_FILE=$(mktemp "${TMPDIR:-/tmp}/formula.XXXXXX")
        echo '# Code generated: DO NOT EDIT' > "$TMP_FILE"
        echo "$CONTENTS" >> "$TMP_FILE"
        write_formula "$TMP_FILE" "$OUTPUT_FILE"
    done
}

REPO="${REPO:-thinedge/tedge-release}"
REPO_MAIN="${REPO_MAIN:-thinedge/tedge-main}"

REST_ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --repo)
            REPO="$2"
            shift
            ;;
        --repo-main)
            REPO_MAIN="$2"
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
        get_latest_version "$REPO" "tedge" "arm64"
        ;;
    pin_extras)
        shift
        pin_extras "$@"
        ;;
    *)
        echo "Unknown command: $COMMAND" >&2
        exit 1
        ;;
esac
