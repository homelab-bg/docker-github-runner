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

# Install Docker CLI
RUN curl -fsSL https://get.docker.com -o get-docker.sh && \
    sh get-docker.sh && \
    rm get-docker.sh

# Create docker group with a default GID (will be adjusted at runtime)
RUN groupadd -g 999 docker || true

# Create runner user and add to docker and sudo groups
RUN useradd -m -s /bin/bash -G docker,sudo runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

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

# Fix permissions for work directory
RUN mkdir -p /home/runner/_work /home/runner/_work/_tool && \
    sudo chown -R runner:runner /home/runner/_work && \
    chmod -R 755 /home/runner/_work

# Copy entrypoint script
COPY --chown=runner:runner scripts/entrypoint.sh /home/runner/entrypoint.sh
COPY --chown=runner:runner scripts/remove-runner.sh /home/runner/remove-runner.sh
RUN chmod +x /home/runner/entrypoint.sh /home/runner/remove-runner.sh

ENTRYPOINT ["/home/runner/entrypoint.sh"]
CMD ["./run.sh"]
