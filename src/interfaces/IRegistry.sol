// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRegistry {
    /// @notice Check if an executor is authorized to call a specific function on a target
    /// @param target The target contract address
    /// @param selector The function selector
    /// @param params The function parameters
    function authorizeCall(address target, bytes4 selector, bytes calldata params) external;

    /// @notice Check if a selector is allowed for an executor
    /// @param executor The executor address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @return Whether the selector is allowed
    function isSelectorAllowed(address executor, address target, bytes4 selector) external view returns (bool);
}
