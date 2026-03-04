#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/tmp/creditchain-genesis-workspace"
OUTPUT_DIR="/genesis"
CHAIN_ID="${CHAIN_ID:-43}"
STAKE_AMOUNT="${STAKE_AMOUNT:-100000000000000}"
EPOCH_DURATION_SECS="${EPOCH_DURATION_SECS:-7200}"
ALLOW_NEW_VALIDATORS="${ALLOW_NEW_VALIDATORS:-true}"
export CREDITCHAIN_DISABLE_TELEMETRY=true

validators=(validator0 validator1 validator2)

find_framework_bundle() {
  local candidate
  local candidates=(
    "/creditchain-framework/move/head.mrb"
    "/framework.mrb"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  candidate="$(find / -name head.mrb -print -quit 2>/dev/null || true)"
  if [[ -n "${candidate}" && -f "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi

  return 1
}

artifacts_already_exist() {
  [[ -s "${OUTPUT_DIR}/genesis.blob" ]] && [[ -s "${OUTPUT_DIR}/waypoint.txt" ]] || return 1

  local name
  for name in "${validators[@]}"; do
    [[ -s "${OUTPUT_DIR}/${name}/validator-identity.yaml" ]] || return 1
    [[ -s "${OUTPUT_DIR}/${name}/validator-full-node-identity.yaml" ]] || return 1
  done

  return 0
}

if artifacts_already_exist; then
  echo "Genesis artifacts already exist in ${OUTPUT_DIR}. Skipping initialization."
  exit 0
fi

rm -rf "${WORKSPACE}"
mkdir -p "${WORKSPACE}"

for name in "${validators[@]}"; do
  user_dir="${WORKSPACE}/${name}"
  mkdir -p "${user_dir}"

  creditchain genesis generate-keys --output-dir "${user_dir}"

  creditchain genesis set-validator-configuration \
    --owner-public-identity-file "${user_dir}/public-keys.yaml" \
    --local-repository-dir "${WORKSPACE}" \
    --username "${name}" \
    --validator-host "${name}:6180" \
    --full-node-host "${name}:6182" \
    --stake-amount "${STAKE_AMOUNT}" \
    --join-during-genesis
done

ROOT_KEY="$(awk -F': ' '$1 == "account_public_key" {gsub(/"/, "", $2); print $2; exit}' "${WORKSPACE}/validator0/public-keys.yaml")"
if [[ -z "${ROOT_KEY}" ]]; then
  echo "Failed to determine root_key from ${WORKSPACE}/validator0/public-keys.yaml" >&2
  exit 1
fi

cat > "${WORKSPACE}/layout.yaml" <<LAYOUT
root_key: "${ROOT_KEY}"
users:
  - validator0
  - validator1
  - validator2
chain_id: ${CHAIN_ID}
allow_new_validators: ${ALLOW_NEW_VALIDATORS}
epoch_duration_secs: ${EPOCH_DURATION_SECS}
is_test: true
min_stake: 100000000000000
min_voting_threshold: 100000000000000
max_stake: 100000000000000000
recurring_lockup_duration_secs: 86400
required_proposer_stake: 1000000
rewards_apy_percentage: 10
voting_duration_secs: 43200
voting_power_increase_limit: 20
LAYOUT

FRAMEWORK_BUNDLE="$(find_framework_bundle || true)"
if [[ -z "${FRAMEWORK_BUNDLE}" ]]; then
  echo "Unable to find framework.mrb/head.mrb in tools image" >&2
  exit 1
fi
cp "${FRAMEWORK_BUNDLE}" "${WORKSPACE}/framework.mrb"

creditchain genesis generate-genesis \
  --local-repository-dir "${WORKSPACE}" \
  --output-dir "${WORKSPACE}"

mkdir -p "${OUTPUT_DIR}"
cp "${WORKSPACE}/genesis.blob" "${OUTPUT_DIR}/genesis.blob"
cp "${WORKSPACE}/waypoint.txt" "${OUTPUT_DIR}/waypoint.txt"

for name in "${validators[@]}"; do
  mkdir -p "${OUTPUT_DIR}/${name}"
  cp "${WORKSPACE}/${name}/validator-identity.yaml" "${OUTPUT_DIR}/${name}/validator-identity.yaml"
  cp "${WORKSPACE}/${name}/validator-full-node-identity.yaml" "${OUTPUT_DIR}/${name}/validator-full-node-identity.yaml"
done

echo "Genesis initialization completed."
