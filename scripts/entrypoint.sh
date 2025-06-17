#!/bin/bash
set -e

# Function to handle shutdown gracefully
cleanup() {
    echo "Removing runner..."
    ./remove-runner.sh
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# SMART DOCKER PERMISSIONS SETUP
echo "🐳 Setting up Docker permissions..."
if [ -S /var/run/docker.sock ]; then
    # Get the actual group ID of the docker socket on the host
    DOCKER_SOCK_GID=$(stat -c '%g' /var/run/docker.sock)
    echo "📍 Host Docker socket group ID: $DOCKER_SOCK_GID"
    
    # Get current docker group GID in container
    CURRENT_DOCKER_GID=$(getent group docker | cut -d: -f3 2>/dev/null || echo "none")
    echo "📦 Container Docker group ID: $CURRENT_DOCKER_GID"
    
    if [ "$CURRENT_DOCKER_GID" != "$DOCKER_SOCK_GID" ]; then
        echo "🔧 Adjusting docker group GID from $CURRENT_DOCKER_GID to $DOCKER_SOCK_GID"
        
        # Try to modify existing docker group, or create new one
        if sudo groupmod -g $DOCKER_SOCK_GID docker 2>/dev/null; then
            echo "✅ Modified existing docker group"
        else
            # If that fails, create a new group and add user to it
            echo "🆕 Creating new docker group with correct GID"
            sudo groupadd -g $DOCKER_SOCK_GID docker_host || true
            sudo usermod -aG $DOCKER_SOCK_GID runner
        fi
        
        # Ensure runner is in docker group
        sudo usermod -aG docker runner
    else
        echo "✅ Docker group GID already matches"
    fi
    
    # Test docker access
    echo "🧪 Testing Docker access..."
    if timeout 10 docker version >/dev/null 2>&1; then
        echo "✅ Docker access confirmed for runner user"
        docker version --format "Docker Engine: {{.Server.Version}}"
    else
        echo "❌ Docker access test failed"
        echo "🔍 Debugging information:"
        echo "   - Docker socket permissions: $(ls -la /var/run/docker.sock)"
        echo "   - Runner user groups: $(groups)"
        echo "   - Docker group members: $(getent group docker)"
        exit 1
    fi
else
    echo "⚠️ Docker socket not found at /var/run/docker.sock"
    echo "🔍 Available sockets:"
    ls -la /var/run/ | grep sock || echo "   No sockets found"
    exit 1
fi

# Set up work directory permissions
echo "📁 Setting up work directory permissions..."
mkdir -p /home/runner/_work /home/runner/_work/_tool
sudo chown -R runner:runner /home/runner/_work
chmod -R 755 /home/runner/_work
echo "✅ Work directory permissions configured"

# Validate required environment variables
echo "🔍 Validating environment variables..."
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "❌ Error: GITHUB_TOKEN environment variable is required"
    exit 1
fi

if [[ -z "$GITHUB_OWNER" ]]; then
    echo "❌ Error: GITHUB_OWNER environment variable is required"
    exit 1
fi

# Set default values
RUNNER_SCOPE=${RUNNER_SCOPE:-repo}
RUNNER_NAME=${RUNNER_NAME:-$(hostname)}
RUNNER_LABELS=${RUNNER_LABELS:-local,docker,self-hosted}
RUNNER_GROUP=${RUNNER_GROUP:-default}

echo "🏃 Runner Configuration:"
echo "   - Name: $RUNNER_NAME"
echo "   - Labels: $RUNNER_LABELS"
echo "   - Group: $RUNNER_GROUP"
echo "   - Scope: $RUNNER_SCOPE"

# Determine registration URL based on scope
if [[ "$RUNNER_SCOPE" == "org" ]]; then
    REGISTRATION_URL="https://github.com/${GITHUB_OWNER}"
    echo "🏢 Registering organization-level runner for: $GITHUB_OWNER"
else
    if [[ -z "$GITHUB_REPOSITORY" ]]; then
        echo "❌ Error: GITHUB_REPOSITORY is required when RUNNER_SCOPE is 'repo'"
        exit 1
    fi
    REGISTRATION_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY}"
    echo "📁 Registering repository-level runner for: $GITHUB_OWNER/$GITHUB_REPOSITORY"
fi

# Get registration token
echo "🎫 Getting registration token..."
if [[ "$RUNNER_SCOPE" == "org" ]]; then
    REGISTRATION_TOKEN=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/orgs/$GITHUB_OWNER/actions/runners/registration-token" | jq -r .token)
else
    REGISTRATION_TOKEN=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPOSITORY/actions/runners/registration-token" | jq -r .token)
fi

if [[ "$REGISTRATION_TOKEN" == "null" || -z "$REGISTRATION_TOKEN" ]]; then
    echo "❌ Error: Failed to get registration token. Check your GITHUB_TOKEN permissions."
    echo "🔍 Required permissions:"
    if [[ "$RUNNER_SCOPE" == "org" ]]; then
        echo "   - admin:org (for organization runners)"
    else
        echo "   - repo (for repository runners)"
    fi
    exit 1
fi

echo "✅ Registration token obtained successfully"

# Configure the runner
echo "⚙️ Configuring runner..."
./config.sh \
    --url "$REGISTRATION_URL" \
    --token "$REGISTRATION_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --runnergroup "$RUNNER_GROUP" \
    --work "/home/runner/_work" \
    --unattended \
    --replace

echo "✅ Runner configured successfully"

# Start the runner
echo "🚀 Starting runner..."
echo "🎯 Runner will listen for jobs with labels: $RUNNER_LABELS"
echo "📍 Workspace: /home/runner/_work"
echo "🔗 Registration URL: $REGISTRATION_URL"

exec ./run.sh
