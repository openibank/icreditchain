#!/bin/bash
# iCreditChain Private Genesis Initialization
# Generates keys, validator configs, and genesis blob for a private network.
#
# Environment variables:
#   CHAIN_ID          - Chain identifier (default: 52001)
#   CHAIN_NAME        - Human-readable chain name (default: iCreditChain-Private)
#   NUM_VALIDATORS    - Number of validators (default: 3)
#   EPOCH_DURATION_SECS - Epoch length (default: 3600)
#   STAKE_AMOUNT      - Validator stake (default: 100000000000000)

set -euo pipefail

CHAIN_ID="${CHAIN_ID:-52001}"
CHAIN_NAME="${CHAIN_NAME:-iCreditChain-Private}"
NUM_VALIDATORS="${NUM_VALIDATORS:-3}"
EPOCH_DURATION_SECS="${EPOCH_DURATION_SECS:-3600}"
STAKE_AMOUNT="${STAKE_AMOUNT:-100000000000000}"
MIN_STAKE="${MIN_STAKE:-100000000000000}"
MAX_STAKE="${MAX_STAKE:-100000000000000000}"
ALLOW_NEW_VALIDATORS="${ALLOW_NEW_VALIDATORS:-false}"
REWARDS_APY_PERCENTAGE="${REWARDS_APY_PERCENTAGE:-0}"
RECURRING_LOCKUP_DURATION_SECS="${RECURRING_LOCKUP_DURATION_SECS:-86400}"

GENESIS_DIR="/opt/icreditchain/genesis"
FRAMEWORK_PATH="/creditchain-framework/move/modules"

echo "============================================="
echo " iCreditChain Private Genesis Initialization"
echo "============================================="
echo " Chain ID:         ${CHAIN_ID}"
echo " Chain Name:       ${CHAIN_NAME}"
echo " Validators:       ${NUM_VALIDATORS}"
echo " Epoch Duration:   ${EPOCH_DURATION_SECS}s"
echo " Stake Amount:     ${STAKE_AMOUNT}"
echo " New Validators:   ${ALLOW_NEW_VALIDATORS}"
echo "============================================="

# Skip if genesis already exists
if [ -f "${GENESIS_DIR}/genesis.blob" ]; then
    echo "Genesis already exists at ${GENESIS_DIR}/genesis.blob — skipping."
    exit 0
fi

mkdir -p "${GENESIS_DIR}"

# Step 1: Generate root key
echo "[1/${NUM_VALIDATORS}+3] Generating root key..."
creditchain genesis generate-keys \
    --output-dir "${GENESIS_DIR}/root" \
    --assume-yes

# Step 2: Generate validator keys and configs
for i in $(seq 0 $((NUM_VALIDATORS - 1))); do
    echo "[2.${i}] Generating keys for validator-${i}..."
    VALIDATOR_DIR="${GENESIS_DIR}/validator-${i}"
    mkdir -p "${VALIDATOR_DIR}"

    creditchain genesis generate-keys \
        --output-dir "${VALIDATOR_DIR}" \
        --assume-yes

    creditchain genesis set-validator-configuration \
        --owner-public-identity-file "${VALIDATOR_DIR}/public-keys.yaml" \
        --local-repository-dir "${GENESIS_DIR}" \
        --username "validator-${i}" \
        --validator-host "validator${i}:6180" \
        --full-node-host "validator${i}:6182" \
        --stake-amount "${STAKE_AMOUNT}"
done

# Step 3: Create layout YAML
echo "[3] Creating genesis layout..."
LAYOUT_FILE="${GENESIS_DIR}/layout.yaml"
cat > "${LAYOUT_FILE}" << LAYOUT_EOF
---
root_key: $(cat "${GENESIS_DIR}/root/public-keys.yaml" | grep "account_public_key" | awk '{print $2}' | tr -d '"')
users:
$(for i in $(seq 0 $((NUM_VALIDATORS - 1))); do echo "  - validator-${i}"; done)
chain_id: ${CHAIN_ID}
allow_new_validators: ${ALLOW_NEW_VALIDATORS}
epoch_duration_secs: ${EPOCH_DURATION_SECS}
is_test: true
min_stake: ${MIN_STAKE}
min_voting_threshold: ${MIN_STAKE}
max_stake: ${MAX_STAKE}
recurring_lockup_duration_secs: ${RECURRING_LOCKUP_DURATION_SECS}
required_proposer_stake: 1000000
rewards_apy_percentage: ${REWARDS_APY_PERCENTAGE}
voting_duration_secs: 43200
voting_power_increase_limit: 20
LAYOUT_EOF

echo "  Layout written to ${LAYOUT_FILE}"

# Step 4: Generate genesis blob
echo "[4] Generating genesis blob..."
creditchain genesis generate-genesis \
    --local-repository-dir "${GENESIS_DIR}" \
    --output-dir "${GENESIS_DIR}" \
    --mainnet

echo ""
echo "============================================="
echo " Genesis generation complete!"
echo " genesis.blob:  ${GENESIS_DIR}/genesis.blob"
echo " waypoint.txt:  ${GENESIS_DIR}/waypoint.txt"
echo "============================================="

# Step 5: Create validator identity files
for i in $(seq 0 $((NUM_VALIDATORS - 1))); do
    VALIDATOR_DIR="${GENESIS_DIR}/validator-${i}"
    echo "[5.${i}] Copying validator-${i} identity..."

    # The identity files are already generated in the validator dir
    if [ -f "${VALIDATOR_DIR}/validator-identity.yaml" ]; then
        echo "  validator-identity.yaml exists"
    fi
done

echo ""
echo "All done. Start validators with: docker compose up -d"
