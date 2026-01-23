# Minimal Smart Account

A minimal, gas-efficient smart account implementation with batch execution capabilities, registry-based authorization, and multi-chain deployment support.

## Features

- **Batch Execution**: Execute multiple transactions in a single call
- **Execution Modes**: Support for DEFAULT (revert on failure) and TRY (continue on failure) modes
- **Registry Authorization**: Flexible authorization system via external registry contract
- **UUPS Upgradeable**: Secure upgrade pattern with owner-controlled upgrades
- **Role-Based Access Control**: Admin and Executor roles for granular permissions
- **Multi-Chain Deployment**: Deploy to the same address across multiple EVM chains using CREATE2
- **Token Support**: Receive ETH, ERC721, and ERC1155 tokens

## Architecture

```
src/
├── MinimalSmartAccount.sol        # Main smart account implementation
├── interfaces/
│   ├── IMinimalSmartAccount.sol   # Account interface
│   └── IRegistry.sol              # Registry interface
├── libraries/
│   ├── ExecutionLib.sol           # Execution decoding utilities
│   └── ModeLib.sol                # Mode encoding/decoding
└── vendor/                        # Vendored dependencies

dependencies/
└── factory-1.0/                   # MinimalUUPSFactory (soldeer dependency)
```

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd minimal-smart-account

# Install dependencies
make install
# or
forge soldeer install
```

## Build & Test

```bash
# Build
make build

# Build (fast, using solx compiler)
make build-fast

# Run tests
make test

# Run tests with gas reporting
make test-gas

# Format code
make fmt
make fmt-check  # Check formatting without modifying

# Check contract sizes
make sizes

# Generate coverage report
make coverage

# Generate gas snapshot
make snapshot

# Clean build artifacts
make clean
```

## Configuration

1. Copy the example environment file:

```bash
cp .env.example .env
```

2. Configure your `.env` file with:
   - `PRIVATE_KEY`: Your deployer private key
   - RPC endpoints for desired chains
   - Block explorer API keys for verification

## Deployment

### Local Development (Anvil)

Start a local node and deploy:

```bash
# Start local Anvil node
make anvil

# Deploy all contracts (implementation + factory)
make deploy-localhost

# Or deploy individual components
make deploy-impl-localhost     # Implementation only
make deploy-factory-localhost  # Factory only
make deploy-proxy-localhost    # Proxy instance (requires factory)

# Dry-run (simulate without broadcasting)
make deploy-localhost-dry-run
```

### Testnet Deployment (Sepolia)

Deploy to Sepolia testnet (requires `keyDeployer` account in forge keystore):

```bash
# Deploy all contracts
make deploy-sepolia

# Or deploy individual components
make deploy-impl-sepolia     # Implementation only
make deploy-factory-sepolia  # Factory only
make deploy-proxy-sepolia    # Proxy instance

# Dry-run
make deploy-sepolia-dry-run
```

### Multi-Chain Mainnet Deployment

Deploy to all chains configured in `deployments/config/mainnet.json`:

```bash
# Validate configuration before deployment
make validate-mainnet

# Deploy to all configured chains
make deploy-mainnet
```

### Address Prediction

Predict deployment addresses before deploying:

```bash
# Predict proxy address
make predict-localhost  # On localhost
make predict-sepolia    # On Sepolia
make predict-mainnet    # Show all mainnet chain configs

# Predict factory address
make predict-factory
```

### Deployment Configuration

Configuration files are located in `deployments/config/`:

- `localhost.json` - Local development settings
- `sepolia.json` - Testnet configuration
- `mainnet.json` - Multi-chain mainnet configuration

Deployment outputs are saved to `deployments/output/<network>/<accountId>.json`

## Usage

### Initialization

```solidity
MinimalSmartAccount account = new MinimalSmartAccount();
account.initialize(owner, registry, "my-account.v1");
```

### Batch Execution

```solidity
import { Execution } from "./interfaces/IMinimalSmartAccount.sol";
import { ModeLib } from "./libraries/ModeLib.sol";
import { ExecutionLib } from "./libraries/ExecutionLib.sol";

// Create batch execution
Execution[] memory executions = new Execution[](2);
executions[0] = Execution({
    target: targetAddress1,
    value: 0,
    callData: abi.encodeCall(ITarget.someFunction, (arg1, arg2))
});
executions[1] = Execution({
    target: targetAddress2,
    value: 1 ether,
    callData: abi.encodeCall(ITarget.anotherFunction, ())
});

// Encode and execute
bytes memory executionData = ExecutionLib.encodeBatch(executions);
account.execute(ModeLib.encodeSimpleBatch(), executionData);
```

### Execution Modes

```solidity
// DEFAULT mode: reverts if any execution fails
ModeCode defaultMode = ModeLib.encodeSimpleBatch();

// TRY mode: continues even if individual executions fail
ModeCode tryMode = ModeLib.encode(
    CALLTYPE_BATCH,
    EXECTYPE_TRY,
    MODE_DEFAULT,
    ModePayload.wrap(0x00)
);
```

## Roles

| Role | ID | Permissions |
|------|------------|-------------|
| Owner | - | Upgrade contract, grant/revoke roles |
| Admin | `_ROLE_0` | Administrative operations |
| Executor | `_ROLE_1` | Execute transactions |

## Registry Integration

The smart account validates all executions through an external registry contract that implements `IRegistry`:

```solidity
interface IRegistry {
    function authorizeCall(
        address target,
        bytes4 selector,
        bytes calldata params
    ) external;

    function isSelectorAllowed(
        address executor,
        address target,
        bytes4 selector
    ) external view returns (bool);
}
```

## Supported Chains

| Chain | Testnet | Mainnet |
|-------|---------|---------|
| Ethereum | Sepolia | Mainnet |
| Arbitrum | Arbitrum Sepolia | Arbitrum One |
| Optimism | Optimism Sepolia | Optimism |
| Base | Base Sepolia | Base |
| Polygon | Polygon Amoy | Polygon |
| Avalanche | Fuji | Avalanche C-Chain |
| BSC | BSC Testnet | BSC |

## Security Considerations

- The contract uses ERC-7201 namespaced storage pattern for upgrade safety
- All executions are validated through the registry before execution
- Only addresses with `EXECUTOR_ROLE` can call `execute()`
- Only the owner can authorize upgrades
- The factory uses CREATE2 for deterministic proxy deployments

## Gas Optimization

- Assembly-optimized batch decoding from Solady
- Minimal proxy pattern for gas-efficient deployments
- Optimized storage layout using ERC-7201

## License

MIT
