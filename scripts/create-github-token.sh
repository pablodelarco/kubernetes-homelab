#!/bin/bash
# Create GitHub token for Renovate Bot

set -e

echo "🔐 Creating GitHub Personal Access Token for Renovate Bot"
echo ""

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Login to GitHub if not already logged in
if ! gh auth status &> /dev/null; then
    echo "📝 Please login to GitHub CLI:"
    gh auth login
fi

echo "✅ GitHub CLI authenticated"
echo ""

# Create a token with required scopes
echo "🔑 Creating Personal Access Token..."
TOKEN=$(gh auth token)

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get token from GitHub CLI"
    echo ""
    echo "Please create a token manually:"
    echo "1. Go to: https://github.com/settings/tokens/new"
    echo "2. Name: Renovate Bot"
    echo "3. Scopes: repo, workflow"
    echo "4. Generate token"
    echo ""
    echo "Then run:"
    echo "  export GITHUB_TOKEN='your_token_here'"
    echo "  ./scripts/setup-renovate-token.sh"
    exit 1
fi

echo "✅ Token obtained"
echo ""

# Update the secret
kubectl create secret generic renovate-secret \
    --from-literal=token="$TOKEN" \
    -n renovate \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret updated in renovate namespace"
echo ""
echo "🚀 Triggering a manual Renovate run to test..."
kubectl delete job renovate-manual-test -n renovate --ignore-not-found=true
kubectl create job --from=cronjob/renovate renovate-manual-test -n renovate

echo ""
echo "📊 Watch the logs with:"
echo "  kubectl logs -n renovate -l job-name=renovate-manual-test -f"

