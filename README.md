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

### Starting a Session

```bash
# Interactive session — container persists after Claude exits
c3po

# Pass a prompt directly
c3po -p "refactor the auth module to use JWT"

# Resume last conversation (note: for initial c3po run, not attach)
c3po --resume

# Pass any Claude Code flags
c3po --model sonnet --verbose
```

### Working with a Running Container

After Claude exits (or while it's running), the container stays alive. Use your host tmux to open additional panes:

```bash
# Open a shell in the running container
c3po exec

# Run a specific command
c3po exec nvim .
c3po exec cargo test
c3po exec git log --oneline

# Resume the last Claude session (default)
c3po attach

# Start a fresh session instead of resuming
c3po attach --no-resume

# Interactive session picker
c3po attach --resume
```

### Lifecycle Management

```bash
# See all c3po containers
c3po status

# Stop and remove the container for this workspace
c3po stop
```

### Ephemeral Mode

For one-shot tasks where you don't need the container to persist:

```bash
# Container removed when Claude exits (old behavior)
c3po --ephemeral

# Shell mode is always ephemeral
c3po --shell
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | API key — forwarded to container if set |
| `CLAUDE_CODE_OAUTH_TOKEN` | OAuth token — forwarded to container if set |

If neither is set, the container uses tokens from `~/.claude` (mounted from host).

## Persist-Mode Workflow

The default workflow uses your **host tmux** as the multiplexer:

```
tmux pane 1              tmux pane 2              tmux pane 3
─────────────            ─────────────            ─────────────
$ c3po                   $ c3po exec              $ c3po exec nvim .
  → Claude session         → bash inside             → neovim inside
  → exits, container        same container            same container
    keeps running
```

1. `c3po` starts Claude in a named container. When Claude exits, the container stays alive.
2. From other tmux panes, `c3po exec` drops into a shell and `c3po attach` resumes the last Claude session — all sharing the same container, filesystem, and installed packages.
3. `c3po stop` tears everything down when you're done.

Each workspace gets its own container (named by directory), so you can run multiple projects simultaneously.

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

                                  persist mode (default):
                                    host: docker run -d → entrypoint setup → sleep infinity
                                    host: docker exec -it → claude session
                                    Claude exits → user returns to host shell
                                    Container keeps running (sleep infinity)
                                  ephemeral mode (--ephemeral):
                                    exec claude --dangerously-skip-permissions
                                    (PID 1 via --init/tini, container dies on exit)
```

### Container Details

- **Base**: `archlinux:base-devel` (gcc, make, etc. pre-installed)
- **User**: `claude` (UID 1000) — matches typical host user for clean volume permissions
- **Workspace**: `/workspace` — your project files, mounted read-write
- **Init**: Docker `--init` flag provides tini for proper signal handling
- **Naming**: `c3po-<dirname>-<hash>` — deterministic per workspace directory

## Security

The container runs with reasonable hardening for a dev environment:

- `--cap-drop=ALL` — no Linux capabilities
- `--security-opt=no-new-privileges:true` — no privilege escalation
- `--pids-limit=1024` — process limit (generous for concurrent Claude + editor + shells)
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

## Future Enhancements

### Network Restriction via Forward Proxy

Running with `--dangerously-skip-permissions` means Claude can make arbitrary outgoing network requests — `curl` to external services, `npm publish`, `git push` to unknown remotes, etc. Container isolation protects the host filesystem but does nothing about data exfiltration over the network.

The solution is a sidecar [tinyproxy](https://tinyproxy.github.io/) container that acts as a forward proxy with a domain whitelist. A `--restricted` flag on `c3po` would spin up the proxy alongside the main container, configure the container's network to route all HTTP/HTTPS traffic through it, and only allow connections to known-good domains (e.g. `api.anthropic.com`, `github.com`, `registry.npmjs.org`). All other outbound traffic would be blocked.

This gives you the convenience of `--dangerously-skip-permissions` with a meaningful safety net against unintended or malicious network activity.
