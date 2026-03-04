#!/usr/bin/env bash
set -euo pipefail

CLI_BIN="${CLI_BIN:-creditchain}"
VALIDATOR_NAME="${VALIDATOR_NAME:-validator-new}"
WORK_DIR="${WORK_DIR:-./independent-validator/${VALIDATOR_NAME}}"
VALIDATOR_HOST="${VALIDATOR_HOST:-}"
FULLNODE_HOST="${FULLNODE_HOST:-}"
STAKE_AMOUNT="${STAKE_AMOUNT:-100000000000000}"
PROFILE="${PROFILE:-default}"

if [[ -z "${VALIDATOR_HOST}" || -z "${FULLNODE_HOST}" ]]; then
  echo "VALIDATOR_HOST and FULLNODE_HOST are required (e.g. validator-new.example.org:6180 and validator-new.example.org:6182)." >&2
  exit 1
fi

mkdir -p "${WORK_DIR}"

"${CLI_BIN}" genesis generate-keys --output-dir "${WORK_DIR}"
"${CLI_BIN}" genesis set-validator-configuration \
  --owner-public-identity-file "${WORK_DIR}/public-keys.yaml" \
  --local-repository-dir "${WORK_DIR}" \
  --username "${VALIDATOR_NAME}" \
  --validator-host "${VALIDATOR_HOST}" \
  --full-node-host "${FULLNODE_HOST}" \
  --stake-amount "${STAKE_AMOUNT}"

OPERATOR_CONFIG="${WORK_DIR}/${VALIDATOR_NAME}/operator.yaml"
if [[ ! -f "${OPERATOR_CONFIG}" ]]; then
  echo "Expected operator config not found: ${OPERATOR_CONFIG}" >&2
  exit 1
fi

cat <<INSTRUCTIONS
Prepared independent validator artifacts in: ${WORK_DIR}

Next steps (run with a funded on-chain account in profile '${PROFILE}'):

1) Register validator config on-chain:
   ${CLI_BIN} node initialize-validator --operator-config-file "${OPERATOR_CONFIG}" --profile "${PROFILE}"

2) Add stake:
   ${CLI_BIN} stake add-stake --amount "${STAKE_AMOUNT}" --profile "${PROFILE}"

3) Join validator set:
   ${CLI_BIN} node join-validator-set --profile "${PROFILE}"

4) Verify after next epoch:
   ${CLI_BIN} node show-validator-set --profile "${PROFILE}"

Note:
- This assumes owner/operator use the same account profile.
- If owner and operator are split accounts, add --pool-address where required.
INSTRUCTIONS
