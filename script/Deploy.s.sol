// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { MinimalSmartAccount } from "../src/MinimalSmartAccount.sol";
import { MinimalSmartAccountFactory } from "../src/MinimalSmartAccountFactory.sol";
import { IRegistry } from "../src/interfaces/IRegistry.sol";
import { DeploymentManager } from "./utils/DeploymentManager.sol";

/// @title DeployAll
/// @notice Deploys all contracts (implementation + factory) for a single chain
/// @dev Reads config from deployments/config/{network}.json and writes output
///      If factory is address(0) in config, deploys a new one
contract DeployAll is DeploymentManager {
    function run() external returns (DeploymentOutput memory output) {
        string memory network = getNetworkName();
        NetworkConfig memory config = readNetworkConfig(network);

        _log("=== Deploying MinimalSmartAccount ===");
        _log("Network:", network);
        _log("Chain ID:", block.chainid);
        logConfig(config);

        vm.startBroadcast();

        // Deploy implementation
        address implementation = address(new MinimalSmartAccount());
        _log("\nImplementation deployed at:", implementation);

        // Deploy factory or use existing
        address factory;
        if (config.factory == address(0)) {
            bytes32 salt = vm.parseBytes32(config.salt);
            factory = address(new MinimalSmartAccountFactory{ salt: salt }());
            _log("Factory deployed at:", factory);
        } else {
            factory = config.factory;
            _log("Using existing factory:", factory);
        }

        vm.stopBroadcast();

        // Write deployment output
        output = DeploymentOutput({
            chainId: block.chainid,
            network: network,
            accountId: config.accountId,
            timestamp: block.timestamp,
            implementation: implementation,
            factory: factory,
            proxy: address(0)
        });
        writeDeploymentOutput(network, output);

        _log("\n=== Deployment Complete ===");
    }

    /// @notice Deploy all contracts with custom config (for testing)
    /// @param config The network configuration to use
    /// @return output The deployment output
    function deploy(NetworkConfig memory config) external returns (DeploymentOutput memory output) {
        _log("=== Deploying MinimalSmartAccount ===");
        logConfig(config);

        // Deploy implementation
        address implementation = address(new MinimalSmartAccount());
        _log("Implementation deployed at:", implementation);

        // Deploy factory or use existing
        address factory;
        if (config.factory == address(0)) {
            bytes32 salt = vm.parseBytes32(config.salt);
            factory = address(new MinimalSmartAccountFactory{ salt: salt }());
            _log("Factory deployed at:", factory);
        } else {
            factory = config.factory;
            _log("Using existing factory:", factory);
        }

        output = DeploymentOutput({
            chainId: block.chainid,
            network: "test",
            accountId: config.accountId,
            timestamp: block.timestamp,
            implementation: implementation,
            factory: factory,
            proxy: address(0)
        });

        _log("\n=== Deployment Complete ===");
    }
}

/// @title DeployImplementation
/// @notice Deploys only the MinimalSmartAccount implementation
contract DeployImplementation is DeploymentManager {
    function run() external returns (address implementation) {
        string memory network = getNetworkName();

        _log("=== Deploying Implementation ===");
        _log("Network:", network);
        _log("Chain ID:", block.chainid);

        vm.startBroadcast();
        implementation = address(new MinimalSmartAccount());
        vm.stopBroadcast();

        _log("Implementation deployed at:", implementation);

        // Note: Implementation deployments don't have accountId context
        // They are shared across all accounts on the network
    }

    /// @notice Deploy implementation (for testing)
    function deploy() external returns (address implementation) {
        implementation = address(new MinimalSmartAccount());
        _log("Implementation deployed at:", implementation);
    }
}

/// @title DeployFactory
/// @notice Deploys only the MinimalSmartAccountFactory
contract DeployFactory is DeploymentManager {
    function run() external returns (address factory) {
        string memory network = getNetworkName();
        NetworkConfig memory config = readNetworkConfig(network);

        _log("=== Deploying Factory ===");
        _log("Network:", network);
        _log("Chain ID:", block.chainid);

        vm.startBroadcast();
        bytes32 salt = vm.parseBytes32(config.salt);
        factory = address(new MinimalSmartAccountFactory{ salt: salt }());
        vm.stopBroadcast();

        _log("Factory deployed at:", factory);

        // Note: Factory deployments don't have accountId context
        // They are shared across all accounts on the network
    }

    /// @notice Deploy factory with salt (for testing)
    function deploy(bytes32 salt) external returns (address factory) {
        factory = address(new MinimalSmartAccountFactory{ salt: salt }());
        _log("Factory deployed at:", factory);
    }
}

