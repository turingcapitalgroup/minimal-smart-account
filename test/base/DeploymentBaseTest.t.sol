// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DeployAll, DeployFactory, DeployImplementation } from "../../script/Deploy.s.sol";
import { DeploymentManager } from "../../script/utils/DeploymentManager.sol";
import { MinimalSmartAccount } from "../../src/MinimalSmartAccount.sol";
import { MinimalSmartAccountFactory } from "../../src/MinimalSmartAccountFactory.sol";
import { IRegistry } from "../../src/interfaces/IRegistry.sol";
import { BaseTest, MockRegistry } from "./BaseTest.t.sol";

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
    MinimalSmartAccountFactory public factory;
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

        // Initialize deployment scripts with verbose=false
        deployAll = new DeployAll();
        deployAll.setVerbose(false);

        deployImplementation = new DeployImplementation();
        deployImplementation.setVerbose(false);

        deployFactory = new DeployFactory();
        deployFactory.setVerbose(false);

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
        factory = MinimalSmartAccountFactory(output.factory);

        // Deploy proxy - must call factory directly from deployer because factory checks msg.sender
        bytes32 fullSalt = _createSalt(deployer, 1);

        vm.startPrank(deployer);
        address proxyAddr = factory.deployDeterministic(
            address(implementation), fullSalt, owner, IRegistry(address(registry)), DEFAULT_ACCOUNT_ID
        );
        vm.stopPrank();

        account = MinimalSmartAccount(payable(proxyAddr));
    }

    /// @notice Deploy only implementation and factory (no proxy)
    function _deployInfrastructure() internal {
        // Deploy mock registry
        registry = new MockRegistry();

        // Initialize deployment scripts with verbose=false
        deployImplementation = new DeployImplementation();
        deployImplementation.setVerbose(false);

        deployFactory = new DeployFactory();
        deployFactory.setVerbose(false);

        // Deploy implementation
        vm.startPrank(deployer);
        address implAddr = deployImplementation.deploy();
        vm.stopPrank();
        implementation = MinimalSmartAccount(payable(implAddr));

        // Deploy factory
        vm.startPrank(deployer);
        address factoryAddr = deployFactory.deploy(DEFAULT_SALT);
        vm.stopPrank();
        factory = MinimalSmartAccountFactory(factoryAddr);
    }

    /// @notice Deploy a new proxy with custom parameters
    /// @param _owner The owner of the new proxy
    /// @param salt The unique salt identifier (will be combined with deployer address)
    function _deployNewProxy(address _owner, bytes32 salt) internal returns (MinimalSmartAccount) {
        bytes32 fullSalt = _createSalt(deployer, uint96(uint256(salt)));

        vm.startPrank(deployer);
        address proxyAddr = factory.deployDeterministic(
            address(implementation), fullSalt, _owner, IRegistry(address(registry)), DEFAULT_ACCOUNT_ID
        );
        vm.stopPrank();

        return MinimalSmartAccount(payable(proxyAddr));
    }
}
