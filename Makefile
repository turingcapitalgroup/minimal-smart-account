# Minimal Smart Account - Makefile
# Multi-chain deployment automation

-include .env

.PHONY: all build test clean deploy-all deploy-mainnet deploy-testnets verify help

# Default target
all: build test

# =============================================================================
# BUILD & TEST
# =============================================================================

## Build the project
build:
	forge build

## Run tests
test:
	forge test -vvv

## Run tests with gas reporting
test-gas:
	forge test -vvv --gas-report

## Run coverage
coverage:
	forge coverage

## Format code
fmt:
	forge fmt

## Check formatting
fmt-check:
	forge fmt --check

## Clean build artifacts
clean:
	forge clean

## Install dependencies
install:
	forge soldeer install

# =============================================================================
# DEPLOYMENT - TESTNETS
# =============================================================================

## Deploy to Sepolia
deploy-sepolia:
	@echo "Deploying to Sepolia..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url sepolia \
		--broadcast \
		--verify \
		-vvvv

## Deploy to Arbitrum Sepolia
deploy-arbitrum-sepolia:
	@echo "Deploying to Arbitrum Sepolia..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url arbitrum_sepolia \
		--broadcast \
		--verify \
		-vvvv

## Deploy to Optimism Sepolia
deploy-optimism-sepolia:
	@echo "Deploying to Optimism Sepolia..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url optimism_sepolia \
		--broadcast \
		--verify \
		-vvvv

## Deploy to Base Sepolia
deploy-base-sepolia:
	@echo "Deploying to Base Sepolia..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url base_sepolia \
		--broadcast \
		--verify \
		-vvvv

## Deploy to Polygon Amoy
deploy-polygon-amoy:
	@echo "Deploying to Polygon Amoy..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url polygon_amoy \
		--broadcast \
		--verify \
		-vvvv

## Deploy to Avalanche Fuji
deploy-avalanche-fuji:
	@echo "Deploying to Avalanche Fuji..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url avalanche_fuji \
		--broadcast \
		--verify \
		-vvvv

## Deploy to BSC Testnet
deploy-bsc-testnet:
	@echo "Deploying to BSC Testnet..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url bsc_testnet \
		--broadcast \
		--verify \
		-vvvv

## Deploy to all testnets
deploy-testnets: deploy-sepolia deploy-arbitrum-sepolia deploy-optimism-sepolia deploy-base-sepolia deploy-polygon-amoy deploy-avalanche-fuji deploy-bsc-testnet
	@echo "Deployed to all testnets!"

# =============================================================================
# DEPLOYMENT - MAINNETS
# =============================================================================

## Deploy to Ethereum Mainnet
deploy-mainnet:
	@echo "Deploying to Ethereum Mainnet..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url mainnet \
		--broadcast \
		--verify \
		-vvvv

## Deploy to Arbitrum
deploy-arbitrum:
	@echo "Deploying to Arbitrum..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url arbitrum \
		--broadcast \
		--verify \
		-vvvv

## Deploy to Optimism
deploy-optimism:
	@echo "Deploying to Optimism..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url optimism \
		--broadcast \
		--verify \
		-vvvv

## Deploy to Base
deploy-base:
	@echo "Deploying to Base..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url base \
		--broadcast \
		--verify \
		-vvvv

## Deploy to Polygon
deploy-polygon:
	@echo "Deploying to Polygon..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url polygon \
		--broadcast \
		--verify \
		-vvvv

## Deploy to Avalanche
deploy-avalanche:
	@echo "Deploying to Avalanche..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url avalanche \
		--broadcast \
		--verify \
		-vvvv

## Deploy to BSC
deploy-bsc:
	@echo "Deploying to BSC..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url bsc \
		--broadcast \
		--verify \
		-vvvv

## Deploy to all mainnets
deploy-mainnets: deploy-mainnet deploy-arbitrum deploy-optimism deploy-base deploy-polygon deploy-avalanche deploy-bsc
	@echo "Deployed to all mainnets!"

# =============================================================================
# DEPLOYMENT - ALL CHAINS
# =============================================================================

## Deploy to all chains (testnets first, then mainnets)
deploy-all: deploy-testnets deploy-mainnets
	@echo "Deployed to all chains!"

# =============================================================================
# PROXY DEPLOYMENT
# =============================================================================

