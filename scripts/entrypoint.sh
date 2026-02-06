#!/bin/bash
set -e

# Ensure workspace .claude directory exists
mkdir -p /workspace/.claude

# Copy default project settings if not already present
if [ ! -f /workspace/.claude/settings.local.json ]; then
    cp /home/claude/.config/c3po/settings.local.json /workspace/.claude/settings.local.json
fi

# Build claude args
CLAUDE_ARGS=()
if [ "${C3PO_PERMISSIONS:-0}" != "1" ]; then
    CLAUDE_ARGS+=(--dangerously-skip-permissions)
fi
CLAUDE_ARGS+=("$@")

if [ "${C3PO_PERSIST:-0}" = "1" ]; then
    # Run Claude in foreground (not exec) so entrypoint survives Claude exit
    claude "${CLAUDE_ARGS[@]}" || true
    echo "[c3po] Claude exited. Container persisting."
    echo "[c3po] Use 'c3po exec' for shell, 'c3po attach' for Claude, 'c3po stop' to terminate."
    # Keep container alive for docker exec sessions
    exec sleep infinity
else
    # Ephemeral mode: Claude is PID 1, container dies with it
    exec claude "${CLAUDE_ARGS[@]}"
fi
