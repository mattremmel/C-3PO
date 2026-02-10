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

# Generate UTF-8 locale
RUN sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
  && locale-gen

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
  shellcheck \
  tmux \
  htop \
  strace \
  github-cli \
  difftastic \
  hyperfine \
  tokei \
  dust \
  bottom \
  hexyl \
  xh \
  watchexec \
  docker \
  docker-compose \
  docker-buildx \
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
  && rustup toolchain install nightly --component rustfmt \
  && mkdir -p /home/${USER_NAME}/.cargo \
  && printf '[build]\nrustflags = ["-C", "link-arg=-fuse-ld=mold"]\n' \
  > /home/${USER_NAME}/.cargo/config.toml
USER root

# -----------------------------------------------------------------------------
# Go
# -----------------------------------------------------------------------------
RUN pacman -S --noconfirm --needed go golangci-lint delve \
  && pacman -Scc --noconfirm

ENV GOPATH="/home/${USER_NAME}/go"

# -----------------------------------------------------------------------------
# C/C++ & LLVM toolchain
# -----------------------------------------------------------------------------
RUN pacman -S --noconfirm --needed \
  cmake \
  clang \
  llvm \
  lldb \
  lld \
  gdb \
  mold \
  && pacman -Scc --noconfirm

# Default to mold for C/C++ builds (cmake, autotools, meson all honor LDFLAGS)
ENV LDFLAGS="-fuse-ld=mold"

# -----------------------------------------------------------------------------
# Build dependencies & database libraries
# -----------------------------------------------------------------------------
RUN pacman -S --noconfirm --needed \
  openssl \
  pkgconf \
  sqlite \
  postgresql-libs \
  protobuf \
  && pacman -Scc --noconfirm

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
WORKDIR /home/claude

ENV PATH="/home/${USER_NAME}/.local/bin:/home/${USER_NAME}/.cargo/bin:/home/${USER_NAME}/go/bin:${PATH}"
ENV EDITOR=nvim
ENV VISUAL=nvim

# Modern terminal & developer experience
ENV COLORTERM=truecolor
ENV TERM=xterm-256color
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LESS="-RFX"
ENV MANPAGER="less -R"
ENV GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
ENV FORCE_COLOR=1
ENV CARGO_TERM_COLOR=always
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
