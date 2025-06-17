#!/bin/bash

echo "🧹 Attempting to remove runner registration..."

# Function to remove the runner registration
if [[ -f ".runner" ]]; then
    echo "📋 Runner configuration file found, proceeding with removal..."
    
    # Get removal token
    echo "🎫 Getting removal token..."
    if [[ "$RUNNER_SCOPE" == "org" ]]; then
        REMOVAL_TOKEN=$(curl -s -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/orgs/$GITHUB_OWNER/actions/runners/remove-token" | jq -r .token 2>/dev/null)
    else
        REMOVAL_TOKEN=$(curl -s -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPOSITORY/actions/runners/remove-token" | jq -r .token 2>/dev/null)
    fi
    
    if [[ "$REMOVAL_TOKEN" != "null" && -n "$REMOVAL_TOKEN" ]]; then
        echo "✅ Removal token obtained, removing runner..."
        ./config.sh remove --unattended --token "$REMOVAL_TOKEN"
        echo "✅ Runner removed successfully from GitHub"
    else
        echo "⚠️ Warning: Could not get removal token, runner may remain registered in GitHub"
        echo "🔍 This could be due to:"
        echo "   - Network connectivity issues"
        echo "   - Token permissions"
        echo "   - GitHub API rate limiting"
    fi
else
    echo "ℹ️ Runner not configured (.runner file not found), nothing to remove"
fi

echo "🏁 Cleanup complete"
