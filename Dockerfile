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
    bat \
    just \
    procs \
    lazygit \
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
# yay (AUR helper) + AUR packages
# -----------------------------------------------------------------------------
# makepkg cannot run as root, so build yay as the target user.
# Grant passwordless sudo temporarily for the install step.
RUN echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER ${USER_NAME}
RUN git clone --depth=1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin \
    && cd /tmp/yay-bin \
    && makepkg -si --noconfirm \
    && rm -rf /tmp/yay-bin

RUN yay -S --noconfirm beads-bin \
    && yay -Scc --noconfirm
USER root

RUN sed -i "/${USER_NAME} ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers

# -----------------------------------------------------------------------------
# Node.js
# -----------------------------------------------------------------------------
RUN pacman -S --noconfirm --needed nodejs npm \
    && pacman -Scc --noconfirm

# -----------------------------------------------------------------------------
# Claude Code (native binary)
# -----------------------------------------------------------------------------
USER ${USER_NAME}
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root

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
RUN nvim --headless -c "autocmd User MasonToolsInstallComplete qall" -c "MasonInstallAll" \
    || echo "WARNING: Mason tools install exited non-zero (known issue, tools may still be installed)"
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
RUN pacman -S --noconfirm --needed rustup sccache cargo-edit cargo-watch \
    && pacman -Scc --noconfirm

USER ${USER_NAME}
RUN rustup default stable \
    && rustup toolchain install nightly --component rustfmt
USER root

# -----------------------------------------------------------------------------
# Go
# -----------------------------------------------------------------------------
RUN pacman -S --noconfirm --needed go golangci-lint delve \
    && pacman -Scc --noconfirm

ENV GOPATH="/home/${USER_NAME}/go"

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

ENV PATH="/home/${USER_NAME}/.local/bin:/home/${USER_NAME}/.cargo/bin:/home/${USER_NAME}/go/bin:${PATH}"
ENV EDITOR=nvim
ENV VISUAL=nvim

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
