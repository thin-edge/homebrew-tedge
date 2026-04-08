#!/bin/sh
set -e

OUTPUT_DIR=""
COMMAND=""
TEDGE_CONFIG_DIR=${TEDGE_CONFIG_DIR:-/etc/tedge}

# Default paths (Linux)
MOSQUITTO_CONF_DIR="/etc/mosquitto"
MOSQUITTO_LOG_DIR="/var/log/mosquitto"

# On macOS with Homebrew, resolve paths via brew prefix
if [ "$(uname)" = "Darwin" ] && command -V brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix)"
    MOSQUITTO_CONF_DIR="$BREW_PREFIX/etc/mosquitto"
    MOSQUITTO_LOG_DIR="$BREW_PREFIX/var/log/mosquitto"
fi

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        collect)
            COMMAND="collect"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Check if the output directory exists
if [ -n "$OUTPUT_DIR" ] && [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory does not exist: $OUTPUT_DIR" >&2
    exit 1
fi

mosquitto_journal() {
    journalctl -u "mosquitto" -n 1000 --no-pager > "$OUTPUT_DIR/mosquitto-journal.log" 2>&1 ||:
}

mosquitto_log() {
    if [ -f "$MOSQUITTO_LOG_DIR/mosquitto.log" ]; then
        # avoid copying the full file as it could be very large if logrotate is not installed and configured
        # but still log the details as it could be helpful to diagnose
        echo "mosquitto log file details:" >&2
        ls -l "$MOSQUITTO_LOG_DIR/mosquitto.log" >&2 ||:
        tail -n 1000 "$MOSQUITTO_LOG_DIR/mosquitto.log" > "$OUTPUT_DIR"/mosquitto.log ||:
    else
        echo "mosquitto.log not found" >&2
    fi
}

mosquitto_config() {
    if [ -d "$MOSQUITTO_CONF_DIR" ]; then
        if command -V tree >/dev/null >&2; then
            tree "$MOSQUITTO_CONF_DIR" > "$OUTPUT_DIR/etc_mosquitto.tree.txt" ||:
        else
            ls -l "$MOSQUITTO_CONF_DIR"/* > "$OUTPUT_DIR/etc_mosquitto.tree.txt" ||:
        fi
    else
        echo "$MOSQUITTO_CONF_DIR directory does not exist" >&2
    fi

    mkdir -p "$OUTPUT_DIR/mosquitto"
    if [ -f "$MOSQUITTO_CONF_DIR/mosquitto.conf" ]; then
        cp -aR "$MOSQUITTO_CONF_DIR/mosquitto.conf" "$OUTPUT_DIR/mosquitto" ||:
    fi
    if [ -d "$MOSQUITTO_CONF_DIR/conf.d" ]; then
        cp -aR "$MOSQUITTO_CONF_DIR/conf.d" "$OUTPUT_DIR/mosquitto/" ||:
    fi

    mkdir -p "$OUTPUT_DIR/tedge"
    cp -aR "$TEDGE_CONFIG_DIR/mosquitto-conf" "$OUTPUT_DIR/tedge/" ||:

    # sanitize password fields (sed -i.bak works on both Linux and macOS BSD sed)
    find "$OUTPUT_DIR" -name "*.conf" -exec sed -i.bak 's/password\s*.*/password <redacted>/g' {} \; ||:
    find "$OUTPUT_DIR" -name "*.conf.bak" -delete ||:
}

collect() {
    if command -V mosquitto > /dev/null 2>&1; then
        if command -V journalctl >/dev/null 2>&1; then
            mosquitto_journal
        fi
        mosquitto_log
        mosquitto_config
    else
        echo "mosquitto not found" >&2
        # this plugin is not applicable when mosquitto doesn't exist
        exit 2
    fi
}

case "$COMMAND" in
    collect)
        collect
        ;;
    *)
        echo "Unknown command" >&2
        exit 1
        ;;
esac

exit 0
