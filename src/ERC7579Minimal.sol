// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Execution, IERC7579Minimal } from "./interfaces/IERC7579Minimal.sol";

import { IRegistry } from "./interfaces/IRegistry.sol";
import { ExecutionLib } from "./libraries/ExecutionLib.sol";
import {
    CALLTYPE_BATCH,
    CALLTYPE_DELEGATECALL,
    CALLTYPE_SINGLE,
    CallType,
    EXECTYPE_DEFAULT,
    EXECTYPE_TRY,
    ExecType,
    ModeCode
} from "./libraries/ModeLib.sol";
import { LibCall } from "solady/utils/LibCall.sol";

abstract contract ERC7579Minimal is IERC7579Minimal {
    using ExecutionLib for bytes;

    event TryExecutionFailed(uint256 numberInBatch);

    IRegistry registry;

    function execute(ModeCode mode, bytes calldata executionCalldata) external returns (bytes[] memory result) {
        CallType callType;
        ExecType execType;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            callType := mode
            execType := shl(8, mode)
        }
        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                   REVERT ON FAILED EXEC                    */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
        if (execType == EXECTYPE_DEFAULT) {
            // DEFAULT EXEC & BATCH CALL
            if (callType == CALLTYPE_BATCH) {
                Execution[] calldata executions = executionCalldata.decodeBatch();
                return _exec(executions);
            }
            // DELEGATECALL not allowed by default
            // handle unsupported calltype
            else {
                revert UnsupportedCallType(callType);
            }
        }
        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                           TRY EXEC                         */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
        else if (execType == EXECTYPE_TRY) {
            // TRY EXEC & BATCH CALL
            if (callType == CALLTYPE_BATCH) {
                Execution[] calldata executions = executionCalldata.decodeBatch();
                _tryExec(executions);
            }
            // handle unsupported calltype
            else {
                revert UnsupportedCallType(callType);
            }
        }
        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*               HANDLE UNSUPPORTED EXEC TYPE                 */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
        else {
            revert UnsupportedExecType(execType);
        }
    }

    function executeFromExecutor(
        ModeCode mode,
        bytes calldata executionCalldata
    )
        external
        returns (bytes[] memory returnData);

    function isValidSignature(bytes32 hash, bytes calldata data) external returns (bytes4);

    function accountId() external view returns (string memory accountImplementationId);

    function _exec(Execution[] calldata executions) internal returns (bytes[] memory result) {
        uint256 length = executions.length;
        // Pre-allocate result array
        result = new bytes[](length);

        // Execute calls with optimized loop
        for (uint256 i; i < length; ++i) {
            // Extract selector and validate vault-specific permission
            bytes4 functionSig = bytes4(executions[i].callData);
            bytes memory params = executions[i].callData[4:];
            registry.authorizeAdapterCall(executions[i].target, functionSig, params);

            // Execute and store result
            result[i] = executions[i].target.callContract(executions[i].value, executions[i].callData);
            emit Executed(msg.sender, executions[i].target, executions[i].callData, executions[i].values, result[i]);
        }
    }

    function _tryExec(Execution[] calldata executions) internal returns (bytes[] memory result) {
        uint256 length = executions.length;
        // Pre-allocate result array
        result = new bytes[](length);

        // Execute calls with optimized loop
        for (uint256 i; i < length; ++i) {
            // Extract selector and validate vault-specific permission
            bytes4 functionSig = bytes4(executions[i].callData);
            bytes memory params = executions[i].callData[4:];
            registry.authorizeAdapterCall(executions[i].target, functionSig, params);

            // Execute and store result
            (bool success,, bytes memory _result) = executions[i].target.tryCall(
                executions[i].value, type(uint256).max, type(uint256).max, executions[i].callData
            );
            result[i] = _result;
            if (!success) emit TryExecutionFailed(i);
            emit Executed(msg.sender, executions[i].target, executions[i].callData, executions[i].values, result[i]);
        }
    }
}
