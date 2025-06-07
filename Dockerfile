# Use Ubuntu 22.04 as base image
FROM ubuntu:22.04

# Set environment variables (almost never changes)
ENV DEBIAN_FRONTEND=noninteractive
ENV RUST_VERSION=1.82.0
ENV NODE_VERSION=20

# Install system packages in logical groups
RUN apt-get update && \
    apt-get install -y curl wget git ca-certificates sudo && \
    apt-get install -y build-essential pkg-config && \
    apt-get install -y libssl-dev libpq-dev libsqlite3-dev libmysqlclient-dev && \
    apt-get install -y unzip jq vim nano htop tree && \
    rm -rf /var/lib/apt/lists/*

# Create user and configure permissions
RUN groupadd --gid 1000 utakata && \
    useradd --uid 1000 --gid utakata --shell /bin/bash --create-home utakata && \
    echo 'utakata ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Switch to utakata user
USER utakata
WORKDIR /home/utakata

# Install Rust (only invalidated when RUST_VERSION changes)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
    --default-toolchain ${RUST_VERSION} \
    --profile minimal \
    --component rustfmt,clippy,rust-src \
    -y

# Install Node.js and configure npm permissions
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash - && \
    sudo apt-get install -y nodejs && \
    sudo chown -R utakata:utakata /usr/lib/node_modules && \
    sudo chmod -R 755 /usr/lib/node_modules

# Set permanent environment variables
ENV CARGO_HOME="/home/utakata/.cargo"
ENV RUSTUP_HOME="/home/utakata/.rustup"
ENV PATH="/home/utakata/.cargo/bin:/usr/bin:/usr/local/bin:/usr/lib/node_modules/.bin:$PATH"

# Configure shell environment
RUN echo '# Rust environment' >> ~/.bashrc && \
    echo 'export CARGO_HOME="$HOME/.cargo"' >> ~/.bashrc && \
    echo 'export RUSTUP_HOME="$HOME/.rustup"' >> ~/.bashrc && \
    echo 'source "$CARGO_HOME/env"' >> ~/.bashrc && \
    echo '' >> ~/.bashrc && \
    echo '# Node.js environment' >> ~/.bashrc && \
    echo 'export PATH="/usr/bin:/usr/local/bin:/usr/lib/node_modules/.bin:$PATH"' >> ~/.bashrc && \
    echo '' >> ~/.bashrc && \
    echo '# Aliases' >> ~/.bashrc && \
    echo 'alias ll="ls -la"' >> ~/.bashrc && \
    echo 'alias cc="claude-code"' >> ~/.bashrc && \
    echo '' >> ~/.bashrc && \
    echo '# Welcome message' >> ~/.bashrc && \
    echo 'echo "🚀 Next.js + Loco Development Environment Ready!"' >> ~/.bashrc && \
    echo 'echo "📝 Tools: rust, cargo, node, npm, claude-code"' >> ~/.bashrc && \
    echo 'echo "💡 Run: cc auth to setup Claude Code"' >> ~/.bashrc

# Install essential Rust tools
RUN /bin/bash -c "source ~/.cargo/env && cargo install --locked cargo-watch"

# Install database tools
RUN /bin/bash -c "source ~/.cargo/env && \
    (cargo install --locked sqlx-cli --features native-tls,postgres,mysql,sqlite || echo 'sqlx-cli installation failed') && \
    (cargo install --locked sea-orm-cli || echo 'sea-orm-cli installation failed')"

# Install framework tools
RUN /bin/bash -c "source ~/.cargo/env && \
    (cargo install --locked loco || echo 'loco-cli installation failed')"

# Install Claude Code
RUN sudo npm install -g @anthropic-ai/claude-code

# Create workspace directories and verify installations
RUN mkdir -p /workspaces && \
    sudo chown -R utakata:utakata /workspaces && \
    /bin/bash -c "source ~/.cargo/env && rustc --version && cargo --version" && \
    node --version && npm --version

WORKDIR /workspaces

# Expose common ports
EXPOSE 3000 5150 8080

CMD ["/bin/bash"]