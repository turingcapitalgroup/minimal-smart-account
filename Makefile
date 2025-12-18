# MinimalSmartAccount Makefile
# ============================

-include .env

.PHONY: all build test clean fmt coverage snapshot gas-report \
        deploy-localhost deploy-sepolia deploy-mainnet \
        deploy-localhost-dry-run deploy-sepolia-dry-run \
        deploy-impl-localhost deploy-impl-sepolia \
        deploy-factory-localhost deploy-factory-sepolia \
        deploy-proxy-localhost deploy-proxy-sepolia \
        predict-localhost predict-sepolia predict-mainnet predict-factory \
        validate-mainnet \
        anvil help

# ==============================================================================
# Build & Test
# ==============================================================================

all: clean build test

build:
	forge build

build-fast:
	forge build --use $$(which solx)

test:
	forge test -vvv

test-gas:
	forge test -vvv --gas-report

clean:
	forge clean

fmt:
	forge fmt

fmt-check:
	forge fmt --check

coverage:
	forge coverage

snapshot:
	forge snapshot

sizes:
	forge build --sizes

install:
	forge soldeer install

# ==============================================================================
# Local Development (Anvil)
# ==============================================================================

anvil:
	anvil

# Deploy all contracts to localhost (anvil)
# Uses default anvil private key
deploy-localhost:
	forge script script/Deploy.s.sol:DeployAll \
		--rpc-url http://localhost:8545 \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		--broadcast \
		--ffi

# Deploy only implementation to localhost
deploy-impl-localhost:
	forge script script/Deploy.s.sol:DeployImplementation \
		--rpc-url http://localhost:8545 \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		--broadcast \
		--ffi

# Deploy only factory to localhost
deploy-factory-localhost:
	forge script script/Deploy.s.sol:DeployFactory \
		--rpc-url http://localhost:8545 \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		--broadcast \
		--ffi

# Deploy proxy using existing factory on localhost
deploy-proxy-localhost:
	forge script script/Deploy.s.sol:DeployProxy \
		--rpc-url http://localhost:8545 \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		--broadcast \
		--ffi

# Dry-run: simulate deployment without broadcasting
deploy-localhost-dry-run:
	forge script script/Deploy.s.sol:DeployAll \
		--rpc-url http://localhost:8545 \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		--ffi

# ==============================================================================
# Testnet Deployment (Sepolia)
# ==============================================================================

# Deploy all contracts to Sepolia
# Requires: keyDeployer account in forge keystore
deploy-sepolia:
	forge script script/Deploy.s.sol:DeployAll \
		--rpc-url sepolia \
		--account keyDeployer \
		--broadcast \
		--verify \
		--ffi

# Deploy only implementation to Sepolia
deploy-impl-sepolia:
	forge script script/Deploy.s.sol:DeployImplementation \
		--rpc-url sepolia \
		--account keyDeployer \
		--broadcast \
		--verify \
		--ffi

# Deploy only factory to Sepolia
deploy-factory-sepolia:
	forge script script/Deploy.s.sol:DeployFactory \
		--rpc-url sepolia \
		--account keyDeployer \
		--broadcast \
		--verify \
		--ffi

# Deploy proxy using existing factory on Sepolia
deploy-proxy-sepolia:
	forge script script/Deploy.s.sol:DeployProxy \
		--rpc-url sepolia \
		--account keyDeployer \
		--broadcast \
		--verify \
		--ffi

# Dry-run: simulate deployment without broadcasting
deploy-sepolia-dry-run:
	forge script script/Deploy.s.sol:DeployAll \
		--rpc-url sepolia \
		--account keyDeployer \
		--ffi

# ==============================================================================
# Mainnet Multi-Chain Deployment
# ==============================================================================

# Validate mainnet configuration before deployment
validate-mainnet:
	forge script script/helpers/PredictAddress.s.sol:ValidateMainnetConfig --ffi

# Deploy to all chains configured in deployments/config/mainnet.json
# Requires: keyDeployer account and RPC URLs for all chains
deploy-mainnet:
	./script/deploy-mainnet.sh

# ==============================================================================
# Address Prediction
# ==============================================================================

# Predict proxy address on localhost
predict-localhost:
	forge script script/helpers/PredictAddress.s.sol:PredictProxyAddress \
		--rpc-url http://localhost:8545 \
		--ffi

# Predict proxy address on Sepolia
predict-sepolia:
	forge script script/helpers/PredictAddress.s.sol:PredictProxyAddress \
		--rpc-url sepolia \
		--ffi

# Predict addresses for mainnet multi-chain deployment
predict-mainnet:
	forge script script/helpers/PredictAddress.s.sol:PredictMainnetAddress --ffi

# Predict factory address before deployment
predict-factory:
	forge script script/helpers/PredictAddress.s.sol:PredictFactoryAddress --ffi

# ==============================================================================
# Help
# ==============================================================================

help:
	@echo "MinimalSmartAccount Makefile"
	@echo "============================"
	@echo ""
	@echo "Build & Test:"
	@echo "  make build          - Build contracts"
	@echo "  make build-fast     - Build with solx (faster)"
	@echo "  make test           - Run tests"
	@echo "  make test-gas       - Run tests with gas report"
	@echo "  make fmt            - Format code"
	@echo "  make coverage       - Generate coverage report"
	@echo "  make sizes          - Show contract sizes"
	@echo ""
	@echo "Local Development (Anvil):"
	@echo "  make anvil                    - Start local Anvil node"
	@echo "  make deploy-localhost         - Deploy all to localhost"
	@echo "  make deploy-localhost-dry-run - Simulate deploy (no broadcast)"
	@echo "  make deploy-impl-localhost    - Deploy implementation only"
	@echo "  make deploy-factory-localhost - Deploy factory only"
	@echo "  make deploy-proxy-localhost   - Deploy proxy only"
	@echo ""
	@echo "Testnet (Sepolia):"
	@echo "  make deploy-sepolia           - Deploy all to Sepolia"
	@echo "  make deploy-sepolia-dry-run   - Simulate deploy (no broadcast)"
	@echo "  make deploy-impl-sepolia      - Deploy implementation only"
	@echo "  make deploy-factory-sepolia   - Deploy factory only"
	@echo "  make deploy-proxy-sepolia     - Deploy proxy only"
	@echo ""
	@echo "Mainnet Multi-Chain:"
	@echo "  make validate-mainnet  - Validate mainnet.json config"
	@echo "  make deploy-mainnet    - Deploy to all configured chains"
	@echo ""
	@echo "Address Prediction:"
	@echo "  make predict-localhost - Predict proxy on localhost"
	@echo "  make predict-sepolia   - Predict proxy on Sepolia"
	@echo "  make predict-mainnet   - Show mainnet chain configs"
	@echo "  make predict-factory   - Predict factory address"
	@echo ""
	@echo "Configuration:"
	@echo "  - Edit deployments/config/localhost.json for local testing"
	@echo "  - Edit deployments/config/sepolia.json for testnet"
	@echo "  - Edit deployments/config/mainnet.json for production multi-chain"
	@echo ""
	@echo "Outputs saved to: deployments/output/<network>/<accountId>.json"
