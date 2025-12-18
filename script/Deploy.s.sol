// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { MinimalSmartAccount } from "../src/MinimalSmartAccount.sol";
import { MinimalSmartAccountFactory } from "../src/MinimalSmartAccountFactory.sol";
import { IRegistry } from "../src/interfaces/IRegistry.sol";
import { DeploymentManager } from "./utils/DeploymentManager.sol";
import { Script, console } from "forge-std/Script.sol";

/// @title DeployAll
/// @notice Deploys all contracts (implementation + factory) for a single chain
/// @dev Reads config from deployments/config/{network}.json and writes output
contract DeployAll is DeploymentManager {
    function run() external {
        string memory network = getNetworkName();
        NetworkConfig memory config = readNetworkConfig(network);

        console.log("=== Deploying MinimalSmartAccount ===");
        console.log("Network:", network);
        console.log("Chain ID:", block.chainid);
        logConfig(config);

        vm.startBroadcast();

        // Deploy implementation
        address implementation = address(new MinimalSmartAccount());
        console.log("\nImplementation deployed at:", implementation);

        // Deploy factory with CREATE2
        bytes32 salt = vm.parseBytes32(config.salt);
        address factory = address(new MinimalSmartAccountFactory{ salt: salt }());
        console.log("Factory deployed at:", factory);

        vm.stopBroadcast();

        // Write deployment output
        DeploymentOutput memory output = DeploymentOutput({
            chainId: block.chainid,
            network: network,
            timestamp: block.timestamp,
            implementation: implementation,
            factory: factory,
            proxy: address(0)
        });
        writeDeploymentOutput(network, output);

        console.log("\n=== Deployment Complete ===");
        console.log("Output written to: deployments/output/", network, "/addresses.json");
    }
}

/// @title DeployImplementation
/// @notice Deploys only the MinimalSmartAccount implementation
contract DeployImplementation is DeploymentManager {
    function run() external returns (address implementation) {
        string memory network = getNetworkName();

        console.log("=== Deploying Implementation ===");
        console.log("Network:", network);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast();
        implementation = address(new MinimalSmartAccount());
        vm.stopBroadcast();

        console.log("Implementation deployed at:", implementation);

        writeContractAddress(network, "implementation", implementation);
    }
}

/// @title DeployFactory
/// @notice Deploys only the MinimalSmartAccountFactory
contract DeployFactory is DeploymentManager {
    function run() external returns (address factory) {
        string memory network = getNetworkName();
        NetworkConfig memory config = readNetworkConfig(network);

        console.log("=== Deploying Factory ===");
        console.log("Network:", network);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast();
        bytes32 salt = vm.parseBytes32(config.salt);
        factory = address(new MinimalSmartAccountFactory{ salt: salt }());
        vm.stopBroadcast();

        console.log("Factory deployed at:", factory);

        writeContractAddress(network, "factory", factory);
    }
}

/// @title DeployProxy
/// @notice Deploys a new MinimalSmartAccount proxy using the factory
contract DeployProxy is DeploymentManager {
    function run() external returns (address proxy) {
        string memory network = getNetworkName();
        NetworkConfig memory config = readNetworkConfig(network);
        DeploymentOutput memory existing = readDeploymentOutput(network);

        require(existing.factory != address(0), "Factory not deployed. Run deploy-all first.");
        require(existing.implementation != address(0), "Implementation not deployed. Run deploy-all first.");

        console.log("=== Deploying Proxy ===");
        console.log("Network:", network);
        console.log("Chain ID:", block.chainid);
        console.log("Factory:", existing.factory);
        console.log("Implementation:", existing.implementation);
        console.log("Owner:", config.owner);

        MinimalSmartAccountFactory factory = MinimalSmartAccountFactory(existing.factory);

        // Compute full salt
        bytes32 salt = vm.parseBytes32(config.salt);
        bytes32 fullSalt = computeFullSalt(config.deployer, salt);

        // Predict address before deployment
        address predictedAddress = factory.predictDeterministicAddress(fullSalt);
        console.log("Predicted proxy address:", predictedAddress);

        vm.startBroadcast();
        proxy = factory.deployDeterministic(
            existing.implementation,
            config.deployer,
            fullSalt,
            config.owner,
            IRegistry(config.registry),
            config.accountId
        );
        vm.stopBroadcast();

        console.log("Proxy deployed at:", proxy);
        require(proxy == predictedAddress, "Address mismatch!");

        writeContractAddress(network, "proxy", proxy);
    }
}

/// @title DeployMainnet
/// @notice Deploys all contracts for mainnet multi-chain deployment
/// @dev Called by deploy-mainnet.sh for each chain
contract DeployMainnet is DeploymentManager {
    function run() external {
        MultiChainConfig memory config = readMainnetConfig();
        ChainConfig memory chainConfig = getChainConfigForCurrentNetwork();

        console.log("=== Mainnet Deployment ===");
        console.log("Network:", chainConfig.name);
        console.log("Chain ID:", block.chainid);
        console.log("Owner:", config.owner);
        console.log("Deployer:", config.deployer);
        console.log("Registry:", chainConfig.registry);

        vm.startBroadcast();

        // Deploy implementation
        address implementation = address(new MinimalSmartAccount());
        console.log("\nImplementation deployed at:", implementation);

        // Deploy factory with CREATE2
        bytes32 salt = vm.parseBytes32(config.salt);
        address factory = address(new MinimalSmartAccountFactory{ salt: salt }());
        console.log("Factory deployed at:", factory);

        // Deploy proxy
        MinimalSmartAccountFactory factoryContract = MinimalSmartAccountFactory(factory);
        bytes32 fullSalt = computeFullSalt(config.deployer, salt);

        address proxy = factoryContract.deployDeterministic(
            implementation, config.deployer, fullSalt, config.owner, IRegistry(chainConfig.registry), config.accountId
        );
        console.log("Proxy deployed at:", proxy);

        vm.stopBroadcast();

        // Write deployment output
        DeploymentOutput memory output = DeploymentOutput({
            chainId: block.chainid,
            network: chainConfig.name,
            timestamp: block.timestamp,
            implementation: implementation,
            factory: factory,
            proxy: proxy
        });
        writeDeploymentOutput(chainConfig.name, output);

        console.log("\n=== Deployment Complete ===");
    }
}
