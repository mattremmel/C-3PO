#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

docker build "$@" -t c3po "$SCRIPT_DIR"
