# =============================================================================
# C3PO - Claude Code Container (Permissions Optional)
# =============================================================================

ARG USER_NAME=claude
ARG USER_ID=1000

# -----------------------------------------------------------------------------
# Base system
# -----------------------------------------------------------------------------
FROM archlinux:base-devel

ARG USER_NAME
ARG USER_ID

# Full system upgrade (required for Arch rolling release)
RUN pacman -Syu --noconfirm && pacman -Scc --noconfirm

# -----------------------------------------------------------------------------
# Core utilities
# -----------------------------------------------------------------------------
RUN pacman -S --noconfirm --needed \
    git \
    curl \
    wget \
    openssh \
    jq \
    ripgrep \
    fd \
    tree \
    less \
    man-db \
    unzip \
    zip \
    && pacman -Scc --noconfirm

# -----------------------------------------------------------------------------
# Non-root user
# -----------------------------------------------------------------------------
RUN useradd -m -s /bin/bash -u ${USER_ID} ${USER_NAME}

# -----------------------------------------------------------------------------
# Node.js + Claude Code
# -----------------------------------------------------------------------------
RUN pacman -S --noconfirm --needed nodejs npm \
    && pacman -Scc --noconfirm

RUN npm install -g @anthropic-ai/claude-code \
    && npm cache clean --force

# -----------------------------------------------------------------------------
# Neovim
# -----------------------------------------------------------------------------
RUN pacman -S --noconfirm --needed neovim \
    && pacman -Scc --noconfirm

ARG NVIM_CONFIG_REPO=https://github.com/mattremmel/config-nvim.git
RUN git clone --depth=1 ${NVIM_CONFIG_REPO} /home/${USER_NAME}/.config/nvim \
    && rm -rf /home/${USER_NAME}/.config/nvim/.git

# Pre-install neovim plugins, treesitter parsers, and Mason tools at build time
# so first launch is instant. Runs as the target user since plugin/data dirs
# live under $HOME. Each step is async so we wait for completion signals.
RUN chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}
USER ${USER_NAME}
RUN nvim --headless "+Lazy! sync" +qa
RUN nvim --headless "+TSUpdateSync" +qa
# FIXME: Mason tools install successfully but nvim exits with code 1.
# The MasonToolsInstallComplete event may fire before all async installs finish,
# or one of the tools emits a non-zero exit. Needs root-cause investigation.
RUN nvim --headless -c "autocmd User MasonToolsInstallComplete qall" -c "MasonInstallAll" || true
USER root

# -----------------------------------------------------------------------------
# Node.js extras
# -----------------------------------------------------------------------------
RUN npm install -g yarn pnpm typescript ts-node \
    && npm cache clean --force

# -----------------------------------------------------------------------------
# Python + uv
# -----------------------------------------------------------------------------
RUN pacman -S --noconfirm --needed python uv \
    && pacman -Scc --noconfirm

# -----------------------------------------------------------------------------
# Rust + cargo tools
# -----------------------------------------------------------------------------
RUN pacman -S --noconfirm --needed rustup sccache \
    && pacman -Scc --noconfirm

USER ${USER_NAME}
RUN rustup default stable \
    && cargo install cargo-edit cargo-watch
USER root

# -----------------------------------------------------------------------------
# Go
# -----------------------------------------------------------------------------
RUN pacman -S --noconfirm --needed go \
    && pacman -Scc --noconfirm

ENV GOPATH="/home/${USER_NAME}/go"

USER ${USER_NAME}
RUN go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go clean -cache -modcache
USER root

# -----------------------------------------------------------------------------
# Claude config (defaults — host ~/.claude mount overlays at runtime)
# -----------------------------------------------------------------------------
COPY config/claude-config.json /home/${USER_NAME}/.claude.json
COPY config/settings.json /home/${USER_NAME}/.claude/settings.json
COPY config/settings.local.json /home/${USER_NAME}/.config/c3po/settings.local.json

# -----------------------------------------------------------------------------
# Entrypoint
# -----------------------------------------------------------------------------
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Fix ownership for all user files
RUN chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}

USER ${USER_NAME}
WORKDIR /workspace

ENV PATH="/home/${USER_NAME}/.cargo/bin:/home/${USER_NAME}/go/bin:${PATH}"
ENV EDITOR=nvim
ENV VISUAL=nvim

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
