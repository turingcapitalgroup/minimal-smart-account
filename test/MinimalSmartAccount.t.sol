// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ExecutionLib, IRegistry, MinimalSmartAccount } from "../src/MinimalSmartAccount.sol";
import { Execution, IMinimalSmartAccount, ModeCode } from "../src/interfaces/IMinimalSmartAccount.sol";
import {
    CALLTYPE_BATCH,
    CALLTYPE_DELEGATECALL,
    CALLTYPE_SINGLE,
    CALLTYPE_STATIC,
    EXECTYPE_DEFAULT,
    EXECTYPE_TRY,
    ExecType,
    MODE_DEFAULT,
    ModeLib,
    ModePayload
} from "../src/libraries/ModeLib.sol";
import { Test } from "forge-std/Test.sol";

contract MockRegistry is IRegistry {
    bool public shouldRevert;
    mapping(address => mapping(address => mapping(bytes4 => bool))) public allowed;

    function setShouldRevert(bool v) external {
        shouldRevert = v;
    }

    function authorizeCall(address target, bytes4 selector, bytes calldata) external view override {
        if (shouldRevert) revert("unauthorized");
        if (!allowed[msg.sender][target][selector]) revert("unauthorized");
    }

    function isSelectorAllowed(address executor, address target, bytes4 selector)
        external
        view
        override
        returns (bool)
    {
        return allowed[executor][target][selector];
    }

    function allow(address adapter, address target, bytes4 selector, bool value) external {
        allowed[adapter][target][selector] = value;
    }
}

contract MockTarget {
    uint256 public value;
    event Called(uint256 indexed newValue);

    function setValue(uint256 _v) external payable returns (uint256) {
        value = _v;
        emit Called(_v);
        return _v;
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function willRevert() external pure {
        revert("fail");
    }

    function addValue(uint256 _v) external returns (uint256) {
        value += _v;
        return value;
    }

    receive() external payable { }
}

contract MockERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        (bool success,) = to.call(
            abi.encodeWithSignature("onERC721Received(address,address,uint256,bytes)", msg.sender, from, tokenId, "")
        );
        require(success, "ERC721: transfer to non ERC721Receiver");
    }
}

contract MockERC1155 {
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external {
        (bool success,) = to.call(
            abi.encodeWithSignature(
                "onERC1155Received(address,address,uint256,uint256,bytes)", msg.sender, from, id, amount, data
            )
        );
        require(success, "ERC1155: transfer to non ERC1155Receiver");
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    )
        external
    {
        (bool success,) = to.call(
            abi.encodeWithSignature(
                "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)",
                msg.sender,
                from,
                ids,
                amounts,
                data
            )
        );
        require(success, "ERC1155: transfer to non ERC1155Receiver");
    }
}

