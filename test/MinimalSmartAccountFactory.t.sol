// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IRegistry, MinimalSmartAccount } from "../src/MinimalSmartAccount.sol";
import { MinimalSmartAccountFactory } from "../src/MinimalSmartAccountFactory.sol";
import { DeploymentBaseTest } from "./base/DeploymentBaseTest.t.sol";

contract MinimalSmartAccountFactoryTest is DeploymentBaseTest {
    /// @dev Helper to create a salt that starts with the caller's address
    function _createFactorySalt(uint96 uniqueId) internal view returns (bytes32) {
        return bytes32(uint256(uint160(address(this))) << 96) | bytes32(uint256(uniqueId));
    }

    function testDeployDeterministic() public {
        bytes32 salt = _createFactorySalt(100);

        address predicted = factory.predictDeterministicAddress(salt);

        address proxy = factory.deployDeterministic(
            address(implementation), salt, owner, IRegistry(address(registry)), "test-account"
        );

        assertEq(proxy, predicted, "Address mismatch");

        // Verify initialization
        MinimalSmartAccount proxyAccount = MinimalSmartAccount(payable(proxy));
        assertEq(proxyAccount.accountId(), "test-account");
        assertEq(proxyAccount.owner(), owner);
    }

    function testDeployDeterministicSameAddressWithSameSalt() public {
        bytes32 salt = _createFactorySalt(101);

        factory.deployDeterministic(
            address(implementation), salt, owner, IRegistry(address(registry)), "test-account-1"
        );

        // Deploying with same salt should fail
        vm.expectRevert(MinimalSmartAccountFactory.DeploymentFailed.selector);
        factory.deployDeterministic(
            address(implementation), salt, owner, IRegistry(address(registry)), "test-account-2"
        );
    }

    function testDeployDeterministicDifferentSaltsDifferentAddresses() public {
        bytes32 salt1 = _createFactorySalt(102);
        bytes32 salt2 = _createFactorySalt(103);

        address proxy1 = factory.deployDeterministic(
            address(implementation), salt1, owner, IRegistry(address(registry)), "test-account-1"
        );
        address proxy2 = factory.deployDeterministic(
            address(implementation), salt2, owner, IRegistry(address(registry)), "test-account-2"
        );

        assertTrue(proxy1 != proxy2, "Addresses should be different");
    }

    function testSaltMustStartWithCaller() public {
        // Salt that starts with a different address (0xDEAD shifted to high bits)
        bytes32 badSalt = bytes32(uint256(uint160(address(0xDEAD))) << 96);

        vm.expectRevert(MinimalSmartAccountFactory.SaltDoesNotStartWithCaller.selector);
        factory.deployDeterministic(
            address(implementation), badSalt, owner, IRegistry(address(registry)), "test-account"
        );
    }

    function testSaltCanStartWithZeroAddress() public {
        // Salt that starts with zero address (low 96 bits only) is allowed
        bytes32 zeroSalt = bytes32(uint256(1));

        address proxy = factory.deployDeterministic(
            address(implementation), zeroSalt, owner, IRegistry(address(registry)), "test-account"
        );

        assertTrue(proxy != address(0), "Deployment should succeed");
    }

    function testPredictDeterministicAddress() public view {
        bytes32 salt = _createFactorySalt(200);

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
