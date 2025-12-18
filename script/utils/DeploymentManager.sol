// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

/// @title DeploymentManager
/// @notice Utility contract for managing deployment configurations and outputs
/// @dev Provides JSON config reading, output writing, and network detection utilities
abstract contract DeploymentManager is Script {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Single-chain network configuration
    struct NetworkConfig {
        string salt;
        address owner;
        address deployer;
        string accountId;
        address registry;
    }

    /// @notice Multi-chain deployment configuration
    struct MultiChainConfig {
        string salt;
        address owner;
        address deployer;
        string accountId;
        ChainConfig[] chains;
    }

    /// @notice Per-chain configuration for multi-chain deployments
    struct ChainConfig {
        string name;
        uint256 chainId;
        string rpcEnvVar;
        string etherscanApiKeyEnvVar;
        bool verify;
        address registry;
    }

    /// @notice Deployment output containing deployed contract addresses
    struct DeploymentOutput {
        uint256 chainId;
        string network;
        uint256 timestamp;
        address implementation;
        address factory;
        address proxy;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      CONFIG READING                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Reads single-chain network configuration from JSON
    /// @param network The network name (localhost, sepolia, etc.)
    /// @return config The parsed network configuration
    function readNetworkConfig(string memory network) internal view returns (NetworkConfig memory config) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/config/", network, ".json");
        string memory json = vm.readFile(path);

        config.salt = vm.parseJsonString(json, ".deployment.salt");
        config.owner = vm.parseJsonAddress(json, ".roles.owner");
        config.deployer = vm.parseJsonAddress(json, ".roles.deployer");
        config.accountId = vm.parseJsonString(json, ".account.accountId");
        config.registry = vm.parseJsonAddress(json, ".external.registry");
    }

    /// @notice Reads multi-chain deployment configuration from mainnet.json
    /// @return config The parsed multi-chain configuration
    function readMainnetConfig() internal view returns (MultiChainConfig memory config) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/config/mainnet.json");
        string memory json = vm.readFile(path);

        config.salt = vm.parseJsonString(json, ".deployment.salt");
        config.owner = vm.parseJsonAddress(json, ".roles.owner");
        config.deployer = vm.parseJsonAddress(json, ".roles.deployer");
        config.accountId = vm.parseJsonString(json, ".account.accountId");

        // Parse chains array
        bytes memory chainsRaw = vm.parseJson(json, ".chains");
        ChainConfig[] memory chains = abi.decode(chainsRaw, (ChainConfig[]));
        config.chains = chains;
    }

    /// @notice Gets chain-specific config for the current network from mainnet.json
    /// @return chainConfig The chain configuration for current block.chainid
    function getChainConfigForCurrentNetwork() internal view returns (ChainConfig memory chainConfig) {
        MultiChainConfig memory config = readMainnetConfig();

        for (uint256 i = 0; i < config.chains.length; i++) {
            if (config.chains[i].chainId == block.chainid) {
                return config.chains[i];
            }
        }

        revert("Chain not found in mainnet.json config");
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      OUTPUT WRITING                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Reads existing deployment output for a network
    /// @param network The network name
    /// @return output The deployment output (zeroed if file doesn't exist)
    function readDeploymentOutput(string memory network) internal view returns (DeploymentOutput memory output) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/output/", network, "/addresses.json");

        try vm.readFile(path) returns (string memory json) {
            if (bytes(json).length > 0) {
                output.chainId = vm.parseJsonUint(json, ".chainId");
                output.network = vm.parseJsonString(json, ".network");
                output.timestamp = vm.parseJsonUint(json, ".timestamp");
                output.implementation = vm.parseJsonAddress(json, ".contracts.implementation");
                output.factory = vm.parseJsonAddress(json, ".contracts.factory");
                output.proxy = vm.parseJsonAddress(json, ".contracts.proxy");
            }
        } catch {
            // File doesn't exist, return empty output
        }
    }

    /// @notice Writes deployment output to JSON file
    /// @param network The network name
    /// @param output The deployment output to write
    function writeDeploymentOutput(string memory network, DeploymentOutput memory output) internal {
        string memory root = vm.projectRoot();
        string memory dirPath = string.concat(root, "/deployments/output/", network);
        string memory filePath = string.concat(dirPath, "/addresses.json");

        // Create directory if it doesn't exist
        vm.createDir(dirPath, true);

        // Build JSON manually for proper formatting
        string memory json = string.concat(
            "{\n",
            '  "chainId": ',
            vm.toString(output.chainId),
            ",\n",
            '  "network": "',
            output.network,
            '",\n',
            '  "timestamp": ',
            vm.toString(output.timestamp),
            ",\n",
            '  "contracts": {\n',
            '    "implementation": "',
            vm.toString(output.implementation),
            '",\n',
            '    "factory": "',
            vm.toString(output.factory),
            '",\n',
            '    "proxy": "',
            vm.toString(output.proxy),
            '"\n',
            "  }\n",
            "}"
        );

        vm.writeFile(filePath, json);
    }

    /// @notice Updates a single contract address in the deployment output
    /// @param network The network name
    /// @param contractName The contract name (implementation, factory, or proxy)
    /// @param contractAddress The deployed address
    function writeContractAddress(string memory network, string memory contractName, address contractAddress) internal {
        DeploymentOutput memory output = readDeploymentOutput(network);

        // Update the specific field
        if (keccak256(bytes(contractName)) == keccak256("implementation")) {
            output.implementation = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256("factory")) {
            output.factory = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256("proxy")) {
            output.proxy = contractAddress;
        }

        // Update metadata
        output.chainId = block.chainid;
        output.network = network;
        output.timestamp = block.timestamp;

        writeDeploymentOutput(network, output);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     NETWORK DETECTION                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Returns the network name for the current chain ID
    /// @return name The network name string
    function getNetworkName() internal view returns (string memory name) {
        if (block.chainid == 1) return "mainnet";
        if (block.chainid == 11_155_111) return "sepolia";
        if (block.chainid == 31_337) return "localhost";
        if (block.chainid == 42_161) return "arbitrum";
        if (block.chainid == 10) return "optimism";
        if (block.chainid == 8453) return "base";
        if (block.chainid == 137) return "polygon";
        if (block.chainid == 43_114) return "avalanche";
        if (block.chainid == 56) return "bnb";
        if (block.chainid == 130) return "unichain";
        return "unknown";
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        UTILITIES                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Computes the full salt with deployer address prefix
    /// @param deployer The deployer address
    /// @param salt The custom salt (12 bytes used)
    /// @return fullSalt The combined salt for CREATE2
    function computeFullSalt(address deployer, bytes32 salt) internal pure returns (bytes32 fullSalt) {
        fullSalt = bytes32(uint256(uint160(deployer))) | (salt >> 160);
    }

    /// @notice Logs network configuration details
    /// @param config The network configuration to log
    function logConfig(NetworkConfig memory config) internal pure {
        console.log("\n=== Network Configuration ===");
        console.log("Salt:", config.salt);
        console.log("Owner:", config.owner);
        console.log("Deployer:", config.deployer);
        console.log("Account ID:", config.accountId);
        console.log("Registry:", config.registry);
    }

    /// @notice Logs deployment output details
    /// @param output The deployment output to log
    function logDeployment(DeploymentOutput memory output) internal pure {
        console.log("\n=== Deployment Output ===");
        console.log("Chain ID:", output.chainId);
        console.log("Network:", output.network);
        console.log("Timestamp:", output.timestamp);
        console.log("Implementation:", output.implementation);
        console.log("Factory:", output.factory);
        console.log("Proxy:", output.proxy);
    }
}
