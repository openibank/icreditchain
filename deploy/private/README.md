# iCreditChain Private/Consortium Deployment

Deploy a private or consortium iCreditChain network with 3 validators using Docker Compose.

## Deployment Modes

| Mode | Chain ID | Validators | Open Enrollment | Rewards | Use Case |
|------|----------|-----------|----------------|---------|----------|
| **Private** | 52001 | 3 (fixed) | No | 0% | Enterprise internal settlement |
| **Consortium** | 52002 | 3+ (expandable) | Yes | 5% | Inter-bank / industry group |

## Quick Start

### Private Network (Closed Validator Set)

```bash
# Full deployment: build images, generate genesis, start validators
./scripts/deploy.sh

# Or skip the docker build if images exist
./scripts/deploy.sh --skip-build
```

### Consortium Network (Open Enrollment)

```bash
# Use consortium environment
cp .env.consortium .env.local
./scripts/deploy.sh
```

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Validator 0  │◄───►│ Validator 1  │◄───►│ Validator 2  │
│ :8090 (API)  │     │ :8091 (API)  │     │ :8092 (API)  │
│ :6190 (P2P)  │     │ :6191 (P2P)  │     │ :6192 (P2P)  │
└─────────────┘     └─────────────┘     └─────────────┘
       ▲                   ▲                   ▲
       └──────────Jolteon BFT Consensus────────┘
```

## Configuration

### Environment Variables

Edit `.env` or create `.env.local`:

| Variable | Default | Description |
|----------|---------|-------------|
| `CHAIN_ID` | 52001 | Unique chain identifier |
| `CHAIN_NAME` | iCreditChain-Private | Human-readable name |
| `NUM_VALIDATORS` | 3 | Number of genesis validators |
| `EPOCH_DURATION_SECS` | 3600 | Epoch length (seconds) |
| `ALLOW_NEW_VALIDATORS` | false | Allow validator enrollment after genesis |
| `REWARDS_APY_PERCENTAGE` | 0 | Staking rewards APY |
| `API_PORT_0` | 8090 | Validator 0 REST API port |

### Validator Configuration

Each validator has its own config file in `configs/`:

- `configs/validator-0.yaml` — Primary validator
- `configs/validator-1.yaml` — Validator 1
- `configs/validator-2.yaml` — Validator 2

Key settings:
- `base.data_dir` — Data storage path
- `validator_network` — P2P networking with mutual TLS
- `api` — REST API configuration
- `storage` — RocksDB pruning configuration

## Management

```bash
# View logs
docker compose logs -f

# View specific validator
docker compose logs -f validator0

# Stop network
docker compose down

# Destroy and recreate
./scripts/deploy.sh --reset

# Check health
curl http://localhost:8090/-/healthy
```

## REST API

Each validator exposes the standard CreditChain REST API:

```bash
# Get ledger info
curl http://localhost:8090/v1

# Get account balance
curl http://localhost:8090/v1/accounts/{address}/resources

# Submit transaction
curl -X POST http://localhost:8090/v1/transactions \
  -H "Content-Type: application/json" \
  -d @transaction.json
```

## Directory Structure

```
deploy/private/
├── docker-compose.yaml          # 3-validator + genesis orchestration
├── .env                         # Private mode defaults
├── .env.consortium              # Consortium mode overrides
├── configs/
│   ├── validator-0.yaml         # Validator 0 node config
│   ├── validator-1.yaml         # Validator 1 node config
│   └── validator-2.yaml         # Validator 2 node config
├── scripts/
│   ├── deploy.sh                # Full deployment script
│   └── init-genesis.sh          # Genesis initialization (runs in container)
└── README.md
```

## Integration with OpeniBank

iCreditChain serves as the settlement layer for OpeniBank v4:

1. **openibank-chain** crate handles private chain operations
2. Transfer receipts are anchored to iCreditChain for finality
3. Cross-institution settlement uses iCreditChain consensus
4. Multi-stablecoin support (iUSD, iEUR, iJPY, iGBP, iCNY, iCAD)

## License

Apache 2.0
