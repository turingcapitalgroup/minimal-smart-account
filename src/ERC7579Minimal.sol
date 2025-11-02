// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// External Libraries
import { Initializable } from "vendor/Initializable.sol";
import { LibCall } from "vendor/LibCall.sol";
import { OwnableRoles } from "vendor/OwnableRoles.sol";
import { UUPSUpgradeable } from "vendor/UUPSUpgradeable.sol";

// Internal Libraries
import { ExecutionLib } from "./libraries/ExecutionLib.sol";
import { CALLTYPE_BATCH, CallType, EXECTYPE_DEFAULT, EXECTYPE_TRY, ExecType, ModeCode } from "./libraries/ModeLib.sol";

// Local Interfaces
import { Execution, IERC7579Minimal } from "./interfaces/IERC7579Minimal.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

/**
 * @title ERC7579Minimal
 * @notice Minimal implementation of ERC-7579 modular smart account standard
 * @dev This contract provides a minimal ERC-7579 account with batch execution capabilities,
 * registry-based authorization, UUPS upgradeability, and role-based access control
 * Now uses the ERC-7201 namespaced storage pattern.
 */
contract ERC7579Minimal is IERC7579Minimal, Initializable, UUPSUpgradeable, OwnableRoles {
    using ExecutionLib for bytes;
    using LibCall for address;

    /* ///////////////////////////////////////////////////////////////
                                ROLES
    ///////////////////////////////////////////////////////////////*/

    /// @notice Admin role identifier for privileged operations
    uint256 internal constant ADMIN_ROLE = _ROLE_0;

    /// @notice Executor role identifier for accounts authorized to execute transactions
    uint256 internal constant EXECUTOR_ROLE = _ROLE_1;

    /* ///////////////////////////////////////////////////////////////
                                STORAGE
    ///////////////////////////////////////////////////////////////*/

    /// @notice Core storage structure for ERC7579Minimal using ERC-7201 namespaced storage pattern
    /// @custom:storage-location erc7201:erc7579.storage.MinimalAccount
    struct MinimalAccountStorage {
        /// @notice Registry contract for authorizing adapter calls
        IRegistry registry;
        /// @notice Sequential nonce for tracking executed transactions
        uint256 nonce;
        /// @notice Unique identifier for this account implementation
        string accountId;
    }

    // keccak256(abi.encode(uint256(keccak256("erc7579.storage.MinimalAccount")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MINIMALACCOUNT_STORAGE_LOCATION =
        0x9932fbd4b78281b9b70cc1aeead73e6a5a61a8ecdff6bb3d8788a303ecdcb600;

    /// @notice Retrieves the MinimalAccount storage struct from its designated storage slot
    /// @dev Uses ERC-7201 namespaced storage pattern.
    /// @return $ The MinimalAccountStorage struct reference for state modifications
    function _getMinimalAccountStorage() private pure returns (MinimalAccountStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := MINIMALACCOUNT_STORAGE_LOCATION
        }
    }

    /* ///////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the ERC7579Minimal account
     * @dev Can only be called once due to the initializer modifier
     * @param _owner The address that will be set as the owner of the account
     * @param _registryAddress The registry contract address for authorizing adapter calls
     * @param _accountId The unique identifier string for this account implementation
     */
    function initialize(
        address _owner,
        IRegistry _registryAddress,
        string memory _accountId
    )
        external
        initializer
    {
        MinimalAccountStorage storage $ = _getMinimalAccountStorage();
        $.registry = _registryAddress;
        $.accountId = _accountId;
        _initializeOwner(_owner);
    }

    /* ///////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC7579Minimal
    function execute(ModeCode mode, bytes calldata executionCalldata) external virtual returns (bytes[] memory result) {
        _authorizeExecute(msg.sender);
        CallType _callType;
        ExecType _execType;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            _callType := mode
            _execType := shl(8, mode)
        }

        // Revert on failed Exec
        if (_execType == EXECTYPE_DEFAULT) {
            // DEFAULT EXEC & BATCH CALL
            if (_callType == CALLTYPE_BATCH) {
                Execution[] calldata _executions = executionCalldata.decodeBatch();
                return _exec(_executions);
            }
            // DELEGATECALL not allowed by default
            // handle unsupported calltype
            else {
                revert UnsupportedCallType(_callType);
            }
        }
        // Try Exec
        else if (_execType == EXECTYPE_TRY) {
            // TRY EXEC & BATCH CALL
            if (_callType == CALLTYPE_BATCH) {
                Execution[] calldata _executions = executionCalldata.decodeBatch();
                return _tryExec(_executions);
            }
            // handle unsupported calltype
            else {
                revert UnsupportedCallType(_callType);
            }
        }
        // Handle Unsupported Exec Type
        else {
            revert UnsupportedExecType(_execType);
        }
    }

    /**
     * @notice Internal function to execute batch calls that revert on failure
     * @dev Validates each call through the registry before execution
     * Increments nonce for each execution and emits Executed event
     * @param executions Array of Execution structs containing target, value, and calldata
     * @return result Array of bytes containing the return data from each executed call
     */
    function _exec(Execution[] calldata executions) internal virtual returns (bytes[] memory result) {
        MinimalAccountStorage storage $ = _getMinimalAccountStorage();
        IRegistry _registry = $.registry;
        uint256 _length = executions.length;
        // Pre-allocate result array
        result = new bytes[](_length);

        // Execute calls with optimized loop
        for (uint256 _i; _i < _length; ++_i) {
            ++$.nonce;
            // Extract selector and validate account-specific permission
            bytes4 _functionSig = bytes4(executions[_i].callData);
            bytes memory _params = executions[_i].callData[4:];
            _registry.authorizeAdapterCall(executions[_i].target, _functionSig, _params);

            // Execute and store result
            result[_i] = executions[_i].target.callContract(executions[_i].value, executions[_i].callData);
            emit Executed(
                $.nonce, msg.sender, executions[_i].target, executions[_i].callData, executions[_i].value, result[_i]
            );
        }
    }

    /**
     * @notice Internal function to execute batch calls that continue on failure
     * @dev Validates each call through the registry before execution
     * Emits TryExecutionFailed event on failures, but continues processing remaining calls
     * Increments nonce for each execution and emits Executed event
     * @param executions Array of Execution structs containing target, value, and calldata
     * @return result Array of bytes containing the return data from each executed call
     */
    function _tryExec(Execution[] calldata executions) internal virtual returns (bytes[] memory result) {
        MinimalAccountStorage storage $ = _getMinimalAccountStorage();
        IRegistry _registry = $.registry;
        uint256 _length = executions.length;
        // Pre-allocate result array
        result = new bytes[](_length);

        // Execute calls with optimized loop
        for (uint256 _i; _i < _length; ++_i) {
            ++$.nonce;

            // Extract selector and validate account-specific permission
            bytes4 _functionSig = bytes4(executions[_i].callData);
            bytes memory _params = executions[_i].callData[4:];
            _registry.authorizeAdapterCall(executions[_i].target, _functionSig, _params);

            // Execute and store result
            (bool _success,, bytes memory _callResult) = executions[_i].target
                .tryCall(executions[_i].value, type(uint256).max, type(uint16).max, executions[_i].callData);
            result[_i] = _callResult;
            if (!_success) emit TryExecutionFailed(_i);
            emit Executed(
                $.nonce, msg.sender, executions[_i].target, executions[_i].callData, executions[_i].value, result[_i]
            );
        }
    }

    /* ///////////////////////////////////////////////////////////////
                            ADMIN OPERATIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal authorization check for UUPS upgrades
     * @dev Ensures only the owner can authorize contract upgrades
     * Reverts if caller is not the owner
     */
    function _authorizeUpgrade(address) internal virtual override {
        _checkOwner();
    }

    /**
     * @notice Internal authorization check for execute operations
     * @dev Ensures only addresses with EXECUTOR_ROLE can execute transactions
     * Reverts if caller does not have the required role
     */
    function _authorizeExecute(address) internal virtual {
        _checkRoles(EXECUTOR_ROLE);
    }

    /* ///////////////////////////////////////////////////////////////
                            PUBLIC VIEW
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC7579Minimal
    function nonce() public view returns (uint256) {
        MinimalAccountStorage storage $ = _getMinimalAccountStorage();
        return $.nonce;
    }

    /// @inheritdoc IERC7579Minimal
    function accountId() public view returns (string memory) {
        MinimalAccountStorage storage $ = _getMinimalAccountStorage();
        return $.accountId;
    }
}
