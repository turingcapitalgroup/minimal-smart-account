// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Internal Libraries
import { CallType, ExecType, ModeCode } from "../libraries/ModeLib.sol";

/* ///////////////////////////////////////////////////////////////
                            STRUCTS
///////////////////////////////////////////////////////////////*/

/**
 * @notice Execution struct containing call parameters for batch operations
 * @param target The address of the contract to call
 * @param value The amount of native tokens (wei) to send with the call
 * @param callData The encoded function call data to execute
 */
struct Execution {
    address target;
    uint256 value;
    bytes callData;
}

/**
 * @title IMinimalSmartAccount
 * @notice Interface for minimal smart account implementation
 * @dev Defines core functionality for executing transactions on behalf of smart accounts
 */
interface IMinimalSmartAccount {
    /* ///////////////////////////////////////////////////////////////
                                ERRORS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when an unsupported call type is requested
     * @param callType The unsupported call type that was attempted
     */
    error UnsupportedCallType(CallType callType);

    /**
     * @notice Thrown when an unsupported execution type is requested
     * @param execType The unsupported execution type that was attempted
     */
    error UnsupportedExecType(ExecType execType);

    /* ///////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a transaction execution failed in TRY mode
     * @dev In TRY mode, failures don't revert the entire batch, only emit this event
     * @param numberInBatch The index of the failed execution in the batch
     */
    event TryExecutionFailed(uint256 numberInBatch);

    /**
     * @notice Emitted when a transaction is successfully executed
     * @param nonce The sequential nonce of the executed transaction
     * @param executor The address that initiated the execution
     * @param target The address of the contract that was called
     * @param callData The encoded function call data that was executed
     * @param value The amount of native tokens (wei) sent with the call
     * @param result The return data from the executed call
     */
    event Executed(
        uint256 indexed nonce,
        address executor,
        address indexed target,
        bytes indexed callData,
        uint256 value,
        bytes result
    );

    /* ///////////////////////////////////////////////////////////////
                                CORE
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes a transaction on behalf of the account
     * @dev Implementations MUST ensure adequate authorization control
     *      Implementations MUST revert if an unsupported mode is requested
     *      Supports batch executions with either DEFAULT (revert on failure) or TRY (continue on failure) modes
     * @param mode The encoded execution mode of the transaction containing CallType and ExecType
     * @param executionCalldata The encoded execution call data containing target, value, and calldata
     * @return result Array of bytes containing the return data from each executed call
     */
    function execute(ModeCode mode, bytes calldata executionCalldata) external returns (bytes[] memory result);

    /**
     * @notice Returns the account implementation identifier
     * @dev The accountId should be structured as "vendorname.accountname.semver"
     * @return accountImplementationId The unique identifier string for this account implementation
     */
    function accountId() external view returns (string memory accountImplementationId);

    /**
     * @notice Returns the nonce of the wallet
     * @return nonceNumber The unique nonce of the last transaction
     */
    function nonce() external view returns (uint256 nonceNumber);
}
