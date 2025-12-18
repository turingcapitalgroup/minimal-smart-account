# Security Audit Report: Minimal Smart Account

**Date:** 2025-12-13
**Auditor:** Security Review
**Commit:** ff38756

---

## Executive Summary

This is a security audit of a minimal smart account implementation with batch execution capabilities, registry-based authorization, and UUPS upgradeability. Overall, the codebase is well-designed and uses battle-tested Solady libraries. However, I've identified several vulnerabilities and concerns ranging from **CRITICAL** to **INFORMATIONAL**.

---

## 🔴 CRITICAL Vulnerabilities

### 1. Missing Owner Initialization Leaves Account Ownerless

**Location:** `src/MinimalSmartAccount.sol:83-96`

**Issue:** The `initialize()` function sets the owner using `_initializeOwner(_owner)`, but **there is no code to grant EXECUTOR_ROLE to anyone**. After initialization:
- The owner is set
- The registry is set
- But **no one has EXECUTOR_ROLE**

This means:
- The `execute()` function requires `EXECUTOR_ROLE` (line 104: `_authorizeExecute` → `_checkRoles(EXECUTOR_ROLE)`)
- The owner can only call `grantRoles()` (inherited from OwnableRoles)
- However, **the owner does NOT automatically have EXECUTOR_ROLE**

**Impact:** After deployment, the smart account cannot execute any transactions until the owner explicitly grants `EXECUTOR_ROLE` to someone. This is likely a design bug - the owner should either:
1. Automatically receive EXECUTOR_ROLE during initialization, OR
2. Be able to execute via `onlyOwnerOrRoles(EXECUTOR_ROLE)` instead of just `onlyRoles(EXECUTOR_ROLE)`

**Recommendation:**
```solidity
function initialize(...) external virtual initializer {
    // ... existing code ...
    _initializeOwner(_owner);
    _grantRoles(_owner, EXECUTOR_ROLE); // Add this line
}
```

---

### 2. Implementation Contract Not Protected Against Direct Initialization

**Location:** `src/MinimalSmartAccount.sol`

**Issue:** The implementation contract (not the proxy) can be directly initialized by anyone. The `Initializable` contract from Solady provides `_disableInitializers()` which should be called in the constructor to prevent this.

**Attack Scenario:**
1. Attacker calls `initialize()` directly on the implementation contract
2. Attacker becomes the owner of the implementation
3. Attacker can call `upgradeToAndCall()` on the implementation (though limited due to `onlyProxy` modifier)

While the `onlyProxy` modifier on `upgradeToAndCall()` prevents direct upgrade on the implementation, it's still a best practice to lock the implementation.

**Recommendation:** Add a constructor:
```solidity
constructor() {
    _disableInitializers();
}
```

---

## 🟠 HIGH Vulnerabilities

### 3. Empty CallData Extraction Can Cause Revert

**Location:** `src/MinimalSmartAccount.sol:161-162`

```solidity
bytes4 _functionSig = bytes4(executions[_i].callData);
bytes memory _params = executions[_i].callData[4:];
```

**Issue:** If `callData` is empty (length 0), this will either:
- Revert on `bytes4()` conversion, OR
- Produce incorrect behavior