contract MinimalSmartAccountTest is Test {
    MinimalSmartAccount minimal;
    MockRegistry registry;
    MockTarget target;
    MockTarget target2;
    address owner = address(0xABCD);
    address executor = address(0xBEEF);
    address admin = address(0xCAFE);
    address randomUser = address(0xDEAD);
    bytes4 setValueSelector = MockTarget.setValue.selector;
    bytes4 getValueSelector = MockTarget.getValue.selector;
    bytes4 willRevertSelector = MockTarget.willRevert.selector;
    bytes4 addValueSelector = MockTarget.addValue.selector;

    uint256 internal constant ADMIN_ROLE = 1 << 0;
    uint256 internal constant EXECUTOR_ROLE = 1 << 1;

    function setUp() public {
        registry = new MockRegistry();
        minimal = new MinimalSmartAccount();
        minimal.initialize(owner, registry, "keyrock.minimal.v1");
        vm.startPrank(owner);
        minimal.grantRoles(executor, EXECUTOR_ROLE);
        minimal.grantRoles(admin, ADMIN_ROLE);
        vm.stopPrank();
        target = new MockTarget();
        target2 = new MockTarget();
        registry.allow(address(minimal), address(target), setValueSelector, true);
        registry.allow(address(minimal), address(target), willRevertSelector, true);
        registry.allow(address(minimal), address(target), addValueSelector, true);
        registry.allow(address(minimal), address(target), getValueSelector, true);
        registry.allow(address(minimal), address(target2), setValueSelector, true);
        registry.allow(address(minimal), address(target2), addValueSelector, true);
    }

    function _encodeBatch(Execution[] memory executions) internal pure returns (bytes memory) {
        return ExecutionLib.encodeBatch(executions);
    }

    function _encodeSingleExecution(address t, uint256 v, bytes memory data) internal pure returns (bytes memory) {
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: t, value: v, callData: data });
        return ExecutionLib.encodeBatch(executions);
    }

    /* ///////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    ///////////////////////////////////////////////////////////////*/

    function testInitialize() public view {
        assertEq(minimal.accountId(), "keyrock.minimal.v1");
        assertEq(minimal.owner(), owner);
        assertEq(minimal.nonce(), 0);
    }

    function testInitializeCannotReinitialize() public {
        vm.expectRevert();
        minimal.initialize(address(0x1234), registry, "new.account.id");
    }

    function testInitializeWithZeroOwner() public {
        MinimalSmartAccount newAccount = new MinimalSmartAccount();
        newAccount.initialize(address(0), registry, "test");
        assertEq(newAccount.owner(), address(0));
    }

    function testInitializeWithEmptyAccountId() public {
        MinimalSmartAccount newAccount = new MinimalSmartAccount();
        newAccount.initialize(owner, registry, "");
        assertEq(newAccount.accountId(), "");
    }

    /* ///////////////////////////////////////////////////////////////
                    ROLE & ACCESS CONTROL TESTS
    ///////////////////////////////////////////////////////////////*/

    function testOwnerCanGrantRoles() public {
        address newExecutor = address(0x1111);
        vm.prank(owner);
        minimal.grantRoles(newExecutor, EXECUTOR_ROLE);
        assertTrue(minimal.hasAnyRole(newExecutor, EXECUTOR_ROLE));
    }

    function testOwnerCanRevokeRoles() public {
        vm.prank(owner);
        minimal.revokeRoles(executor, EXECUTOR_ROLE);
        assertFalse(minimal.hasAnyRole(executor, EXECUTOR_ROLE));
    }

    function testNonOwnerCannotGrantRoles() public {
        vm.prank(randomUser);
        vm.expectRevert();
        minimal.grantRoles(randomUser, EXECUTOR_ROLE);
    }

    function testNonOwnerCannotRevokeRoles() public {
        vm.prank(randomUser);
        vm.expectRevert();
        minimal.revokeRoles(executor, EXECUTOR_ROLE);
    }

    function testExecutorRoleRequired() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 1);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);

        vm.prank(randomUser);
        vm.expectRevert();
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);
    }

    function testAdminRoleNotSufficientForExecute() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 1);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);

        vm.prank(admin);
        vm.expectRevert();
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);
    }

    function testOwnerCannotExecuteWithoutExecutorRole() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 1);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);

        vm.prank(owner);
        vm.expectRevert();
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);
    }

    function testOwnerWithExecutorRoleCanExecute() public {
        vm.prank(owner);
        minimal.grantRoles(owner, EXECUTOR_ROLE);

        bytes memory data = abi.encodeWithSelector(setValueSelector, 999);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);

        vm.prank(owner);
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);
        assertEq(target.value(), 999);
    }

    /* ///////////////////////////////////////////////////////////////
                    BATCH EXECUTION TESTS (DEFAULT MODE)
    ///////////////////////////////////////////////////////////////*/

    function testExecuteBatchSingleSuccess() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 123);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);

        vm.prank(executor);
        bytes[] memory result = minimal.execute(ModeLib.encodeSimpleBatch(), execData);

        assertEq(target.value(), 123);
        assertEq(minimal.nonce(), 1);
        assertEq(result.length, 1);
        assertEq(abi.decode(result[0], (uint256)), 123);
    }

    function testExecuteBatchMultipleSuccess() public {
        Execution[] memory executions = new Execution[](3);
        executions[0] =
            Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(setValueSelector, 100) });
        executions[1] =
            Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(addValueSelector, 50) });
        executions[2] =
            Execution({ target: address(target2), value: 0, callData: abi.encodeWithSelector(setValueSelector, 200) });

        bytes memory execData = _encodeBatch(executions);

        vm.prank(executor);
        bytes[] memory results = minimal.execute(ModeLib.encodeSimpleBatch(), execData);

        assertEq(target.value(), 150); // 100 + 50
        assertEq(target2.value(), 200);
        assertEq(minimal.nonce(), 3);
        assertEq(results.length, 3);
    }

    function testExecuteBatchWithValue() public {
        vm.deal(address(minimal), 1 ether);

        bytes memory data = abi.encodeWithSelector(setValueSelector, 42);
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: address(target), value: 0.5 ether, callData: data });

        bytes memory execData = _encodeBatch(executions);

        vm.prank(executor);
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);

        assertEq(address(target).balance, 0.5 ether);
        assertEq(address(minimal).balance, 0.5 ether);
    }

    function testExecuteBatchRevertsOnFailure() public {
        Execution[] memory executions = new Execution[](2);
        executions[0] =
            Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(setValueSelector, 100) });
        executions[1] =
            Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(willRevertSelector) });

        bytes memory execData = _encodeBatch(executions);

        vm.prank(executor);
        vm.expectRevert();
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);
    }

    function testExecuteBatchEmitsExecutedEvent() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 777);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);

        vm.prank(executor);
        vm.expectEmit(true, true, true, true);
        emit IMinimalSmartAccount.Executed(1, executor, address(target), data, 0, abi.encode(uint256(777)));
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);
    }

    function testExecuteBatchNonceIncrementsPerExecution() public {
        Execution[] memory executions = new Execution[](5);
        for (uint256 i = 0; i < 5; i++) {
            executions[i] =
                Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(setValueSelector, i) });
        }

        bytes memory execData = _encodeBatch(executions);

        vm.prank(executor);
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);

        assertEq(minimal.nonce(), 5);
    }

    /* ///////////////////////////////////////////////////////////////
                        TRY EXECUTION TESTS
    ///////////////////////////////////////////////////////////////*/

    function testTryExecuteSingleFailure() public {
        bytes memory data = abi.encodeWithSelector(willRevertSelector);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);

        ModeCode tryMode = ModeLib.encode(CALLTYPE_BATCH, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));

        vm.prank(executor);
        vm.expectEmit(true, false, false, true);
        emit IMinimalSmartAccount.TryExecutionFailed(0);
        bytes[] memory results = minimal.execute(tryMode, execData);

        assertEq(minimal.nonce(), 1);
        assertEq(results.length, 1);
    }

    function testTryExecutePartialFailure() public {
        Execution[] memory executions = new Execution[](3);
        executions[0] =
            Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(setValueSelector, 100) });
        executions[1] =
            Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(willRevertSelector) });
        executions[2] =
            Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(addValueSelector, 50) });

        bytes memory execData = _encodeBatch(executions);
        ModeCode tryMode = ModeLib.encode(CALLTYPE_BATCH, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));

        vm.prank(executor);
        vm.expectEmit(true, false, false, true);
        emit IMinimalSmartAccount.TryExecutionFailed(1);
        bytes[] memory results = minimal.execute(tryMode, execData);

        assertEq(target.value(), 150); // 100 + 50, skipped the revert
        assertEq(minimal.nonce(), 3);
        assertEq(results.length, 3);
    }

    function testTryExecuteAllFailures() public {
        Execution[] memory executions = new Execution[](2);
        executions[0] =
            Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(willRevertSelector) });
        executions[1] =
            Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(willRevertSelector) });

        bytes memory execData = _encodeBatch(executions);
        ModeCode tryMode = ModeLib.encode(CALLTYPE_BATCH, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));

        vm.prank(executor);
        bytes[] memory results = minimal.execute(tryMode, execData);

        assertEq(minimal.nonce(), 2);
        assertEq(results.length, 2);
    }

    function testTryExecuteAllSuccess() public {
        Execution[] memory executions = new Execution[](2);
        executions[0] =
            Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(setValueSelector, 10) });
        executions[1] =
            Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(addValueSelector, 5) });

        bytes memory execData = _encodeBatch(executions);
        ModeCode tryMode = ModeLib.encode(CALLTYPE_BATCH, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));

        vm.prank(executor);
        bytes[] memory results = minimal.execute(tryMode, execData);

        assertEq(target.value(), 15);
        assertEq(minimal.nonce(), 2);
        assertEq(results.length, 2);
    }

    function testTryExecuteEmitsExecutedEventOnSuccess() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 555);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);
        ModeCode tryMode = ModeLib.encode(CALLTYPE_BATCH, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));

        vm.prank(executor);
        vm.expectEmit(true, true, true, true);
        emit IMinimalSmartAccount.Executed(1, executor, address(target), data, 0, abi.encode(uint256(555)));
        minimal.execute(tryMode, execData);
    }

    /* ///////////////////////////////////////////////////////////////
                    UNSUPPORTED MODE TESTS
    ///////////////////////////////////////////////////////////////*/

    function testExecuteRevertUnsupportedSingleCallType() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 1);

        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSelector(IMinimalSmartAccount.UnsupportedCallType.selector, CALLTYPE_SINGLE));
        minimal.execute(ModeLib.encodeSimpleSingle(), data);
    }

    function testExecuteRevertUnsupportedDelegateCallType() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 1);
        ModeCode delegateMode =
            ModeLib.encode(CALLTYPE_DELEGATECALL, EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00));

        vm.prank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(IMinimalSmartAccount.UnsupportedCallType.selector, CALLTYPE_DELEGATECALL)
        );
        minimal.execute(delegateMode, data);
    }

    function testExecuteRevertUnsupportedStaticCallType() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 1);
        ModeCode staticMode = ModeLib.encode(CALLTYPE_STATIC, EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00));

        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSelector(IMinimalSmartAccount.UnsupportedCallType.selector, CALLTYPE_STATIC));
        minimal.execute(staticMode, data);
    }

    function testTryExecuteRevertUnsupportedSingleCallType() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 1);
        ModeCode trySingleMode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));

        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSelector(IMinimalSmartAccount.UnsupportedCallType.selector, CALLTYPE_SINGLE));
        minimal.execute(trySingleMode, data);
    }

    function testExecuteRevertUnsupportedExecType() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 1);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);
        ExecType invalidExecType = ExecType.wrap(0x02);
        ModeCode invalidMode = ModeLib.encode(CALLTYPE_BATCH, invalidExecType, MODE_DEFAULT, ModePayload.wrap(0x00));

        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSelector(IMinimalSmartAccount.UnsupportedExecType.selector, invalidExecType));
        minimal.execute(invalidMode, execData);
    }

    /* ///////////////////////////////////////////////////////////////
                    REGISTRY AUTHORIZATION TESTS
    ///////////////////////////////////////////////////////////////*/

    function testRegistryRevertPreventsExecution() public {
        registry.setShouldRevert(true);
        bytes memory data = abi.encodeWithSelector(setValueSelector, 7);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);

        vm.prank(executor);
        vm.expectRevert(bytes("unauthorized"));
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);
    }

    function testRegistryRevertPreventsTryExecution() public {
        registry.setShouldRevert(true);
        bytes memory data = abi.encodeWithSelector(setValueSelector, 7);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);
        ModeCode tryMode = ModeLib.encode(CALLTYPE_BATCH, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));

        vm.prank(executor);
        vm.expectRevert(bytes("unauthorized"));
        minimal.execute(tryMode, execData);
    }

    function testUnauthorizedSelectorReverts() public {
        bytes4 unauthorizedSelector = bytes4(keccak256("unauthorized()"));
        bytes memory data = abi.encodeWithSelector(unauthorizedSelector);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);

        vm.prank(executor);
        vm.expectRevert(bytes("unauthorized"));
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);
    }

    function testUnauthorizedTargetReverts() public {
        address unauthorizedTarget = address(0x9999);
        bytes memory data = abi.encodeWithSelector(setValueSelector, 1);
        bytes memory execData = _encodeSingleExecution(unauthorizedTarget, 0, data);

        vm.prank(executor);
        vm.expectRevert(bytes("unauthorized"));
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);
    }

    /* ///////////////////////////////////////////////////////////////
                    ETH HANDLING TESTS
    ///////////////////////////////////////////////////////////////*/

    function testReceiveEther() public {
        vm.deal(address(this), 1 ether);
        (bool success,) = address(minimal).call{ value: 1 ether }("");
        assertTrue(success);
        assertEq(address(minimal).balance, 1 ether);
    }

    function testReceiveEtherFromMultipleSenders() public {
        vm.deal(address(0x1), 1 ether);
        vm.deal(address(0x2), 2 ether);

        vm.prank(address(0x1));
        (bool success1,) = address(minimal).call{ value: 1 ether }("");
        assertTrue(success1);

        vm.prank(address(0x2));
        (bool success2,) = address(minimal).call{ value: 2 ether }("");
        assertTrue(success2);

        assertEq(address(minimal).balance, 3 ether);
    }

    /* ///////////////////////////////////////////////////////////////
                    TOKEN RECEIVER TESTS
    ///////////////////////////////////////////////////////////////*/

    function testOnERC721Received() public view {
        bytes4 result = minimal.onERC721Received(address(0), address(0), 0, "");
        assertEq(result, bytes4(0x150b7a02));
    }

    function testOnERC721ReceivedFromTransfer() public {
        MockERC721 erc721 = new MockERC721();
        erc721.safeTransferFrom(address(this), address(minimal), 1);
    }

    function testOnERC1155Received() public view {
        bytes4 result = minimal.onERC1155Received(address(0), address(0), 0, 0, "");
        assertEq(result, bytes4(0xf23a6e61));
    }

    function testOnERC1155ReceivedFromTransfer() public {
        MockERC1155 erc1155 = new MockERC1155();
        erc1155.safeTransferFrom(address(this), address(minimal), 1, 100, "");
    }

    function testOnERC1155BatchReceived() public view {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        bytes4 result = minimal.onERC1155BatchReceived(address(0), address(0), ids, values, "");
        assertEq(result, bytes4(0xbc197c81));
    }

    function testOnERC1155BatchReceivedFromTransfer() public {
        MockERC1155 erc1155 = new MockERC1155();
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;
        erc1155.safeBatchTransferFrom(address(this), address(minimal), ids, amounts, "");
    }

    /* ///////////////////////////////////////////////////////////////
                    SUPPORTS INTERFACE TESTS
    ///////////////////////////////////////////////////////////////*/

    function testSupportsInterfaceERC165() public view {
        assertTrue(minimal.supportsInterface(0x01ffc9a7));
    }

    function testSupportsInterfaceERC721Receiver() public view {
        assertTrue(minimal.supportsInterface(0x150b7a02));
    }

    function testSupportsInterfaceERC1155Receiver() public view {
        assertTrue(minimal.supportsInterface(0x4e2312e0));
    }

    function testDoesNotSupportRandomInterface() public view {
        assertFalse(minimal.supportsInterface(0xdeadbeef));
    }

    /* ///////////////////////////////////////////////////////////////
                        FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzzExecuteBatchValue(uint256 value) public {
        vm.assume(value > 0 && value <= 100 ether);
        vm.deal(address(minimal), value);

        bytes memory data = abi.encodeWithSelector(setValueSelector, 42);
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: address(target), value: value, callData: data });

        bytes memory execData = _encodeBatch(executions);

        vm.prank(executor);
        minimal.execute(ModeLib.encodeSimpleBatch(), execData);

        assertEq(address(target).balance, value);
    }

    function testFuzzExecuteBatchSetValue(uint256 newValue) public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, newValue);
        bytes memory execData = _encodeSingleExecution(address(target), 0, data);

        vm.prank(executor);
        bytes[] memory result = minimal.execute(ModeLib.encodeSimpleBatch(), execData);

        assertEq(target.value(), newValue);
        assertEq(abi.decode(result[0], (uint256)), newValue);
    }

    function testFuzzMultipleBatchExecutions(uint8 numExecutions) public {
        vm.assume(numExecutions > 0 && numExecutions <= 20);

        Execution[] memory executions = new Execution[](numExecutions);
        for (uint256 i = 0; i < numExecutions; i++) {
            executions[i] =
                Execution({ target: address(target), value: 0, callData: abi.encodeWithSelector(setValueSelector, i) });
        }

        bytes memory execData = _encodeBatch(executions);

        vm.prank(executor);
        bytes[] memory results = minimal.execute(ModeLib.encodeSimpleBatch(), execData);

        assertEq(minimal.nonce(), numExecutions);
        assertEq(results.length, numExecutions);
        assertEq(target.value(), numExecutions - 1); // Last value set
    }
}
