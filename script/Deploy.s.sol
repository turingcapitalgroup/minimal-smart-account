// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { MinimalSmartAccount } from "../src/MinimalSmartAccount.sol";
import { MinimalSmartAccountFactory } from "../src/MinimalSmartAccountFactory.sol";
import { IRegistry } from "../src/interfaces/IRegistry.sol";
import { Script, console } from "forge-std/Script.sol";

/// @title Deploy
/// @notice Deployment script for MinimalSmartAccount and MinimalSmartAccountFactory
/// @dev Supports deterministic deployment across multiple chains using CREATE2
contract Deploy is Script {
    /// @notice The salt used for deterministic deployment (same across all chains)
    bytes32 public constant FACTORY_SALT = bytes32(uint256(0x1));

    /// @notice Deployed contract addresses
    address public implementation;
    address public factory;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation contract
        implementation = address(new MinimalSmartAccount());
        console.log("MinimalSmartAccount implementation deployed at:", implementation);

        // Deploy factory contract using CREATE2 for deterministic address
        factory = address(new MinimalSmartAccountFactory{ salt: FACTORY_SALT }());
        console.log("MinimalSmartAccountFactory deployed at:", factory);

        vm.stopBroadcast();

        // Log predicted addresses for verification
        console.log("\n=== Deployment Summary ===");
        console.log("Implementation:", implementation);
        console.log("Factory:", factory);
    }
}

/// @title DeployImplementation
/// @notice Deploys only the MinimalSmartAccount implementation
contract DeployImplementation is Script {
    function run() external returns (address implementation) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);
        implementation = address(new MinimalSmartAccount());
        vm.stopBroadcast();

        console.log("MinimalSmartAccount implementation deployed at:", implementation);
    }
}

/// @title DeployFactory
/// @notice Deploys only the MinimalSmartAccountFactory
contract DeployFactory is Script {
    bytes32 public constant FACTORY_SALT = bytes32(uint256(0x1));

    function run() external returns (address factory) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);
        factory = address(new MinimalSmartAccountFactory{ salt: FACTORY_SALT }());
        vm.stopBroadcast();

        console.log("MinimalSmartAccountFactory deployed at:", factory);
    }
}

/// @title DeployProxy
/// @notice Deploys a new MinimalSmartAccount proxy using the factory
contract DeployProxy is Script {
    function run() external returns (address proxy) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Configuration from environment variables
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        address implementationAddress = vm.envAddress("IMPLEMENTATION_ADDRESS");
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        address owner = vm.envOr("OWNER_ADDRESS", deployer);
        string memory accountId = vm.envOr("ACCOUNT_ID", string("minimal-smart-account.v1"));
        bytes32 salt = bytes32(vm.envOr("DEPLOY_SALT", uint256(0)));

        // Encode caller address into salt for CREATE2
        bytes32 fullSalt = bytes32(uint256(uint160(deployer))) | (salt >> 160);

        console.log("Chain ID:", block.chainid);
        console.log("Factory:", factoryAddress);
        console.log("Implementation:", implementationAddress);
        console.log("Owner:", owner);

        MinimalSmartAccountFactory factory = MinimalSmartAccountFactory(factoryAddress);

        // Predict the address before deployment
        address predictedAddress = factory.predictDeterministicAddress(fullSalt);
        console.log("Predicted proxy address:", predictedAddress);

        vm.startBroadcast(deployerPrivateKey);
        proxy = factory.deployDeterministic(
            implementationAddress, deployer, fullSalt, owner, IRegistry(registryAddress), accountId
        );
        vm.stopBroadcast();

        console.log("Proxy deployed at:", proxy);
        require(proxy == predictedAddress, "Address mismatch!");
    }
}

/// @title PredictProxyAddress
/// @notice Predicts the address of a proxy without deploying
contract PredictProxyAddress is Script {
    function run() external view {
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        bytes32 salt = bytes32(vm.envOr("DEPLOY_SALT", uint256(0)));

        // Encode caller address into salt for CREATE2
        bytes32 fullSalt = bytes32(uint256(uint160(deployer))) | (salt >> 160);

        MinimalSmartAccountFactory factory = MinimalSmartAccountFactory(factoryAddress);
        address predictedAddress = factory.predictDeterministicAddress(fullSalt);

        console.log("Factory:", factoryAddress);
        console.log("Deployer:", deployer);
        console.log("Salt:", vm.toString(salt));
        console.log("Predicted proxy address:", predictedAddress);
    }
}
