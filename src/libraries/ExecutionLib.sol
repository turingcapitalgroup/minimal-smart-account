// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution } from "../interfaces/IMinimalSmartAccount.sol";

/**
 * @title ExecutionLib
 * @notice Helper Library for decoding Execution calldata
 * @dev malloc for memory allocation is bad for gas. Use this assembly instead.
 */
library ExecutionLib {
    error DecodingError();

    /**
     * @notice Decode a batch of `Execution` executionBatch from a `bytes` calldata.
     * @dev Assembly-optimized decoding from Solady
     */
    function decodeBatch(bytes calldata executionCalldata) internal pure returns (Execution[] calldata executionBatch) {
        /// @solidity memory-safe-assembly
        assembly {
            let u := calldataload(executionCalldata.offset)
            let s := add(executionCalldata.offset, u)
            let e := sub(add(executionCalldata.offset, executionCalldata.length), 0x20)
            executionBatch.offset := add(s, 0x20)
            executionBatch.length := calldataload(s)
            if or(shr(64, u), gt(add(s, shl(5, executionBatch.length)), e)) {
                mstore(0x00, 0xba597e7e) // `DecodingError()`.
                revert(0x1c, 0x04)
            }
            if executionBatch.length {
                // Perform bounds checks on the decoded `executionBatch`.
                // Loop runs out-of-gas if `executionBatch.length` is big enough to cause overflows.
                for { let i := executionBatch.length } 1 { } {
                    i := sub(i, 1)
                    let p := calldataload(add(executionBatch.offset, shl(5, i)))
                    let c := add(executionBatch.offset, p)
                    let q := calldataload(add(c, 0x40))
                    let o := add(c, q)
                    // forgefmt: disable-next-item
                    if or(shr(64, or(calldataload(o), or(p, q))),
                        or(gt(add(c, 0x40), e), gt(add(o, calldataload(o)), e))) {
                        mstore(0x00, 0xba597e7e) // `DecodingError()`.
                        revert(0x1c, 0x04)
                    }
                    if iszero(i) { break }
                }
            }
        }
    }

    function encodeBatch(Execution[] memory executions) internal pure returns (bytes memory callData) {
        callData = abi.encode(executions);
    }

    function decodeSingle(bytes calldata executionCalldata)
        internal
        pure
        returns (address target, uint256 value, bytes calldata callData)
    {
        target = address(bytes20(executionCalldata[0:20]));
        value = uint256(bytes32(executionCalldata[20:52]));
        callData = executionCalldata[52:];
    }

    function encodeSingle(
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        pure
        returns (bytes memory userOpCalldata)
    {
        userOpCalldata = abi.encodePacked(target, value, callData);
    }
}
