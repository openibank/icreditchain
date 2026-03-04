#!/usr/bin/env bash
set -euo pipefail

CLI_BIN="${CLI_BIN:-creditchain}"
VALIDATOR_NAME="${VALIDATOR_NAME:-validator-new}"
WORK_DIR="${WORK_DIR:-./independent-validator/${VALIDATOR_NAME}}"
PROFILE="${PROFILE:-default}"
STAKE_AMOUNT="${STAKE_AMOUNT:-100000000000000}"
JOIN_POOL_ADDRESS="${JOIN_POOL_ADDRESS:-}"

OPERATOR_CONFIG="${OPERATOR_CONFIG:-${WORK_DIR}/${VALIDATOR_NAME}/operator.yaml}"
if [[ ! -f "${OPERATOR_CONFIG}" ]]; then
  echo "Operator config not found: ${OPERATOR_CONFIG}" >&2
  exit 1
fi

"${CLI_BIN}" node initialize-validator \
  --operator-config-file "${OPERATOR_CONFIG}" \
  --profile "${PROFILE}"

"${CLI_BIN}" stake add-stake \
  --amount "${STAKE_AMOUNT}" \
  --profile "${PROFILE}"

join_cmd=("${CLI_BIN}" node join-validator-set --profile "${PROFILE}")
if [[ -n "${JOIN_POOL_ADDRESS}" ]]; then
  join_cmd+=(--pool-address "${JOIN_POOL_ADDRESS}")
fi
"${join_cmd[@]}"

"${CLI_BIN}" node show-validator-set --profile "${PROFILE}"
