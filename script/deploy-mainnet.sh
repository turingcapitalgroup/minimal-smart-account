#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  MinimalSmartAccount Mainnet Deployer  ${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install with: sudo pacman -S jq (Arch) or sudo apt install jq (Ubuntu)"
    exit 1
fi

# Path to config
CONFIG_FILE="deployments/config/mainnet.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Config file not found at $CONFIG_FILE${NC}"
    exit 1
fi

# Read chains from config
CHAINS=$(jq -r '.chains[] | @base64' "$CONFIG_FILE")
TOTAL_CHAINS=$(echo "$CHAINS" | wc -l)

echo -e "\n${YELLOW}Configuration loaded from: $CONFIG_FILE${NC}"
echo -e "Total chains to deploy: $TOTAL_CHAINS"

# Validate configuration first
echo -e "\n${BLUE}Step 1: Validating configuration...${NC}"
forge script script/helpers/PredictAddress.s.sol:ValidateMainnetConfig --ffi

read -p "Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled.${NC}"
    exit 0
fi

# Track results
SUCCESSFUL=()
FAILED=()

# Deploy to each chain
echo -e "\n${BLUE}Step 2: Deploying to chains...${NC}"

for chain in $CHAINS; do
    # Decode chain config
    _jq() {
        echo "${chain}" | base64 --decode | jq -r "${1}"
    }

    NAME=$(_jq '.name')
    CHAIN_ID=$(_jq '.chainId')
    RPC_ENV_VAR=$(_jq '.rpcEnvVar')
    ETHERSCAN_ENV_VAR=$(_jq '.etherscanApiKeyEnvVar')
    VERIFY=$(_jq '.verify')

    echo -e "\n${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}Deploying to: $NAME (Chain ID: $CHAIN_ID)${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"

    # Get RPC URL from environment
    RPC_URL="${!RPC_ENV_VAR}"
    if [ -z "$RPC_URL" ]; then
        echo -e "${RED}Error: $RPC_ENV_VAR not set${NC}"
        FAILED+=("$NAME")
        continue
    fi

    # Build verification args
    VERIFY_ARGS=""
    if [ "$VERIFY" = "true" ]; then
        ETHERSCAN_KEY="${!ETHERSCAN_ENV_VAR}"
        if [ -n "$ETHERSCAN_KEY" ]; then
            VERIFY_ARGS="--verify --etherscan-api-key $ETHERSCAN_KEY"
        else
            echo -e "${YELLOW}Warning: $ETHERSCAN_ENV_VAR not set, skipping verification${NC}"
        fi
    fi

    # Run deployment
    if forge script script/Deploy.s.sol:DeployMainnet \
        --rpc-url "$RPC_URL" \
        --account keyDeployer \
        --broadcast \
        --ffi \
        $VERIFY_ARGS; then

        echo -e "${GREEN}Successfully deployed to $NAME${NC}"
        SUCCESSFUL+=("$NAME")

        # Format output JSON
        OUTPUT_FILE="deployments/output/$NAME/addresses.json"
        if [ -f "$OUTPUT_FILE" ]; then
            jq '.' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
        fi
    else
        echo -e "${RED}Failed to deploy to $NAME${NC}"
        FAILED+=("$NAME")
    fi
done

# Print summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}           Deployment Summary           ${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${GREEN}Successful deployments (${#SUCCESSFUL[@]}/${TOTAL_CHAINS}):${NC}"
for chain in "${SUCCESSFUL[@]}"; do
    echo -e "  - $chain"
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "\n${RED}Failed deployments (${#FAILED[@]}/${TOTAL_CHAINS}):${NC}"
    for chain in "${FAILED[@]}"; do
        echo -e "  - $chain"
    done
fi

echo -e "\n${BLUE}Deployment outputs saved to: deployments/output/<chain>/addresses.json${NC}"

# Exit with error if any deployments failed
if [ ${#FAILED[@]} -gt 0 ]; then
    exit 1
fi
