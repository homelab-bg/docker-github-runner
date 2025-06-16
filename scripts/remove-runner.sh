#!/bin/bash

# Function to remove the runner registration
if [[ -f ".runner" ]]; then
    echo "Removing runner registration..."
    
    # Get removal token
    if [[ "$RUNNER_SCOPE" == "org" ]]; then
        REMOVAL_TOKEN=$(curl -s -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/orgs/$GITHUB_OWNER/actions/runners/remove-token" | jq -r .token)
    else
        REMOVAL_TOKEN=$(curl -s -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPOSITORY/actions/runners/remove-token" | jq -r .token)
    fi
    
    if [[ "$REMOVAL_TOKEN" != "null" && -n "$REMOVAL_TOKEN" ]]; then
        ./config.sh remove --unattended --token "$REMOVAL_TOKEN"
        echo "Runner removed successfully"
    else
        echo "Warning: Could not get removal token, runner may remain registered"
    fi
else
    echo "Runner not configured, nothing to remove"
fi
