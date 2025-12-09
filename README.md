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
├── MinimalSmartAccountFactory.sol # Factory for deterministic deployments
├── interfaces/
│   ├── IMinimalSmartAccount.sol   # Account interface
│   └── IRegistry.sol              # Registry interface
├── libraries/
│   ├── ExecutionLib.sol           # Execution decoding utilities
│   └── ModeLib.sol                # Mode encoding/decoding
└── vendor/                        # Vendored dependencies
```

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd minimal-smart-account

# Install dependencies
forge soldeer install
```

## Build & Test

```bash
# Build
make build

# Run tests
make test

# Run tests with gas reporting
make test-gas

# Format code
make fmt

# Check contract sizes
make sizes
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

### Single Chain Deployment

Deploy to a specific chain:

```bash
# Testnets
make deploy-sepolia
make deploy-arbitrum-sepolia
make deploy-optimism-sepolia
make deploy-base-sepolia

# Mainnets
make deploy-mainnet
make deploy-arbitrum
make deploy-optimism
make deploy-base
```

### Multi-Chain Deployment

Deploy to all testnets or mainnets:

```bash
# All testnets
make deploy-testnets

# All mainnets
make deploy-mainnets

# All chains
make deploy-all
```

### Proxy Deployment

After deploying the factory and implementation, deploy individual account proxies:

```bash
# Set required environment variables
export FACTORY_ADDRESS=0x...
export IMPLEMENTATION_ADDRESS=0x...
export REGISTRY_ADDRESS=0x...

# Deploy proxy
make deploy-proxy-sepolia
```

### Predict Address

Predict the deployment address before deploying:

```bash
export FACTORY_ADDRESS=0x...
export DEPLOYER_ADDRESS=0x...
make predict-address
```

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
    function authorizeAdapterCall(
        address target,
        bytes4 selector,
        bytes calldata params
    ) external;

    function isAdapterSelectorAllowed(
        address adapter,
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
- The factory uses CREATE2 with caller-prefixed salts to prevent front-running

## Gas Optimization

- Assembly-optimized batch decoding from Solady
- Minimal proxy pattern for gas-efficient deployments
- Optimized storage layout using ERC-7201

## License

MIT
