// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IRegistry } from "../../src/interfaces/IRegistry.sol";
import { Test } from "forge-std/Test.sol";

/// @title BaseTest
/// @notice Base test contract with common utilities
/// @dev Provides user creation and common test setup
abstract contract BaseTest is Test {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          USERS                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    address public owner;
    address public deployer;
    address public executor;
    address public alice;
    address public bob;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          SETUP                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _createUsers() internal {
        owner = makeAddr("owner");
        deployer = makeAddr("deployer");
        executor = makeAddr("executor");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Fund users
        vm.deal(owner, 100 ether);
        vm.deal(deployer, 100 ether);
        vm.deal(executor, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        UTILITIES                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Create a salt that starts with the caller's address
    function _createSalt(address caller, uint96 uniqueId) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(caller)) << 96) | bytes32(uint256(uniqueId));
    }
}

/// @title MockRegistry
/// @notice Mock registry for testing authorization
contract MockRegistry is IRegistry {
    bool public shouldRevert;
    mapping(address => mapping(address => mapping(bytes4 => bool))) public allowed;

    function setShouldRevert(bool v) external {
        shouldRevert = v;
    }

    function authorizeAdapterCall(address target, bytes4 selector, bytes calldata) external view override {
        if (shouldRevert) revert("unauthorized");
        if (!allowed[msg.sender][target][selector]) revert("unauthorized");
    }

    function isAdapterSelectorAllowed(
        address adapter,
        address target,
        bytes4 selector
    )
        external
        view
        override
        returns (bool)
    {
        return allowed[adapter][target][selector];
    }

    function allow(address adapter, address target, bytes4 selector, bool value) external {
        allowed[adapter][target][selector] = value;
    }

    function allowAll(address adapter, address target) external {
        // Allow common function selectors
        allowed[adapter][target][bytes4(0)] = true;
    }
}
