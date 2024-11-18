#!/usr/bin/env bash

# Check if .secrets file exists
if [ ! -f .secrets ]; then
    echo "Error: .secrets file not found"
    echo "Please create a .secrets file with your GPG_KEY"
    exit 1
fi

act workflow_dispatch -W .github/workflows/deploy.yml --container-architecture linux/arm64 --secret-file .secrets "$@" 