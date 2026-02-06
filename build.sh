#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

docker build "$@" -t c3po "$SCRIPT_DIR"
