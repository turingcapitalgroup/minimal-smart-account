// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { console } from "forge-std/console.sol";
import { MinimalUUPSFactory } from "minimal-uups-factory/MinimalUUPSFactory.sol";

/// @title PredictProxyAddress
/// @notice Predicts the proxy address for a single-chain deployment without deploying
contract PredictProxyAddress is DeploymentManager {
    function run() external view {
        string memory network = getNetworkName();
        NetworkConfig memory config = readNetworkConfig(network);
        DeploymentOutput memory existing = readDeploymentOutput(network, config.accountId);

        require(existing.factory != address(0), "Factory not deployed. Run deploy-all first.");

        console.log("=== Predict Proxy Address ===");
        console.log("Network:", network);
        console.log("Chain ID:", block.chainid);
        console.log("Factory:", existing.factory);

        MinimalUUPSFactory factory = MinimalUUPSFactory(existing.factory);

        // Compute full salt
        bytes32 salt = vm.parseBytes32(config.salt);
        bytes32 fullSalt = computeFullSalt(config.deployer, salt);

        address predictedAddress = factory.predictDeterministicAddress(existing.implementation, fullSalt);

        console.log("\n=== Prediction Result ===");
        console.log("Deployer:", config.deployer);
        console.log("Salt:", config.salt);
        console.log("Predicted Proxy Address:", predictedAddress);
    }
}

/// @title PredictMainnetAddress
/// @notice Predicts proxy addresses across all mainnet chains
/// @dev Useful for verifying deterministic addresses before multi-chain deployment
contract PredictMainnetAddress is DeploymentManager {
    function run() external view {
        MultiChainConfig memory config = readMainnetConfig();

        console.log("=== Predict Mainnet Addresses ===");
        console.log("Owner:", config.owner);
        console.log("Deployer:", config.deployer);
        console.log("Salt:", config.salt);
        console.log("Account ID:", config.accountId);

        bytes32 salt = vm.parseBytes32(config.salt);
        bytes32 fullSalt = computeFullSalt(config.deployer, salt);

        console.log("\n=== Chain Configurations ===");
        for (uint256 i = 0; i < config.chains.length; i++) {
            ChainConfig memory chain = config.chains[i];
            console.log("\n---", chain.name, "---");
            console.log("Chain ID:", chain.chainId);
            console.log("Registry:", chain.registry);
            console.log("Verify:", chain.verify);
        }

        console.log("\n=== Note ===");
        console.log("Proxy addresses will be deterministic across all chains");
        console.log("if the same factory is deployed to the same address on each chain.");
        console.log("Full Salt:", vm.toString(fullSalt));
    }
}

/// @title ValidateMainnetConfig
/// @notice Validates the mainnet.json configuration before deployment
contract ValidateMainnetConfig is DeploymentManager {
    function run() external view {
        MultiChainConfig memory config = readMainnetConfig();

        console.log("=== Validating Mainnet Configuration ===");

        // Validate global config
        bool hasErrors = false;

        if (config.owner == address(0)) {
            console.log("ERROR: Owner address not set");
            hasErrors = true;
        } else {
            console.log("Owner:", config.owner);
        }

        if (config.deployer == address(0)) {
            console.log("ERROR: Deployer address not set");
            hasErrors = true;
        } else {
            console.log("Deployer:", config.deployer);
        }

        if (bytes(config.salt).length == 0) {
            console.log("ERROR: Salt not set");
            hasErrors = true;
        } else {
            console.log("Salt:", config.salt);
        }

        if (bytes(config.accountId).length == 0) {
            console.log("ERROR: Account ID not set");
            hasErrors = true;
        } else {
            console.log("Account ID:", config.accountId);
        }

        console.log("\n=== Chain Validation ===");
        console.log("Total chains:", config.chains.length);

        for (uint256 i = 0; i < config.chains.length; i++) {
            ChainConfig memory chain = config.chains[i];
            console.log("\n---", chain.name, "---");
            console.log("  Chain ID:", chain.chainId);

            if (chain.registry == address(0)) {
                console.log("  WARNING: Registry not set for", chain.name);
            } else {
                console.log("  Registry:", chain.registry);
            }

            if (bytes(chain.rpcEnvVar).length == 0) {
                console.log("  ERROR: RPC env var not set");
                hasErrors = true;
            }

            if (chain.verify && bytes(chain.etherscanApiKeyEnvVar).length == 0) {
                console.log("  WARNING: Etherscan API key env var not set but verify=true");
            }
        }

        console.log("\n=== Validation Result ===");
        if (hasErrors) {
            console.log("FAILED: Fix errors before deploying");
        } else {
            console.log("PASSED: Configuration is valid");
        }
    }
}

/// @title PredictFactoryAddress
/// @notice Predicts the factory address before deployment
contract PredictFactoryAddress is DeploymentManager {
    function run() external view {
        string memory network = getNetworkName();
        NetworkConfig memory config = readNetworkConfig(network);

        console.log("=== Predict Factory Address ===");
        console.log("Network:", network);
        console.log("Deployer:", config.deployer);
        console.log("Salt:", config.salt);

        bytes32 salt = vm.parseBytes32(config.salt);

        // Factory is deployed with CREATE2 from deployer address
        // The predicted address depends on deployer nonce for CREATE, or salt for CREATE2
        bytes32 initCodeHash = keccak256(type(MinimalUUPSFactory).creationCode);

        address predictedFactory =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), config.deployer, salt, initCodeHash)))));

        console.log("\n=== Prediction Result ===");
        console.log("Init Code Hash:", vm.toString(initCodeHash));
        console.log("Predicted Factory Address:", predictedFactory);
    }
}
