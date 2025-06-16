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

# Validate required environment variables
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Error: GITHUB_TOKEN environment variable is required"
    exit 1
fi

if [[ -z "$GITHUB_OWNER" ]]; then
    echo "Error: GITHUB_OWNER environment variable is required"
    exit 1
fi

# Set default values
RUNNER_SCOPE=${RUNNER_SCOPE:-repo}
RUNNER_NAME=${RUNNER_NAME:-$(hostname)}
RUNNER_LABELS=${RUNNER_LABELS:-local,docker,self-hosted}
RUNNER_GROUP=${RUNNER_GROUP:-default}

# Determine registration URL based on scope
if [[ "$RUNNER_SCOPE" == "org" ]]; then
    REGISTRATION_URL="https://github.com/${GITHUB_OWNER}"
    echo "Registering organization-level runner for: $GITHUB_OWNER"
else
    if [[ -z "$GITHUB_REPOSITORY" ]]; then
        echo "Error: GITHUB_REPOSITORY is required when RUNNER_SCOPE is 'repo'"
        exit 1
    fi
    REGISTRATION_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY}"
    echo "Registering repository-level runner for: $GITHUB_OWNER/$GITHUB_REPOSITORY"
fi

# Get registration token
echo "Getting registration token..."
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
    echo "Error: Failed to get registration token. Check your GITHUB_TOKEN permissions."
    exit 1
fi

# Configure the runner
echo "Configuring runner..."
./config.sh \
    --url "$REGISTRATION_URL" \
    --token "$REGISTRATION_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --runnergroup "$RUNNER_GROUP" \
    --work "/home/runner/_work" \
    --unattended \
    --replace

# Start the runner
echo "Starting runner..."
exec ./run.sh
