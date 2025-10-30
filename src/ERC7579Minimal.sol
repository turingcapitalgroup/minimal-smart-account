// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Execution, IERC7579Minimal } from "./interfaces/IERC7579Minimal.sol";

import { IRegistry } from "./interfaces/IRegistry.sol";
import { ExecutionLib } from "./libraries/ExecutionLib.sol";
import { CALLTYPE_BATCH, CallType, EXECTYPE_DEFAULT, EXECTYPE_TRY, ExecType, ModeCode } from "./libraries/ModeLib.sol";

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { LibCall } from "solady/utils/LibCall.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

contract ERC7579Minimal is IERC7579Minimal, Initializable, UUPSUpgradeable, OwnableRoles {
    using ExecutionLib for bytes;
    using LibCall for address;

    uint256 internal constant ADMIN_ROLE = _ROLE_0;

    uint256 internal constant EXECUTOR_ROLE = _ROLE_1;

    IRegistry registry;
    uint256 public nonce;
    string public accountId;

    function initialize(address _owner, IRegistry _registry, string memory _accountId) external initializer {
        registry = _registry;
        accountId = _accountId;
        _initializeOwner(_owner);
    }

    function execute(ModeCode mode, bytes calldata executionCalldata) external virtual returns (bytes[] memory result) {
        _authorizeExecute(msg.sender);
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

    function _exec(Execution[] calldata executions) internal virtual returns (bytes[] memory result) {
        uint256 length = executions.length;
        // Pre-allocate result array
        result = new bytes[](length);

        // Execute calls with optimized loop
        for (uint256 i; i < length; ++i) {
            ++nonce;
            // Extract selector and validate vault-specific permission
            bytes4 functionSig = bytes4(executions[i].callData);
            bytes memory params = executions[i].callData[4:];
            registry.authorizeAdapterCall(executions[i].target, functionSig, params);

            // Execute and store result
            result[i] = executions[i].target.callContract(executions[i].value, executions[i].callData);
            emit Executed(
                nonce, msg.sender, executions[i].target, executions[i].callData, executions[i].value, result[i]
            );
        }
    }

    function _tryExec(Execution[] calldata executions) internal virtual returns (bytes[] memory result) {
        uint256 length = executions.length;
        // Pre-allocate result array
        result = new bytes[](length);

        // Execute calls with optimized loop
        for (uint256 i; i < length; ++i) {
            ++nonce;

            // Extract selector and validate vault-specific permission
            bytes4 functionSig = bytes4(executions[i].callData);
            bytes memory params = executions[i].callData[4:];
            registry.authorizeAdapterCall(executions[i].target, functionSig, params);

            // Execute and store result
            (bool success,, bytes memory _result) = executions[i].target
                .tryCall(executions[i].value, type(uint256).max, type(uint16).max, executions[i].callData);
            result[i] = _result;
            if (!success) emit TryExecutionFailed(i);
            emit Executed(
                nonce, msg.sender, executions[i].target, executions[i].callData, executions[i].value, result[i]
            );
        }
    }

    function _authorizeUpgrade(address) internal virtual override {
        _checkOwner();
    }

    function _authorizeExecute(address) internal virtual {
        _checkRoles(EXECUTOR_ROLE);
    }
}
