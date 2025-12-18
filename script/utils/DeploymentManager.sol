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
        address factory;
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
        address factory;
    }

    /// @notice Deployment output containing deployed contract addresses
    struct DeploymentOutput {
        uint256 chainId;
        string network;
        string accountId;
        uint256 timestamp;
        address implementation;
        address factory;
        address proxy;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      SCRIPT OPTIONS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Controls verbose logging (default: true for scripts, false for tests)
    bool public verbose = true;

    /// @notice Controls whether to write deployment output to JSON (default: true for scripts, false for tests)
    bool public writeToJson = true;

    /// @notice Sets the verbose logging flag
    /// @param _verbose Whether to enable verbose logging
    function setVerbose(bool _verbose) public {
        verbose = _verbose;
    }

    /// @notice Sets the writeToJson flag
    /// @param _writeToJson Whether to write deployment output to JSON files
    function setWriteToJson(bool _writeToJson) public {
        writeToJson = _writeToJson;
    }

    /// @notice Log a message (only if verbose)
    function _log(string memory message) internal view {
        if (verbose) console.log(message);
    }

    /// @notice Log a message with an address (only if verbose)
    function _log(string memory message, address value) internal view {
        if (verbose) console.log(message, value);
    }

    /// @notice Log a message with a uint256 (only if verbose)
    function _log(string memory message, uint256 value) internal view {
        if (verbose) console.log(message, value);
    }

    /// @notice Log a message with a string (only if verbose)
    function _log(string memory message, string memory value) internal view {
        if (verbose) console.log(message, value);
    }

    /// @notice Log a message with a bytes32 (only if verbose)
    function _log(string memory message, bytes32 value) internal view {
        if (verbose) console.log(message, vm.toString(value));
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
        config.factory = vm.parseJsonAddress(json, ".external.factory");
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

    /// @notice Reads existing deployment output for a network and accountId
    /// @param network The network name
    /// @param accountId The account identifier
    /// @return output The deployment output (zeroed if file doesn't exist)
    function readDeploymentOutput(
        string memory network,
        string memory accountId
    )
        internal
        view
        returns (DeploymentOutput memory output)
    {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/output/", network, "/", accountId, ".json");

        try vm.readFile(path) returns (string memory json) {
            if (bytes(json).length > 0) {
                output.chainId = vm.parseJsonUint(json, ".chainId");
                output.network = vm.parseJsonString(json, ".network");
                output.accountId = vm.parseJsonString(json, ".accountId");
                output.timestamp = vm.parseJsonUint(json, ".timestamp");
                output.implementation = vm.parseJsonAddress(json, ".contracts.implementation");
                output.factory = vm.parseJsonAddress(json, ".contracts.factory");
                output.proxy = vm.parseJsonAddress(json, ".contracts.proxy");
            }
        } catch {
            // File doesn't exist, return empty output
        }
    }

    /// @notice Writes deployment output to JSON file (only if writeToJson is true)
    /// @dev File path: deployments/output/{network}/{accountId}.json
    /// @param network The network name
    /// @param output The deployment output to write
    function writeDeploymentOutput(string memory network, DeploymentOutput memory output) internal {
        if (!writeToJson) return;

        string memory root = vm.projectRoot();
        string memory dirPath = string.concat(root, "/deployments/output/", network);
        string memory filePath = string.concat(dirPath, "/", output.accountId, ".json");

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
            '  "accountId": "',
            output.accountId,
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

    /// @notice Updates a single contract address in the deployment output (only if writeToJson is true)
    /// @param network The network name
    /// @param accountId The account identifier
    /// @param contractName The contract name (implementation, factory, or proxy)
    /// @param contractAddress The deployed address
    function writeContractAddress(
        string memory network,
        string memory accountId,
        string memory contractName,
        address contractAddress
    )
        internal
    {
        if (!writeToJson) return;

        DeploymentOutput memory output = readDeploymentOutput(network, accountId);

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
        output.accountId = accountId;
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

    /// @notice Logs network configuration details (only if verbose)
    /// @param config The network configuration to log
    function logConfig(NetworkConfig memory config) internal view {
        _log("\n=== Network Configuration ===");
        _log("Salt:", config.salt);
        _log("Owner:", config.owner);
        _log("Deployer:", config.deployer);
        _log("Account ID:", config.accountId);
        _log("Registry:", config.registry);
        _log("Factory:", config.factory);
    }

    /// @notice Logs deployment output details (only if verbose)
    /// @param output The deployment output to log
    function logDeployment(DeploymentOutput memory output) internal view {
        _log("\n=== Deployment Output ===");
        _log("Chain ID:", output.chainId);
        _log("Network:", output.network);
        _log("Timestamp:", output.timestamp);
        _log("Implementation:", output.implementation);
        _log("Factory:", output.factory);
        _log("Proxy:", output.proxy);
    }
}
