#!/bin/bash
# iCreditChain Private Deployment Script
# Builds docker images, initializes genesis, and starts validators.
#
# Usage:
#   ./scripts/deploy.sh              # Full deployment
#   ./scripts/deploy.sh --skip-build # Use existing images
#   ./scripts/deploy.sh --reset      # Destroy and recreate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${DEPLOY_DIR}/../.." && pwd)"

# Load environment
if [ -f "${DEPLOY_DIR}/.env.local" ]; then
    source "${DEPLOY_DIR}/.env.local"
elif [ -f "${DEPLOY_DIR}/.env" ]; then
    source "${DEPLOY_DIR}/.env"
fi

CHAIN_NAME="${CHAIN_NAME:-iCreditChain-Private}"
SKIP_BUILD=false
RESET=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-build) SKIP_BUILD=true ;;
        --reset) RESET=true ;;
        --help|-h)
            echo "Usage: deploy.sh [--skip-build] [--reset]"
            echo "  --skip-build  Skip docker image builds"
            echo "  --reset       Destroy volumes and recreate from scratch"
            exit 0
            ;;
    esac
done

echo "╔══════════════════════════════════════════╗"
echo "║   iCreditChain Private Deployment        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Reset if requested
if [ "$RESET" = true ]; then
    echo "[RESET] Destroying existing deployment..."
    cd "${DEPLOY_DIR}"
    docker compose down -v 2>/dev/null || true
    echo "  Volumes destroyed."
    echo ""
fi

# Step 1: Build docker images
if [ "$SKIP_BUILD" = false ]; then
    echo "[1/3] Building docker images..."
    if [ -f "${PROJECT_ROOT}/docker/builder/docker-bake-rust-all.sh" ]; then
        cd "${PROJECT_ROOT}"
        bash docker/builder/docker-bake-rust-all.sh || {
            echo "ERROR: Docker build failed."
            echo "  If images already exist, use --skip-build flag."
            exit 1
        }
    else
        echo "  WARNING: Build script not found at docker/builder/docker-bake-rust-all.sh"
        echo "  Assuming images are already built. Use --skip-build to suppress this warning."
    fi
    echo ""
else
    echo "[1/3] Skipping docker build (--skip-build)"
    echo ""
fi

# Step 2: Initialize genesis + start validators
echo "[2/3] Starting deployment..."
cd "${DEPLOY_DIR}"
docker compose up -d
echo ""

# Step 3: Wait for validators to sync
echo "[3/3] Waiting for validators to start..."
for i in 0 1 2; do
    PORT_VAR="API_PORT_${i}"
    PORT="${!PORT_VAR:-809${i}}"
    echo -n "  Validator ${i} (port ${PORT}): "

    for attempt in $(seq 1 30); do
        if curl -sf "http://localhost:${PORT}/-/healthy" > /dev/null 2>&1; then
            echo "healthy"
            break
        fi
        if [ $attempt -eq 30 ]; then
            echo "not ready (may still be starting)"
        fi
        sleep 2
    done
done

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Deployment Complete!                    ║"
echo "╠══════════════════════════════════════════╣"
echo "║   REST APIs:                              ║"
echo "║     Validator 0: http://localhost:${API_PORT_0:-8090}    ║"
echo "║     Validator 1: http://localhost:${API_PORT_1:-8091}    ║"
echo "║     Validator 2: http://localhost:${API_PORT_2:-8092}    ║"
echo "║                                           ║"
echo "║   Management:                             ║"
echo "║     Logs:  docker compose logs -f          ║"
echo "║     Stop:  docker compose down             ║"
echo "║     Reset: ./scripts/deploy.sh --reset     ║"
echo "╚══════════════════════════════════════════╝"
