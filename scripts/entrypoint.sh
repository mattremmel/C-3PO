#!/bin/bash
set -eo pipefail

# Ensure workspace .claude directory exists
mkdir -p .claude

# Copy default project settings if not already present
if [ ! -f .claude/settings.local.json ]; then
    cp /home/claude/.config/c3po/settings.local.json .claude/settings.local.json
fi

if [ "${C3PO_PERSIST:-0}" = "1" ]; then
    # Persist mode: keep container alive for docker exec sessions.
    # Claude is launched from the host via 'docker exec'.
    exec sleep infinity
else
    # Ephemeral mode: Claude is PID 1, container dies with it
    CLAUDE_ARGS=()
    if [ "${C3PO_PERMISSIONS:-0}" != "1" ]; then
        CLAUDE_ARGS+=(--dangerously-skip-permissions)
    fi
    CLAUDE_ARGS+=("$@")
    exec claude "${CLAUDE_ARGS[@]}"
fi
