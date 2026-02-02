# OVS-Fixed Refactoring and Verification Workplan

## Context
The goal is to refactor the `ovs-fixed` library to utilize the `ClassPlus` pattern for initialization and state management. This improves modularity and standardization. We need to update the library, the mixin, create examples for both usage patterns (Class vs Mixin), and rigorously test them using PocketIC (PIC) to ensure functionality, persistence, and upgrade safety of the cycle sharing mechanism.

## Workspace
Root: `/Users/afat/Dropbox/development/ICDevs/projects/ovs-fixed`

## Tasks

### Phase 1: Library Refactoring

- [x] **Step 1: Implement ClassPlus in `src/lib.mo`** ✅
  - Import `ClassPlus` library.
  - Define `InitArgs`, `Environment`, and `State` types clearly if not already defined.
  - Wrap the `OVS` class logic within the `ClassPlus` pattern.
  - Define the `Init` function using `ClassPlus.BuildInitSystem`.
  - Ensure the internal `TimerTool` logic is compatible with the ClassPlus lifecycle (init/upgrade).

- [x] **Step 2: Refactor `src/OVSMixin.mo`** ✅
  - Update the mixin to accept the configuration parameters required by the new `lib.mo` structure.
  - Instantiate the `OVS` class using the new `Init` (Or `InitDirect` if strictly necessary for mixins, but preferably standard Init) pattern.
  - Ensure `system` capability is correctly propagated.

### Phase 2: Example Canisters

- [x] **Step 3: Setup Project Structure for Examples** ✅
  - Create `src/examples/` directory.
  - Copy/Create a `DummyCollector.mo` (from `ICRC_fungible` or create fresh) to receive cycles.

- [x] **Step 4: Create Mixin Example** ✅
  - Create `src/examples/MixinCanister.mo`.
  - Implement a basic actor importing `OVSMixin`.
  - Expose a method to trigger actions (e.g., `triggerInfo`).

- [x] **Step 5: Create Base Class Example** ✅
  - Create `src/examples/ClassCanister.mo`.
  - Implement a basic actor importing `OVS` from `lib.mo`.
  - Initialize it using `ClassPlus` boilerplate.
  - Expose a method to trigger actions.

- [x] **Step 6: Configure Build** ✅
  - Update `dfx.json` to include:
    - `mixin_canister`
    - `class_canister`
    - `dummy_collector`

### Phase 3: Verification (PIC)

- [x] **Step 7: Create Test Suite** ✅
  - Create `pic/ovs.test.ts`.
  - Configure vitest, tsconfig, package.json.

- [x] **Step 8: Implement Functional Tests** ✅
  - Test Case: **Initial Cycle Share**.
    - Deploy Collector, MixinCanister, ClassCanister.
    - Fund Canisters.
    - Trigger actions (call `triggerInfo`).
    - Advance time past the schedule.
    - Assert `DummyCollector` received cycles.
    - Assert `getStats` shows updated data.
  - Test Case: **Multi-Period Cycle Sharing** ✅
    - Verify timer reschedules across multiple periods.
    - Confirmed 3 shares over 3 time periods.

- [x] **Step 9: Implement Persistence Tests (Stop/Start)** ✅
  - Test Case: **Stop/Start**.
    - Trigger actions.
    - Stop Canister.
    - Start Canister.
    - Advance time.
    - Assert scheduled payments still occur.
    - Verified: activeActions preserved, nextCycleActionId preserved, timer fires after restart.

- [x] **Step 10: Implement Upgrade Tests** ✅
  - Test Case: **Upgrade**.
    - Trigger actions.
    - Install Code (Upgrade) with same WASM using `wasm_memory_persistence`.
    - Advance time.
    - Assert scheduled payments still occur.
    - Assert `activeActions` count was preserved.

### Phase 4: Final Review
- [x] Review code for `system` capability safety. ✅
  - All `<system>` parameters properly scoped to transient contexts
  - Timer operations correctly use system capability
  - No system capability escapes to stable storage
  - ClassPlus integration safely propagates system capability through `wrappedOnInitialize`
- [x] Ensure all types are exported correctly. ✅
  - Core types: `State`, `OVSState`, `ICRC85State`, `OVSStats`, `Environment`, `InitArgs`, `OVSConfig`
  - Function args: `InitFunctionArgs`, `MixinFunctionArgs`
  - Utility types: `Map`, `Value`, `ActionId`, `Action`, `Error`
  - Constants: `OneDay`, `OneXDR`
  - Functions: `Init`, `initialState`, `shareCycles`
  - Class: `OVS`

## Summary
All tasks completed ✅. The OVS library has been successfully refactored to use ClassPlus pattern with:
- Full PocketIC test coverage (5 tests passing)
- Mixin and Class usage examples
- Verified persistence across upgrades and stop/start
- Multi-period timer rescheduling verified
- Safe system capability handling
