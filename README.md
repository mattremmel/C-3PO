# C3PO — Claude Code Container (Permissions Optional)

A containerized Arch Linux environment for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with `--dangerously-skip-permissions` — safely isolated from your host system.

## Quick Start

```bash
# 1. Build the image
./build.sh

# 2. Symlink to PATH (one-time)
ln -s "$(pwd)/c3po" ~/.local/bin/c3po

# 3. Run from any project directory
cd ~/my-project
c3po
```

## Prerequisites

- **Docker** (or a compatible runtime like Podman)
- **Auth** — one of:
  - Existing `~/.claude` directory with OAuth tokens (from running `claude` on host)
  - `ANTHROPIC_API_KEY` environment variable
  - `CLAUDE_CODE_OAUTH_TOKEN` environment variable

## Installation

Clone the repo and build:

```bash
git clone https://github.com/you/c3po.git
cd c3po
./build.sh
```

Add `c3po` to your PATH:

```bash
# Symlink (recommended)
ln -s "$(pwd)/c3po" ~/.local/bin/c3po

# Or add the repo directory to PATH
export PATH="$PATH:/path/to/c3po"
```

## Usage

```bash
# Interactive session in current directory
c3po

# Pass a prompt directly
c3po -p "refactor the auth module to use JWT"

# Resume last conversation
c3po --resume

# Drop into a shell for debugging
c3po --shell

# Pass any Claude Code flags
c3po --model sonnet --verbose
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | API key — forwarded to container if set |
| `CLAUDE_CODE_OAUTH_TOKEN` | OAuth token — forwarded to container if set |

If neither is set, the container uses tokens from `~/.claude` (mounted from host).

## Configuration

### Config Files

| File | Container Path | Purpose |
|------|---------------|---------|
| `config/claude-config.json` | `~/.claude.json` | Onboarding, auto-updates, project trust |
| `config/settings.json` | `~/.claude/settings.json` | Tool permissions, editor config |
| `config/settings.local.json` | `/workspace/.claude/settings.local.json` | Project-level settings (copied if absent) |
| `config/nvim/init.lua` | `~/.config/nvim/init.lua` | Neovim baseline config |

### Host Mount Overlay

The host `~/.claude` directory is mounted into the container at runtime. This means:

- **Existing OAuth tokens are reused** — no re-authentication needed
- **Session state persists** across container runs
- Build-time config files serve as **fallback defaults** when no host config exists

### Project Settings

`settings.local.json` is copied into `/workspace/.claude/` only if not already present, so your project's existing settings are never overwritten.

## Included Languages

The image ships with the following language toolchains pre-installed:

| Language | Tools |
|----------|-------|
| **Node.js** | node, npm, yarn, pnpm, typescript, ts-node |
| **Python** | python, uv |
| **Rust** | rustc, cargo, rustup, sccache, cargo-edit, cargo-watch |
| **Go** | go, golangci-lint, dlv |

To add more languages, edit the `Dockerfile` and rebuild: `./build.sh`

## Architecture

```
Host                              Container
─────────────────────────         ─────────────────────────
$(pwd)/         ──── rw ────►     /workspace/
~/.claude/      ──── rw ────►     /home/claude/.claude/
$ANTHROPIC_API_KEY ── env ──►     $ANTHROPIC_API_KEY

                                  entrypoint.sh
                                    └─► exec claude --dangerously-skip-permissions
                                         (PID 1 via --init/tini)
```

### Container Details

- **Base**: `archlinux:base-devel` (gcc, make, etc. pre-installed)
- **User**: `claude` (UID 1000) — matches typical host user for clean volume permissions
- **Workspace**: `/workspace` — your project files, mounted read-write
- **Init**: Docker `--init` flag provides tini for proper signal handling

## Security

The container runs with reasonable hardening for a dev environment:

- `--cap-drop=ALL` — no Linux capabilities
- `--security-opt=no-new-privileges:true` — no privilege escalation
- `--pids-limit=500` — process limit (generous for dev work)
- Non-root user inside container
- `--dangerously-skip-permissions` is scoped to the container only

This is a **development tool**, not a security sandbox. The workspace mount is read-write by design.

## Build Options

```bash
# Standard build
./build.sh

# No cache rebuild
./build.sh --no-cache

# Custom user ID (match your host UID)
docker build --build-arg USER_ID=$(id -u) -t c3po .
```
