// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IRegistry, MinimalSmartAccount } from "../src/MinimalSmartAccount.sol";
import { MinimalSmartAccountFactory } from "../src/MinimalSmartAccountFactory.sol";
import { Test } from "forge-std/Test.sol";

contract MockRegistry is IRegistry {
    function authorizeAdapterCall(address, bytes4, bytes calldata) external pure override { }

    function isAdapterSelectorAllowed(address, address, bytes4) external pure override returns (bool) {
        return true;
    }
}

contract MinimalSmartAccountFactoryTest is Test {
    MinimalSmartAccountFactory factory;
    MinimalSmartAccount implementation;
    MockRegistry registry;

    address owner = address(0xABCD);
    address admin = address(0xBEEF);

    function setUp() public {
        factory = new MinimalSmartAccountFactory();
        implementation = new MinimalSmartAccount();
        registry = new MockRegistry();
    }

    /// @dev Helper to create a salt that starts with the caller's address
    function _createSalt(uint96 uniqueId) internal view returns (bytes32) {
        return bytes32(uint256(uint160(address(this))) << 96) | bytes32(uint256(uniqueId));
    }

    function testDeployDeterministic() public {
        bytes32 salt = _createSalt(1);

        address predicted = factory.predictDeterministicAddress(salt);

        address proxy =
            factory.deployDeterministic(address(implementation), admin, salt, owner, registry, "test-account");

        assertEq(proxy, predicted, "Address mismatch");
        assertEq(factory.adminOf(proxy), admin, "Admin mismatch");

        // Verify initialization
        MinimalSmartAccount account = MinimalSmartAccount(payable(proxy));
        assertEq(account.accountId(), "test-account");
        assertEq(account.owner(), owner);
    }

    function testDeployDeterministicSameAddressWithSameSalt() public {
        bytes32 salt = _createSalt(2);

        address proxy1 =
            factory.deployDeterministic(address(implementation), admin, salt, owner, registry, "test-account-1");

        // Deploying with same salt should fail
        vm.expectRevert(MinimalSmartAccountFactory.DeploymentFailed.selector);
        factory.deployDeterministic(address(implementation), admin, salt, owner, registry, "test-account-2");

        // Verify first deployment worked
        assertEq(MinimalSmartAccount(payable(proxy1)).accountId(), "test-account-1");
    }

    function testDeployDeterministicDifferentSaltsDifferentAddresses() public {
        bytes32 salt1 = _createSalt(3);
        bytes32 salt2 = _createSalt(4);

        address proxy1 =
            factory.deployDeterministic(address(implementation), admin, salt1, owner, registry, "test-account-1");
        address proxy2 =
            factory.deployDeterministic(address(implementation), admin, salt2, owner, registry, "test-account-2");

        assertTrue(proxy1 != proxy2, "Addresses should be different");
    }

    function testSaltMustStartWithCaller() public {
        // Salt that starts with a different address (0xDEAD shifted to high bits)
        bytes32 badSalt = bytes32(uint256(uint160(address(0xDEAD))) << 96);

        vm.expectRevert(MinimalSmartAccountFactory.SaltDoesNotStartWithCaller.selector);
        factory.deployDeterministic(address(implementation), admin, badSalt, owner, registry, "test-account");
    }

    function testSaltCanStartWithZeroAddress() public {
        // Salt that starts with zero address (low 96 bits only) is allowed
        bytes32 zeroSalt = bytes32(uint256(1));

        address proxy =
            factory.deployDeterministic(address(implementation), admin, zeroSalt, owner, registry, "test-account");

        assertTrue(proxy != address(0), "Deployment should succeed");
    }

    function testChangeAdmin() public {
        bytes32 salt = _createSalt(5);
        address proxy =
            factory.deployDeterministic(address(implementation), address(this), salt, owner, registry, "test-account");

        assertEq(factory.adminOf(proxy), address(this));

        address newAdmin = address(0x1234);
        factory.changeAdmin(proxy, newAdmin);

        assertEq(factory.adminOf(proxy), newAdmin);
    }

    function testChangeAdminUnauthorized() public {
        bytes32 salt = _createSalt(6);
        address proxy =
            factory.deployDeterministic(address(implementation), admin, salt, owner, registry, "test-account");

        // Try to change admin from non-admin account
        vm.expectRevert(MinimalSmartAccountFactory.Unauthorized.selector);
        factory.changeAdmin(proxy, address(0x1234));
    }

    function testUpgrade() public {
        bytes32 salt = _createSalt(7);
        address proxy =
            factory.deployDeterministic(address(implementation), address(this), salt, owner, registry, "test-account");

        // Deploy new implementation
        MinimalSmartAccount newImpl = new MinimalSmartAccount();

        // Upgrade
        factory.upgrade(proxy, address(newImpl));

        // Verify proxy still works
        MinimalSmartAccount account = MinimalSmartAccount(payable(proxy));
        assertEq(account.accountId(), "test-account");
    }

    function testUpgradeUnauthorized() public {
        bytes32 salt = _createSalt(8);
        address proxy =
            factory.deployDeterministic(address(implementation), admin, salt, owner, registry, "test-account");

        MinimalSmartAccount newImpl = new MinimalSmartAccount();

        // Try to upgrade from non-admin account
        vm.expectRevert(MinimalSmartAccountFactory.Unauthorized.selector);
        factory.upgrade(proxy, address(newImpl));
    }

    function testPredictDeterministicAddress() public view {
        bytes32 salt = _createSalt(100);

        address predicted = factory.predictDeterministicAddress(salt);

        // Verify prediction is deterministic
        address predicted2 = factory.predictDeterministicAddress(salt);
        assertEq(predicted, predicted2);
    }

    function testInitCodeHash() public view {
        bytes32 hash = factory.initCodeHash();
        assertTrue(hash != bytes32(0), "Init code hash should not be zero");
    }
}
