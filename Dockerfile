# =============================================================================
# マルチステージビルド: Next.js + Loco (Rust) + PostgreSQL開発環境
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Node.js環境 (Alpine Linux)
# -----------------------------------------------------------------------------
FROM node:24-bullseye-slim AS node-stage
RUN apt-get update && apt-get install -y git \
    && rm -rf /var/lib/apt/lists/*

# Install system packages in logical groups
RUN apt-get update && \
    apt-get install -y curl wget git ca-certificates sudo && \
    apt-get install -y build-essential pkg-config && \
    apt-get install -y libssl-dev libpq-dev  && \
    apt-get install -y unzip jq vim nano htop tree && \
    apt-get install -y postgresql-client && \
    rm -rf /var/lib/apt/lists/*
# -----------------------------------------------------------------------------
# Stage 2: Rust基盤 (Debian Slim) + Node.js追加
# -----------------------------------------------------------------------------
FROM rust:1.87.0-slim-bullseye AS rust-base

# 必要なシステムパッケージのインストール
RUN apt-get update && apt-get install -y \
    # Rust/Loco開発に必要
    pkg-config \
    libssl-dev \
    libpq-dev \
    # PostgreSQLクライアント
    postgresql-client \
    # 開発ツール
    git \
    curl \
    ca-certificates \
    # ビルドツール
    build-essential \
    python3 \
    # Node.js用の依存関係
    xz-utils \
    libssl3 \ 
	libssl3-dev \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && apt-get autoremove -y

# Node.js 24をSlimイメージからコピー (同じDebian系なので互換性あり)
COPY --from=node-stage /usr/local/bin/node /usr/local/bin/node
COPY --from=node-stage /usr/local/bin/npm /usr/local/bin/npm
COPY --from=node-stage /usr/local/bin/npx /usr/local/bin/npx
COPY --from=node-stage /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node-stage /usr/local/bin/corepack /usr/local/bin/corepack
COPY --from=node-stage /usr/local/include/node /usr/local/include/node
COPY --from=node-stage /usr/local/share/doc/node /usr/local/share/doc/node

# NPMのシンボリックリンクを正しく設定
RUN cd /usr/local/bin \
    && ln -sf ../lib/node_modules/npm/bin/npm-cli.js npm \
    && ln -sf ../lib/node_modules/npm/bin/npx-cli.js npx \
    && node --version && npm --version


# Rustツールチェーンの最適化
RUN rustup component add rustfmt clippy \
    && cargo install cargo-edit cargo-watch sqlx-cli sea-orm-cli loco \
    && rm -rf /usr/local/cargo/registry/cache

# -----------------------------------------------------------------------------
# Stage 3: 開発環境構築
# -----------------------------------------------------------------------------
FROM rust-base AS development

# 開発ユーザーの作成
ARG USERNAME=utakata
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && mkdir -p /home/$USERNAME/.cargo/registry \
    && mkdir -p /home/$USERNAME/.npm \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME

# sudoの設定（開発環境用）
RUN apt-get update && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code and verify installations
# RUN sudo npm install -g @anthropic-ai/claude-code && \
RUN rustc --version && cargo --version" && \
    node --version && npm --version
# -----------------------------------------------------------------------------
# Stage 4: 最終開発環境
# -----------------------------------------------------------------------------
FROM development AS final

USER $USERNAME

# 作業ディレクトリの設定
WORKDIR /workspaces

# Cargo設定の最適化
RUN mkdir -p /home/$USERNAME/.cargo \
    && echo '[build]\ntarget-dir = "/tmp/target"\n\n[net]\ngit-fetch-with-cli = true\n\n[registries.crates-io]\nprotocol = "sparse"' > /home/$USERNAME/.cargo/config.toml

# 環境変数の設定
ENV CARGO_HOME=/home/$USERNAME/.cargo
ENV CARGO_TARGET_DIR=/tmp/target
ENV CARGO_INCREMENTAL=0
ENV RUST_BACKTRACE=0
ENV NPM_CONFIG_CACHE=/home/$USERNAME/.npm
ENV NODE_ENV=development
ENV PATH="/usr/local/bin:${PATH}"

# デフォルトコマンド
CMD ["/bin/bash"]

# -----------------------------------------------------------------------------
# ビルド時の最適化情報
# -----------------------------------------------------------------------------
# イメージサイズを確認する場合:
# docker images | grep your-image-name
#
# 各ステージのサイズを確認する場合:
# docker history your-image-name
#
# 不要なレイヤーを削除する場合:
# docker system prune -a
#
# 環境変数は.envファイルで設定:
# DATABASE_URL, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB等
# -----------------------------------------------------------------------------
