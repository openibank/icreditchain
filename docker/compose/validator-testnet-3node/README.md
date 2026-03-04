# CreditChain 3-Validator Docker Network

This compose profile brings up **3 validator nodes** and an automated **genesis/init** job.

## Build images first

This profile defaults to local image tags:
- `creditchain-core/tools:from-local`
- `creditchain-core/validator:from-local`

Build them from the repo root:

```bash
docker buildx create --use
docker/builder/docker-bake-rust-all.sh tools
docker/builder/docker-bake-rust-all.sh validator
```

## Is 3 validators in Docker possible?

Yes. This setup is valid for local development, integration testing, and bootstrap rehearsals.

For a real public chain, running all 3 validators on one Docker host is not production-safe:
- all validators share one failure domain,
- with `N=3`, BFT tolerance is `f=(N-1)/3=0`, so one validator failure can stop progress.

Use at least 4 validators on separate hosts/regions for production-grade resilience.

## What this setup does

- `genesis` service runs once and generates:
  - `genesis.blob`
  - `waypoint.txt`
  - per-validator identities:
    - `validator{0,1,2}/validator-identity.yaml`
    - `validator{0,1,2}/validator-full-node-identity.yaml`
- Validator addresses are generated as Docker DNS names:
  - `validator0:6180`, `validator1:6180`, `validator2:6180`
- Validators start only after genesis artifacts are present.

## Independent validator onboarding

This network supports post-genesis validator additions (`ALLOW_NEW_VALIDATORS=true` by default).

A new independent validator must still perform on-chain onboarding (not just network config):
1. Run a validator node with the same `genesis.blob` and `waypoint.txt`.
2. Generate keys: `creditchain genesis generate-keys --output-dir <dir>`.
3. Fund the validator account.
4. Register config: `creditchain node initialize-validator ...`.
5. Add stake: `creditchain stake add-stake --amount <octas>`.
6. Join set: `creditchain node join-validator-set`.
7. Wait one epoch and verify with `creditchain node show-validator-set`.

To simplify preparation, use:

```bash
VALIDATOR_NAME=validator-new \
VALIDATOR_HOST=validator-new.example.org:6180 \
FULLNODE_HOST=validator-new.example.org:6182 \
PROFILE=default \
./prepare-independent-validator.sh
```

Then execute on-chain onboarding in one step (owner/operator same profile):

```bash
VALIDATOR_NAME=validator-new \
PROFILE=default \
STAKE_AMOUNT=100000000000000 \
./join-independent-validator.sh
```

If join is submitted by a dedicated operator account, pass the stake pool address:

```bash
JOIN_POOL_ADDRESS=0x... \
./join-independent-validator.sh
```

## Run

From this directory:

```bash
docker compose up -d
```

Check status:

```bash
docker compose ps
docker compose logs -f genesis
docker compose logs -f validator0 validator1 validator2
```

## Endpoints on host

- validator0 REST: `http://127.0.0.1:8080`
- validator1 REST: `http://127.0.0.1:8081`
- validator2 REST: `http://127.0.0.1:8082`

Host port mappings:
- validator0: `6180/6181/6182`
- validator1: `6280/6281/6282`
- validator2: `6380/6381/6382`

## Reset and regenerate genesis

```bash
docker compose down -v
```

This removes node data and genesis volumes, so next `up` regenerates a fresh chain.

## Optional parameters

You can override image repo/tag and chain parameters with environment variables:

```bash
VALIDATOR_IMAGE_REPO=your-repo/validator \
TOOLS_IMAGE_REPO=your-repo/tools \
IMAGE_TAG=your-tag \
CHAIN_ID=43 \
STAKE_AMOUNT=100000000000000 \
EPOCH_DURATION_SECS=7200 \
ALLOW_NEW_VALIDATORS=true \
docker compose up -d
```
