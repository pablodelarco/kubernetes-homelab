#!/bin/bash
# Setup Renovate GitHub Token

set -e

echo "🔐 Setting up Renovate GitHub Token"
echo ""

# Check if token is provided
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GITHUB_TOKEN environment variable not set"
    echo ""
    echo "Please create a GitHub Personal Access Token with 'repo' and 'workflow' scopes:"
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

echo "✅ GitHub token found"
echo ""

# Create namespace if it doesn't exist
kubectl create namespace renovate --dry-run=client -o yaml | kubectl apply -f -

# Create the secret
kubectl create secret generic renovate-secret \
    --from-literal=token="$GITHUB_TOKEN" \
    -n renovate \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret created in renovate namespace"
echo ""
echo "🚀 Now you can deploy Renovate:"
echo "  kubectl apply -f argocd-apps/renovate.yaml"

