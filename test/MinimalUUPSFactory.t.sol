// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IRegistry, MinimalSmartAccount } from "../src/MinimalSmartAccount.sol";
import { DeploymentBaseTest } from "./base/DeploymentBaseTest.t.sol";
import { MinimalUUPSFactory } from "factory/MinimalUUPSFactory.sol";

contract MinimalUUPSFactoryTest is DeploymentBaseTest {
    function testDeployDeterministic() public {
        bytes32 salt = bytes32(uint256(100));

        address predicted = factory.predictDeterministicAddress(address(implementation), salt);

        bytes memory initData =
            abi.encodeCall(MinimalSmartAccount.initialize, (owner, IRegistry(address(registry)), "test-account"));
        address proxy = factory.deployDeterministicAndCall(address(implementation), salt, initData);

        assertEq(proxy, predicted, "Address mismatch");

        // Verify initialization
        MinimalSmartAccount proxyAccount = MinimalSmartAccount(payable(proxy));
        assertEq(proxyAccount.accountId(), "test-account");
        assertEq(proxyAccount.owner(), owner);
    }

    function testDeployDeterministicSameAddressWithSameSalt() public {
        bytes32 salt = bytes32(uint256(101));

        bytes memory initData =
            abi.encodeCall(MinimalSmartAccount.initialize, (owner, IRegistry(address(registry)), "test-account-1"));
        factory.deployDeterministicAndCall(address(implementation), salt, initData);

        // Deploying with same salt should fail
        bytes memory initData2 =
            abi.encodeCall(MinimalSmartAccount.initialize, (owner, IRegistry(address(registry)), "test-account-2"));
        vm.expectRevert(MinimalUUPSFactory.DeploymentFailed.selector);
        factory.deployDeterministicAndCall(address(implementation), salt, initData2);
    }

    function testDeployDeterministicDifferentSaltsDifferentAddresses() public {
        bytes32 salt1 = bytes32(uint256(102));
        bytes32 salt2 = bytes32(uint256(103));

        bytes memory initData1 =
            abi.encodeCall(MinimalSmartAccount.initialize, (owner, IRegistry(address(registry)), "test-account-1"));
        bytes memory initData2 =
            abi.encodeCall(MinimalSmartAccount.initialize, (owner, IRegistry(address(registry)), "test-account-2"));

        address proxy1 = factory.deployDeterministicAndCall(address(implementation), salt1, initData1);
        address proxy2 = factory.deployDeterministicAndCall(address(implementation), salt2, initData2);

        assertTrue(proxy1 != proxy2, "Addresses should be different");
    }

    function testPredictDeterministicAddress() public view {
        bytes32 salt = bytes32(uint256(200));

        address predicted = factory.predictDeterministicAddress(address(implementation), salt);

        // Verify prediction is deterministic
        address predicted2 = factory.predictDeterministicAddress(address(implementation), salt);
        assertEq(predicted, predicted2);
    }

    function testInitCodeHash() public view {
        bytes32 hash = factory.initCodeHash(address(implementation));
        assertTrue(hash != bytes32(0), "Init code hash should not be zero");
    }
}
