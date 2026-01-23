// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DeployAll, DeployFactory, DeployImplementation } from "../../script/Deploy.s.sol";
import { DeploymentManager } from "../../script/utils/DeploymentManager.sol";
import { MinimalSmartAccount } from "../../src/MinimalSmartAccount.sol";
import { IRegistry } from "../../src/interfaces/IRegistry.sol";
import { BaseTest, MockRegistry } from "./BaseTest.t.sol";
import { MinimalUUPSFactory } from "minimal-uups-factory/MinimalUUPSFactory.sol";

/// @title DeploymentBaseTest
/// @notice Base test contract that uses deployment scripts for setup
/// @dev Provides full protocol deployment for integration tests
abstract contract DeploymentBaseTest is BaseTest {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       DEPLOYMENT SCRIPTS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    DeployAll public deployAll;
    DeployImplementation public deployImplementation;
    DeployFactory public deployFactory;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      DEPLOYED CONTRACTS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    MinimalSmartAccount public implementation;
    MinimalUUPSFactory public factory;
    MinimalSmartAccount public account;
    MockRegistry public registry;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CONFIGURATION                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    string public constant DEFAULT_ACCOUNT_ID = "minimal-smart-account.v1";
    bytes32 public constant DEFAULT_SALT = bytes32(uint256(1));

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          SETUP                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function setUp() public virtual {
        _createUsers();
        _deployProtocol();
    }

    /// @notice Deploy the full protocol using deployment scripts
    function _deployProtocol() internal {
        // Deploy mock registry
        registry = new MockRegistry();

        // Initialize deployment scripts with verbose=false and writeToJson=false for tests
        deployAll = new DeployAll();
        deployAll.setVerbose(false);
        deployAll.setWriteToJson(false);

        deployImplementation = new DeployImplementation();
        deployImplementation.setVerbose(false);
        deployImplementation.setWriteToJson(false);

        deployFactory = new DeployFactory();
        deployFactory.setVerbose(false);
        deployFactory.setWriteToJson(false);

        // Create config for deployment
        DeploymentManager.NetworkConfig memory config = DeploymentManager.NetworkConfig({
            salt: "0x0000000000000000000000000000000000000000000000000000000000000001",
            owner: owner,
            deployer: deployer,
            accountId: DEFAULT_ACCOUNT_ID,
            registry: address(registry),
            factory: address(0) // Deploy new factory
        });

        // Deploy implementation and factory
        vm.startPrank(deployer);
        DeploymentManager.DeploymentOutput memory output = deployAll.deploy(config);
        vm.stopPrank();

        implementation = MinimalSmartAccount(payable(output.implementation));
        factory = MinimalUUPSFactory(output.factory);

        // Deploy proxy
        bytes32 fullSalt = _createSalt(deployer, 1);
        bytes memory initData =
            abi.encodeCall(MinimalSmartAccount.initialize, (owner, IRegistry(address(registry)), DEFAULT_ACCOUNT_ID));

        vm.startPrank(deployer);
        address proxyAddr = factory.deployDeterministicAndCall(address(implementation), fullSalt, initData);
        vm.stopPrank();

        account = MinimalSmartAccount(payable(proxyAddr));
    }

    /// @notice Deploy only implementation and factory (no proxy)
    function _deployInfrastructure() internal {
        // Deploy mock registry
        registry = new MockRegistry();

        // Initialize deployment scripts with verbose=false and writeToJson=false for tests
        deployImplementation = new DeployImplementation();
        deployImplementation.setVerbose(false);
        deployImplementation.setWriteToJson(false);

        deployFactory = new DeployFactory();
        deployFactory.setVerbose(false);
        deployFactory.setWriteToJson(false);

        // Deploy implementation
        vm.startPrank(deployer);
        address implAddr = deployImplementation.deploy();
        vm.stopPrank();
        implementation = MinimalSmartAccount(payable(implAddr));

        // Deploy factory
        vm.startPrank(deployer);
        address factoryAddr = deployFactory.deploy(DEFAULT_SALT);
        vm.stopPrank();
        factory = MinimalUUPSFactory(factoryAddr);
    }

    /// @notice Deploy a new proxy with custom parameters
    /// @param _owner The owner of the new proxy
    /// @param salt The unique salt identifier (will be combined with deployer address)
    function _deployNewProxy(address _owner, bytes32 salt) internal returns (MinimalSmartAccount) {
        bytes32 fullSalt = _createSalt(deployer, uint96(uint256(salt)));
        bytes memory initData =
            abi.encodeCall(MinimalSmartAccount.initialize, (_owner, IRegistry(address(registry)), DEFAULT_ACCOUNT_ID));

        vm.startPrank(deployer);
        address proxyAddr = factory.deployDeterministicAndCall(address(implementation), fullSalt, initData);
        vm.stopPrank();

        return MinimalSmartAccount(payable(proxyAddr));
    }
}
