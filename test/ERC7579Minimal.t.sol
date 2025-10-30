// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ERC7579Minimal.sol";

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
}

contract MockTarget {
    uint256 public value;
    event Called(uint256 indexed newValue);
    function setValue(uint256 _v) external payable returns (uint256) {
        value = _v;
        emit Called(_v);
        return _v;
    }
    function willRevert() external pure {
        revert("fail");
    }
}

contract ERC7579MinimalTest is Test {
    ERC7579Minimal minimal;
    MockRegistry registry;
    MockTarget target;
    address owner = address(0xABCD);
    address executor = address(0xBEEF);
    bytes4 setValueSelector = MockTarget.setValue.selector;
    bytes4 willRevertSelector = MockTarget.willRevert.selector;

    function setUp() public {
        registry = new MockRegistry();
        minimal = new ERC7579Minimal();
        minimal.initialize(owner, registry, "acc");
        vm.startPrank(owner);
        minimal.grantRoles(executor, 1 << 1);
        vm.stopPrank();
        target = new MockTarget();
        registry.allow(address(minimal), address(target), setValueSelector, true);
        registry.allow(address(minimal), address(target), willRevertSelector, true);
    }

    function _encodeBatch(address t, uint256 v, bytes memory data) internal pure returns (bytes memory) {
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution(t, v, data);
        return ExecutionLib.encodeBatch(executions);
    }

    function testInitialize() public {
        assertEq(minimal.accountId(), "acc");
    }

    function testExecuteBatchSuccess() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 123);
        bytes memory execData = _encodeBatch(address(target), 0, data);
        vm.startPrank(executor);
        bytes[] memory result = minimal.execute(ModeCode.wrap(bytes32(uint256(0x0101))), execData);
        vm.stopPrank();
        assertEq(target.value(), 123);
        assertEq(minimal.nonce(), 1);
        assertEq(result.length, 1);
    }

    function testExecuteBatchUnauthorized() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 1);
        bytes memory execData = _encodeBatch(address(target), 0, data);
        vm.expectRevert();
        minimal.execute(ModeCode.wrap(bytes32(uint256(0x0101))), execData);
    }

    function testExecuteRevertUnsupportedCallType() public {
        bytes memory data = abi.encodeWithSelector(setValueSelector, 1);
        vm.startPrank(executor);
        vm.expectRevert();
        minimal.execute(ModeCode.wrap(bytes32(uint256(0x0000))), data);
        vm.stopPrank();
    }

    function testTryExecuteEmitsTryExecutionFailed() public {
        bytes memory data = abi.encodeWithSelector(willRevertSelector);
        bytes memory execData = _encodeBatch(address(target), 0, data);
        vm.startPrank(executor);
        vm.expectEmit(true, false, false, true);
        emit ERC7579Minimal.TryExecutionFailed(0);
        minimal.execute(ModeCode.wrap(bytes32(uint256(0x0201))), execData);
        vm.stopPrank();
        assertEq(minimal.nonce(), 1);
    }

    function testRegistryRevertPreventsExecution() public {
        registry.setShouldRevert(true);
        bytes memory data = abi.encodeWithSelector(setValueSelector, 7);
        bytes memory execData = _encodeBatch(address(target), 0, data);
        vm.startPrank(executor);
        vm.expectRevert(bytes("unauthorized"));
        minimal.execute(ModeCode.wrap(bytes32(uint256(0x0101))), execData);
        vm.stopPrank();
    }
}
