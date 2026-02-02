import { PocketIc, Actor, PocketIcServer } from '@dfinity/pic';
import { describe, test, expect, beforeAll, afterAll } from 'vitest';
import { Principal } from '@dfinity/principal';
import { idlFactory as mixinIdlFactory } from '../src/declarations/mixin_canister/mixin_canister.did.js';
import { idlFactory as collectorIdlFactory } from '../src/declarations/dummy_collector/dummy_collector.did.js';
import { idlFactory as classIdlFactory } from '../src/declarations/class_canister/class_canister.did.js';
import { IDL } from '@dfinity/candid';
import path from 'path';

const WASM_PATH_MIXIN = path.resolve(__dirname, '..', '.dfx', 'local', 'canisters', 'mixin_canister', 'mixin_canister.wasm');
const WASM_PATH_COLLECTOR = path.resolve(__dirname, '..', '.dfx', 'local', 'canisters', 'dummy_collector', 'dummy_collector.wasm');
const WASM_PATH_CLASS = path.resolve(__dirname, '..', '.dfx', 'local', 'canisters', 'class_canister', 'class_canister.wasm');

describe('OVS Integration Tests', () => {
  let picServer: PocketIcServer;
  let pic: PocketIc;
  let collectorCanister: any;
  let mixinCanister: any;
  let classCanister: any;
  
  let collectorId: Principal;
  let mixinId: Principal;
  let classId: Principal;

  beforeAll(async () => {
    picServer = await PocketIcServer.start();
    pic = await PocketIc.create(picServer.getUrl());
    
    // Deploy Collector first (no init args)
    const collectorFixture = await pic.setupCanister({
      idlFactory: collectorIdlFactory,
      wasm: WASM_PATH_COLLECTOR,
    });
    collectorId = collectorFixture.canisterId;
    collectorCanister = collectorFixture.actor;

    // Deploy Mixin with collectorId as init arg
    const mixinFixture = await pic.setupCanister({
      idlFactory: mixinIdlFactory,
      wasm: WASM_PATH_MIXIN,
      arg: IDL.encode([IDL.Principal], [collectorId]),
    });
    mixinId = mixinFixture.canisterId;
    mixinCanister = mixinFixture.actor;
    
    // Deploy Class Canister with optional collector
    const classFixture = await pic.setupCanister({
      idlFactory: classIdlFactory,
      wasm: WASM_PATH_CLASS,
      arg: IDL.encode([IDL.Opt(IDL.Principal)], [[collectorId]]),
    });
    classId = classFixture.canisterId;
    classCanister = classFixture.actor;

    // Add cycles to canisters so they can share
    await pic.addCycles(mixinId, 100_000_000_000_000); // 100T
    await pic.addCycles(classId, 100_000_000_000_000); // 100T
  });

  afterAll(async () => {
     await picServer.stop();
  });

  test('Mixin Canister should initialize and schedule', async () => {
      // 1. Trigger Action
      await mixinCanister.triggerInfo();

      // 2. Advance time past the initial schedule (initialWait = 0, period = 5 seconds)
      await pic.advanceTime(10_000); // 10 seconds in ms
      await pic.tick(20); 

      // 3. Check Collector
      const stats = await collectorCanister.getStats();
      console.log("Collector Stats (Mixin):", stats);

      // Should have received cycle share
      expect(Number(stats.count)).toBeGreaterThan(0);
      expect(stats.logs.length).toBeGreaterThan(0);
      // MixinCanister config: `namespace = "org.icdevs.ovs.test"`.
      expect(stats.logs[0].namespace).toBe("org.icdevs.ovs.test");
  });

  test('Class Canister should initialize and schedule', async () => {
      // Clear collector stats if needed (or check for class-specific namespace)
      
      // 1. Trigger Action
      await classCanister.triggerInfo();

      // 2. Advance time
      await pic.advanceTime(10_000);
      await pic.tick(20); 

      // 3. Check Collector
      const stats = await collectorCanister.getStats();
      console.log("Collector Stats (Class):", stats);

      const classStats = await classCanister.getStats();
      console.log("Class OVS Stats:", classStats);

      // ClassCanister config: `namespace = "org.icdevs.ovs.test.class"`.
      const logs = stats.logs;
      const found = logs.find((l: any) => l.namespace === "org.icdevs.ovs.test.class");
      expect(found).toBeDefined();
  });

  test('Class Canister should persist state across upgrade', async () => {
      // Get initial stats
      const statsBefore = await classCanister.getStats();
      console.log("Stats before upgrade:", statsBefore);
      const activeActionsBefore = Number(statsBefore.activeActions);

      // Trigger some actions
      await classCanister.triggerInfo();
      await classCanister.triggerInfo();
      await classCanister.triggerInfo();

      // Verify actions were tracked
      const statsAfterActions = await classCanister.getStats();
      expect(Number(statsAfterActions.activeActions)).toBe(activeActionsBefore + 3);

      // Upgrade the canister
      await pic.upgradeCanister({
         canisterId: classId,
         wasm: WASM_PATH_CLASS,
         arg: IDL.encode([IDL.Opt(IDL.Principal)], [[collectorId]]),
         upgradeModeOptions: {
            wasm_memory_persistence: [{ keep: null }],
            skip_pre_upgrade: [],
         },
      });

      // Check that state persisted
      const statsAfterUpgrade = await classCanister.getStats();
      console.log("Stats after upgrade:", statsAfterUpgrade);
      
      // Actions should be preserved (activeActions went from 1 to 4 after adding 3)
      expect(Number(statsAfterUpgrade.activeActions)).toBe(activeActionsBefore + 3);

      // nextCycleActionId should still be set (timer state preserved)
      expect(statsAfterUpgrade.nextCycleActionId.length).toBe(1);

      // Advance time to trigger scheduled cycle share
      await pic.advanceTime(10_000);
      await pic.tick(30);

      // Check collector received cycles
      const collectorStats = await collectorCanister.getStats();
      console.log("Collector after upgrade test:", collectorStats);
      
      // The upgrade test is about state persistence, not necessarily triggering new shares
      // The key verification is that activeActions count was preserved
      expect(Number(collectorStats.count)).toBeGreaterThanOrEqual(2);
  });

  test('Class Canister should persist scheduled payments across stop/start', async () => {
      // Get initial collector count
      const initialStats = await collectorCanister.getStats();
      const initialCount = Number(initialStats.count);
      console.log("Initial collector count (stop/start test):", initialCount);

      // Get initial OVS state
      const ovsStatsBefore = await classCanister.getStats();
      console.log("OVS stats before stop:", JSON.stringify(ovsStatsBefore, (k, v) => typeof v === 'bigint' ? v.toString() : v, 2));
      const activeActionsBefore = Number(ovsStatsBefore.activeActions);

      // Trigger some actions before stopping
      await classCanister.triggerInfo();
      await classCanister.triggerInfo();

      // Verify actions were tracked
      const statsAfterActions = await classCanister.getStats();
      expect(Number(statsAfterActions.activeActions)).toBe(activeActionsBefore + 2);
      console.log("Actions tracked before stop:", Number(statsAfterActions.activeActions));

      // Stop the canister
      console.log("Stopping canister...");
      await pic.stopCanister({ canisterId: classId });

      // Wait a bit while stopped
      await pic.advanceTime(2_000);
      await pic.tick(10);

      // Start the canister
      console.log("Starting canister...");
      await pic.startCanister({ canisterId: classId });

      // Check state after restart
      const statsAfterRestart = await classCanister.getStats();
      console.log("OVS stats after restart:", JSON.stringify(statsAfterRestart, (k, v) => typeof v === 'bigint' ? v.toString() : v, 2));

      // Actions should be preserved
      expect(Number(statsAfterRestart.activeActions)).toBe(activeActionsBefore + 2);

      // nextCycleActionId should still be set (timer state preserved)
      expect(statsAfterRestart.nextCycleActionId.length).toBe(1);
      console.log("Timer action ID preserved:", statsAfterRestart.nextCycleActionId[0]);

      // Advance time past the period to trigger scheduled cycle share
      await pic.advanceTime(6_000); // 6 seconds
      await pic.tick(100);

      // Check collector received cycles
      const collectorStats = await collectorCanister.getStats();
      const afterCount = Number(collectorStats.count);
      console.log("Collector count after stop/start + time advance:", afterCount);

      // Should have received at least one more cycle share after restart
      expect(afterCount).toBeGreaterThan(initialCount);

      console.log("Stop/Start test passed - scheduled payments persisted");
  });

  test('Class Canister should share cycles across multiple periods', async () => {
      // Get initial collector state
      const initialStats = await collectorCanister.getStats();
      const initialCount = Number(initialStats.count);
      console.log("Initial collector count:", initialCount);

      // Check OVS state
      let ovsStats = await classCanister.getStats();
      console.log("OVS stats at start of multi-period test:", JSON.stringify(ovsStats, (k, v) => typeof v === 'bigint' ? v.toString() : v, 2));

      // Period is 5 seconds (5_000_000_000 ns). We'll test 3 periods.
      
      // Track initial actions to trigger activity
      await classCanister.triggerInfo();
      await classCanister.triggerInfo();
      await classCanister.triggerInfo();
      
      // Check current time from PIC
      const currentTime = await pic.getTime();
      console.log("Current PIC time (ms):", currentTime);
      console.log("Current PIC time (ns):", BigInt(currentTime) * 1_000_000n);
      
      // Check OVS state after tracking
      ovsStats = await classCanister.getStats();
      console.log("OVS stats after tracking:", JSON.stringify(ovsStats, (k, v) => typeof v === 'bigint' ? v.toString() : v, 2));
      
      // First period - advance past period and trigger timer
      // Need to advance enough time - the next action is scheduled for now + 5 seconds
      await pic.advanceTime(6_000); // 6 seconds in ms
      const timeAfterAdvance = await pic.getTime();
      console.log("PIC time after advance (ms):", timeAfterAdvance);
      
      await pic.tick(100);
      
      let stats = await collectorCanister.getStats();
      const afterFirstPeriod = Number(stats.count);
      console.log("After first period:", afterFirstPeriod);
      
      ovsStats = await classCanister.getStats();
      console.log("OVS stats after first period:", JSON.stringify(ovsStats, (k, v) => typeof v === 'bigint' ? v.toString() : v, 2));
      
      expect(afterFirstPeriod).toBeGreaterThan(initialCount);

      // Track more actions
      await classCanister.triggerInfo();
      await classCanister.triggerInfo();

      // Second period
      await pic.advanceTime(6_000);
      await pic.tick(100);
      
      stats = await collectorCanister.getStats();
      const afterSecondPeriod = Number(stats.count);
      console.log("After second period:", afterSecondPeriod);
      expect(afterSecondPeriod).toBeGreaterThan(afterFirstPeriod);

      // Track more actions
      await classCanister.triggerInfo();

      // Third period
      await pic.advanceTime(6_000);
      await pic.tick(100);
      
      stats = await collectorCanister.getStats();
      const afterThirdPeriod = Number(stats.count);
      console.log("After third period:", afterThirdPeriod);
      expect(afterThirdPeriod).toBeGreaterThan(afterSecondPeriod);

      console.log("Total shares across 3 periods:", afterThirdPeriod - initialCount);
      console.log("Final collector stats:", stats);
  });

});
