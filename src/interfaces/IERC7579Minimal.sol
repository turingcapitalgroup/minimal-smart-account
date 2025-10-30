// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { CallType, ExecType, ModeCode } from "../libraries/ModeLib.sol";

/* ///////////////////////////////////////////////////////////////
                                STRUCTS
    ///////////////////////////////////////////////////////////////*/
struct Execution {
    address target;
    uint256 value;
    bytes callData;
}

interface IERC7579Minimal {

    /* ///////////////////////////////////////////////////////////////
                                ERRORS
    ///////////////////////////////////////////////////////////////*/

    error UnsupportedCallType(CallType);

    error UnsupportedExecType(ExecType);

    /* ///////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    event TryExecutionFailed(uint256 numberInBatch);

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
     * @dev Executes a transaction on behalf of the account.
     *         This function is intended to be called by ERC-4337 EntryPoint.sol
     * @dev Ensure adequate authorization control: i.e. onlyEntryPointOrSelf
     *
     * @dev MSA MUST implement this function signature.
     * If a mode is requested that is not supported by the Account, it MUST revert
     * @param mode The encoded execution mode of the transaction. See ModeLib.sol for details
     * @param executionCalldata The encoded execution call data
     */
    function execute(ModeCode mode, bytes calldata executionCalldata) external returns (bytes[] memory result);

    /**
     * @dev Returns the account id of the smart account
     * @return accountImplementationId the account id of the smart account
     * the accountId should be structured like so:
     *        "vendorname.accountname.semver"
     */
    function accountId() external view returns (string memory accountImplementationId);
}
