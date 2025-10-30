// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRegistry {
    /// @notice Check if an adapter is authorized to call a specific function on a target
    /// @param target The target contract address
    /// @param selector The function selector
    /// @param params The function parameters
    function authorizeAdapterCall(address target, bytes4 selector, bytes calldata params) external;

    /// @notice Check if a selector is allowed for an adapter
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @return Whether the selector is allowed
    function isAdapterSelectorAllowed(
        address adapter,
        address target,
        bytes4 selector
    )
        external
        view
        returns (bool);
}
