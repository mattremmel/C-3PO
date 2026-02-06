# C3PO

Containerized Arch Linux environment for running Claude Code with `--dangerously-skip-permissions` in isolation.

## Key Files

- `c3po` — CLI entrypoint (bash). Manages container lifecycle: run, exec, attach, stop, status, logs, build.
- `Dockerfile` — Arch Linux image with Node.js, Python, Rust, Go, neovim, and Claude Code.
- `scripts/entrypoint.sh` — Container entrypoint. Handles persist vs ephemeral mode.
- `build.sh` — Convenience wrapper for `docker build`.
- `config/` — Default Claude and project settings baked into the image.

## Build & Test

```bash
./build.sh          # Build the Docker image
./c3po --help       # Verify CLI works
./c3po --version    # Print version
```

## Code Style

- Bash scripts, targeting bash 5+.
- All scripts use `set -eo pipefail`.
- Keep scripts shellcheck-clean (`shellcheck c3po scripts/entrypoint.sh build.sh`).
- No external dependencies beyond Docker and coreutils.
