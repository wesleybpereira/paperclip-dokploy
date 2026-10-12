#!/bin/sh
# Claude Code wrapper installed at /usr/local/sbin/claude (ahead of
# /usr/local/bin on PATH).
#
# `docker exec` and the Dokploy terminal enter the container as root, so a
# `claude auth login` run there writes root:root 0600 credentials that the
# Paperclip server (uid node) can neither read nor refresh: the connection
# fails verification, then silently "loses" the login, and "Start sign-in
# again" returns 500 (EACCES unlinking the root-owned backups).
#
# When invoked as root, hand the CLI to the node user instead. The connector
# wizard's `mkdir -p "$CLAUDE_CONFIG_DIR"` also runs as root, so repair the
# ownership of that directory first (only inside the Paperclip home).
#
# Escape hatch: PAPERCLIP_CLAUDE_AS_ROOT=1 runs the real binary as root.

set -e

REAL_CLAUDE=/usr/local/bin/claude
APP_HOME="${PAPERCLIP_HOME:-/paperclip}"

if [ "$(id -u)" -ne 0 ] || [ "${PAPERCLIP_CLAUDE_AS_ROOT:-}" = "1" ]; then
    exec "$REAL_CLAUDE" "$@"
fi

if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    case "$CLAUDE_CONFIG_DIR" in
        "$APP_HOME"/*)
            # Create missing parents as node so none end up root-owned.
            gosu node mkdir -p "$CLAUDE_CONFIG_DIR" 2>/dev/null || mkdir -p "$CLAUDE_CONFIG_DIR"
            chown -R node:node "$CLAUDE_CONFIG_DIR"
            ;;
    esac
fi

exec gosu node env HOME="$APP_HOME" "$REAL_CLAUDE" "$@"