## Deploy a proxy on Sepolia (requires FACTORY_ADDRESS, IMPLEMENTATION_ADDRESS, REGISTRY_ADDRESS)
deploy-proxy-sepolia:
	@echo "Deploying proxy to Sepolia..."
	forge script script/Deploy.s.sol:DeployProxy \
		--rpc-url sepolia \
		--broadcast \
		-vvvv

## Deploy a proxy on Mainnet (requires FACTORY_ADDRESS, IMPLEMENTATION_ADDRESS, REGISTRY_ADDRESS)
deploy-proxy-mainnet:
	@echo "Deploying proxy to Mainnet..."
	forge script script/Deploy.s.sol:DeployProxy \
		--rpc-url mainnet \
		--broadcast \
		-vvvv

# =============================================================================
# UTILITIES
# =============================================================================

## Predict proxy address (requires FACTORY_ADDRESS, DEPLOYER_ADDRESS)
predict-address:
	@forge script script/Deploy.s.sol:PredictProxyAddress -vvvv

## Dry run deployment (no broadcast)
dry-run:
	@echo "Dry run deployment..."
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url sepolia \
		-vvvv

## Show contract sizes
sizes:
	forge build --sizes

## Generate gas snapshot
snapshot:
	forge snapshot

# =============================================================================
# HELP
# =============================================================================

## Show this help
help:
	@echo "Minimal Smart Account - Makefile Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Build & Test:"
	@echo "  build              Build the project"
	@echo "  test               Run tests"
	@echo "  test-gas           Run tests with gas reporting"
	@echo "  coverage           Run coverage"
	@echo "  fmt                Format code"
	@echo "  fmt-check          Check formatting"
	@echo "  clean              Clean build artifacts"
	@echo "  install            Install dependencies"
	@echo ""
	@echo "Testnet Deployments:"
	@echo "  deploy-sepolia           Deploy to Sepolia"
	@echo "  deploy-arbitrum-sepolia  Deploy to Arbitrum Sepolia"
	@echo "  deploy-optimism-sepolia  Deploy to Optimism Sepolia"
	@echo "  deploy-base-sepolia      Deploy to Base Sepolia"
	@echo "  deploy-polygon-amoy      Deploy to Polygon Amoy"
	@echo "  deploy-avalanche-fuji    Deploy to Avalanche Fuji"
	@echo "  deploy-bsc-testnet       Deploy to BSC Testnet"
	@echo "  deploy-testnets          Deploy to all testnets"
	@echo ""
	@echo "Mainnet Deployments:"
	@echo "  deploy-mainnet     Deploy to Ethereum Mainnet"
	@echo "  deploy-arbitrum    Deploy to Arbitrum"
	@echo "  deploy-optimism    Deploy to Optimism"
	@echo "  deploy-base        Deploy to Base"
	@echo "  deploy-polygon     Deploy to Polygon"
	@echo "  deploy-avalanche   Deploy to Avalanche"
	@echo "  deploy-bsc         Deploy to BSC"
	@echo "  deploy-mainnets    Deploy to all mainnets"
	@echo ""
	@echo "All Chains:"
	@echo "  deploy-all         Deploy to all chains"
	@echo ""
	@echo "Proxy Deployment:"
	@echo "  deploy-proxy-sepolia   Deploy proxy on Sepolia"
	@echo "  deploy-proxy-mainnet   Deploy proxy on Mainnet"
	@echo ""
	@echo "Utilities:"
	@echo "  predict-address    Predict proxy address"
	@echo "  dry-run            Dry run deployment"
	@echo "  sizes              Show contract sizes"
	@echo "  snapshot           Generate gas snapshot"
	@echo ""
	@echo "Environment Variables Required:"
	@echo "  PRIVATE_KEY              Deployer private key"
	@echo "  *_RPC_URL                RPC endpoints for each chain"
	@echo "  *_API_KEY                Block explorer API keys"
	@echo ""
	@echo "For proxy deployment also set:"
	@echo "  FACTORY_ADDRESS          Factory contract address"
	@echo "  IMPLEMENTATION_ADDRESS   Implementation contract address"
	@echo "  REGISTRY_ADDRESS         Registry contract address"
	@echo "  OWNER_ADDRESS            (optional) Account owner"
	@echo "  ACCOUNT_ID               (optional) Account identifier"
	@echo "  DEPLOY_SALT              (optional) Custom salt for CREATE2"
