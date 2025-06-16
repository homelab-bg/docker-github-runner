FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    jq \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create a user for the runner
RUN useradd -m -s /bin/bash runner && \
    usermod -aG sudo runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install Docker CLI (for workflows that need Docker)
RUN curl -fsSL https://get.docker.com -o get-docker.sh && \
    sh get-docker.sh && \
    usermod -aG docker runner && \
    rm get-docker.sh

# Set up GitHub Actions runner
WORKDIR /home/runner
USER runner

# Download and extract the latest runner
ARG RUNNER_VERSION="2.311.0"
RUN curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Install runner dependencies
RUN sudo ./bin/installdependencies.sh

# Copy entrypoint script
COPY --chown=runner:runner scripts/entrypoint.sh /home/runner/entrypoint.sh
COPY --chown=runner:runner scripts/remove-runner.sh /home/runner/remove-runner.sh
RUN chmod +x /home/runner/entrypoint.sh /home/runner/remove-runner.sh

ENTRYPOINT ["/home/runner/entrypoint.sh"]