/// @title DeployProxy
/// @notice Deploys a new MinimalSmartAccount proxy using the factory
contract DeployProxy is DeploymentManager {
    function run() external returns (address proxy) {
        string memory network = getNetworkName();
        NetworkConfig memory config = readNetworkConfig(network);
        DeploymentOutput memory existing = readDeploymentOutput(network, config.accountId);

        require(existing.factory != address(0), "Factory not deployed. Run deploy-all first.");
        require(existing.implementation != address(0), "Implementation not deployed. Run deploy-all first.");

        _log("=== Deploying Proxy ===");
        _log("Network:", network);
        _log("Chain ID:", block.chainid);
        _log("Factory:", existing.factory);
        _log("Implementation:", existing.implementation);
        _log("Owner:", config.owner);

        MinimalSmartAccountFactory factory = MinimalSmartAccountFactory(existing.factory);

        // Compute full salt
        bytes32 salt = vm.parseBytes32(config.salt);
        bytes32 fullSalt = computeFullSalt(config.deployer, salt);

        // Predict address before deployment
        address predictedAddress = factory.predictDeterministicAddress(fullSalt);
        _log("Predicted proxy address:", predictedAddress);

        vm.startBroadcast();
        proxy = factory.deployDeterministic(
            existing.implementation, fullSalt, config.owner, IRegistry(config.registry), config.accountId
        );
        vm.stopBroadcast();

        _log("Proxy deployed at:", proxy);
        require(proxy == predictedAddress, "Address mismatch!");

        writeContractAddress(network, config.accountId, "proxy", proxy);
    }

    /// @notice Deploy proxy with custom parameters (for testing)
    function deploy(
        address factoryAddr,
        address implementation,
        bytes32 salt,
        address owner,
        IRegistry registry,
        string memory accountId
    )
        external
        returns (address proxy)
    {
        MinimalSmartAccountFactory factory = MinimalSmartAccountFactory(factoryAddr);
        proxy = factory.deployDeterministic(implementation, salt, owner, registry, accountId);
        _log("Proxy deployed at:", proxy);
    }
}

/// @title DeployMainnet
/// @notice Deploys all contracts for mainnet multi-chain deployment
/// @dev Called by deploy-mainnet.sh for each chain
contract DeployMainnet is DeploymentManager {
    function run() external {
        MultiChainConfig memory config = readMainnetConfig();
        ChainConfig memory chainConfig = getChainConfigForCurrentNetwork();

        _log("=== Mainnet Deployment ===");
        _log("Network:", chainConfig.name);
        _log("Chain ID:", block.chainid);
        _log("Owner:", config.owner);
        _log("Deployer:", config.deployer);
        _log("Registry:", chainConfig.registry);

        vm.startBroadcast();

        // Deploy implementation
        address implementation = address(new MinimalSmartAccount());
        _log("\nImplementation deployed at:", implementation);

        // Deploy factory or use existing
        address factory;
        bytes32 salt = vm.parseBytes32(config.salt);
        if (chainConfig.factory == address(0)) {
            factory = address(new MinimalSmartAccountFactory{ salt: salt }());
            _log("Factory deployed at:", factory);
        } else {
            factory = chainConfig.factory;
            _log("Using existing factory:", factory);
        }

        // Deploy proxy
        MinimalSmartAccountFactory factoryContract = MinimalSmartAccountFactory(factory);
        bytes32 fullSalt = computeFullSalt(config.deployer, salt);

        address proxy = factoryContract.deployDeterministic(
            implementation, fullSalt, config.owner, IRegistry(chainConfig.registry), config.accountId
        );
        _log("Proxy deployed at:", proxy);

        vm.stopBroadcast();

        // Write deployment output
        DeploymentOutput memory output = DeploymentOutput({
            chainId: block.chainid,
            network: chainConfig.name,
            accountId: config.accountId,
            timestamp: block.timestamp,
            implementation: implementation,
            factory: factory,
            proxy: proxy
        });
        writeDeploymentOutput(chainConfig.name, output);

        _log("\n=== Deployment Complete ===");
    }
}
