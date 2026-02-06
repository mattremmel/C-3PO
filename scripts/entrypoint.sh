#!/bin/bash
set -e

# Ensure workspace .claude directory exists
mkdir -p /workspace/.claude

# Copy default project settings if not already present
if [ ! -f /workspace/.claude/settings.local.json ]; then
    cp /home/claude/.config/c3po/settings.local.json /workspace/.claude/settings.local.json
fi

# Hand off to claude as PID 1
exec claude --dangerously-skip-permissions "$@"