An execution with empty callData is a valid ETH transfer (sending value to a contract's receive/fallback function).

**Impact:** Users cannot perform simple ETH transfers through the smart account.

**Recommendation:** Add a check:
```solidity
bytes4 _functionSig;
bytes memory _params;
if (executions[_i].callData.length >= 4) {
    _functionSig = bytes4(executions[_i].callData);
    _params = executions[_i].callData[4:];
} else {
    _functionSig = bytes4(0);
    _params = executions[_i].callData;
}
```

---

### 4. Registry Can Be Set to Zero Address

**Location:** `src/MinimalSmartAccount.sol:93`

```solidity
$.registry = _registryAddress;
```

**Issue:** No validation that `_registryAddress != address(0)`. If set to zero address, all executions will fail when calling `authorizeAdapterCall()` on a non-existent contract.

**Impact:** Bricked smart account that cannot execute any transactions.

**Recommendation:**
```solidity
require(address(_registryAddress) != address(0), "Invalid registry");
```

---

### 5. TRY Mode Still Reverts on Registry Authorization Failure

**Location:** `src/MinimalSmartAccount.sol:193`

```solidity
function _tryExec(...) internal virtual returns (bytes[] memory result) {
    // ...
    _registry.authorizeAdapterCall(executions[_i].target, _functionSig, _params);
    // Then tryCall...
}
```

**Issue:** In `_tryExec()` (TRY mode), the registry authorization call is NOT wrapped in a try-catch. If the registry reverts (denies authorization), the entire batch fails even in TRY mode.

**Expected Behavior:** TRY mode should catch authorization failures and emit `TryExecutionFailed`, not revert the entire batch.

**Impact:** TRY mode doesn't work as expected when authorization fails.

**Recommendation:** Wrap registry call in try-catch for TRY mode:
```solidity
try _registry.authorizeAdapterCall(...) {
    // Execute
} catch {
    emit TryExecutionFailed(_i);
    continue;
}
```

---

## 🟡 MEDIUM Vulnerabilities

### 6. Dual Admin Pattern Creates Confusion

**Location:** `src/MinimalSmartAccountFactory.sol` and `src/MinimalSmartAccount.sol`

**Issue:** There are TWO separate admin/owner concepts:
1. **Factory Admin:** Stored at `shl(96, proxy)` slot in factory - can upgrade proxies
2. **Account Owner:** Stored in `_OWNER_SLOT` in the proxy - can grant roles

These are independent entities that can be different addresses. The factory's `upgrade()` and `upgradeAndCall()` are controlled by the **Factory Admin**, NOT the Account Owner.

**However,** the `upgradeToAndCall()` function in `UUPSUpgradeable.sol` is protected by `_authorizeUpgrade()` which checks for **Account Owner**.

This creates a situation where:
- Factory Admin can set implementation slot directly
- Account Owner can upgrade via `upgradeToAndCall()`

**Impact:** Confusing dual-control over upgrades. The factory admin can bypass owner-controlled upgrades.

**Recommendation:** Document this clearly or consolidate control to a single entity.

---

### 7. No Event on Initialize

**Location:** `src/MinimalSmartAccount.sol:83-96`

**Issue:** The `initialize()` function doesn't emit a custom event with the initialized parameters (owner, registry, accountId).

**Impact:** Difficult to track off-chain what registry was set for each account.

**Recommendation:** Add an event:
```solidity
event AccountInitialized(address indexed owner, address indexed registry, string accountId);
```

---

### 8. ADMIN_ROLE Is Defined But Never Used

**Location:** `src/MinimalSmartAccount.sol:33`

```solidity
uint256 internal constant ADMIN_ROLE = _ROLE_0;
```

**Issue:** `ADMIN_ROLE` is defined but never used anywhere in the contract. This suggests incomplete implementation or leftover code.

**Impact:** Potentially confusing for integrators; dead code.

**Recommendation:** Either use it or remove it.

---

## 🔵 LOW / INFORMATIONAL

### 9. Nonce Incremented Before Execution

**Location:** `src/MinimalSmartAccount.sol:159, 188`

```solidity
++$.nonce;  // Before execution
```

**Issue:** Nonce is incremented before execution, not after. While this prevents replay attacks, it means:
- In DEFAULT mode: If execution fails, nonce is still consumed
- In TRY mode: Correct behavior

This is a design choice, not a vulnerability, but worth noting.

---

### 10. No Getter for Registry

**Location:** `src/MinimalSmartAccount.sol`

**Issue:** There's no public getter function to read the registry address. While `accountId()` and `nonce()` are exposed, the registry is not.

**Recommendation:** Add:
```solidity
function registry() public view returns (IRegistry) {
    return _getMinimalAccountStorage().registry;
}
```

---

### 11. Salt Validation Allows Zero-Prefix Salt

**Location:** `src/MinimalSmartAccountFactory.sol:188`

```solidity
if iszero(or(iszero(shr(96, salt)), eq(caller(), shr(96, salt)))) {
```

**Issue:** Any salt starting with `0x0000...` (160 zero bits) can be used by anyone. This is intentional for vanity address mining but could lead to front-running if users don't understand this.

**Recommendation:** Document this behavior clearly.

---

### 12. No Reentrancy Guard on Execute

**Location:** `src/MinimalSmartAccount.sol:103`

**Issue:** The `execute()` function has no reentrancy protection. While the current implementation doesn't appear vulnerable (no state changes after external calls that could be exploited), this could become a concern in future upgrades.

**Note:** This is currently safe because:
- State (nonce) is incremented before external calls
- No vulnerable state is read after external calls

**Recommendation:** Consider adding `nonReentrant` modifier for defense-in-depth, especially for upgradeable contracts.

---

### 13. receive() Doesn't Emit Event

**Location:** `src/MinimalSmartAccount.sol:230`

```solidity
receive() external payable { }
```

**Issue:** The `receive()` function doesn't emit the `EtherReceived` event that is defined in the contract (line 72).

**Impact:** ETH received via direct transfer is not logged.

**Recommendation:**
```solidity
receive() external payable {
    emit EtherReceived(msg.sender, msg.value);
}
```

---

### 14. TRY Mode Uses Unlimited Gas

**Location:** `src/MinimalSmartAccount.sol:196-197`

```solidity
(bool _success,, bytes memory _callResult) = executions[_i].target
    .tryCall(executions[_i].value, type(uint256).max, type(uint16).max, executions[_i].callData);
```

**Issue:** `type(uint256).max` gas stipend and `type(uint16).max` return data copy. While intentional for flexibility, this removes the gas-limiting safety that `tryCall` typically provides.

**Impact:** A malicious target contract could consume all gas.

---

## Summary Table

| # | Severity | Issue | Status |
|---|----------|-------|--------|
| 1 | CRITICAL | No EXECUTOR_ROLE granted on initialize | Unmitigated |
| 2 | CRITICAL | Implementation not locked | Unmitigated |
| 3 | HIGH | Empty callData causes revert | Unmitigated |
| 4 | HIGH | Registry can be zero address | Unmitigated |
| 5 | HIGH | TRY mode reverts on auth failure | Unmitigated |
| 6 | MEDIUM | Dual admin pattern confusion | Design Issue |
| 7 | MEDIUM | No Initialize event | Unmitigated |
| 8 | MEDIUM | ADMIN_ROLE unused | Dead Code |
| 9 | INFO | Nonce incremented before exec | Design Choice |
| 10 | INFO | No registry getter | Missing Feature |
| 11 | INFO | Zero-prefix salt anyone can use | Expected Behavior |
| 12 | INFO | No reentrancy guard | Consider Adding |
| 13 | INFO | receive() missing event | Inconsistency |
| 14 | INFO | TRY mode unlimited gas | Design Choice |

---

## Appendix: Files Reviewed

- `src/MinimalSmartAccount.sol`
- `src/MinimalSmartAccountFactory.sol`
- `src/interfaces/IMinimalSmartAccount.sol`
- `src/interfaces/IRegistry.sol`
- `src/libraries/ModeLib.sol`
- `src/libraries/ExecutionLib.sol`
- `src/vendor/Ownable.sol`
- `src/vendor/OwnableRoles.sol`
- `src/vendor/UUPSUpgradeable.sol`
- `src/vendor/Initializable.sol`
- `src/vendor/LibCall.sol`
- `src/vendor/CallContextChecker.sol`
