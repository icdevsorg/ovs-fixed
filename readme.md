# ovs-fixed

**ICRC-85 Open Value Sharing for Motoko**

A ClassPlus-based library for automatic cycle sharing on the Internet Computer. Implements the [ICRC-85 Open Value Sharing](https://github.com/dfinity/ICRC/issues/85) standard to share a portion of your canister's cycles with infrastructure providers and the community.

## Installation

```bash
mops add ovs-fixed
```

## Quick Start (Mixin Pattern)

The easiest way to add OVS to your canister is with the mixin pattern:

```motoko
import OVSMixin "mo:ovs-fixed/OVSMixin";
import OVS "mo:ovs-fixed";
import TTMixin "mo:timer-tool/TimerToolMixin";
import TT "mo:timer-tool";
import ClassPlus "mo:class-plus";
import Principal "mo:core/Principal";

shared ({ caller = _owner }) persistent actor class MyCanister() = this {

  transient let canisterId = Principal.fromActor(this);
  transient let org_icdevs_class_plus_manager = ClassPlus.ClassPlusInitializationManager<system>(_owner, canisterId, true);

  // 1. Include TimerTool mixin (required by OVS)
  include TTMixin({
    config = {
      org_icdevs_class_plus_manager = manager;
      args = null;
      pullEnvironment = ?(func() : TT.Environment {{      
        advanced = null;
        reportExecution = null;
        reportError = null;
        syncUnsafe = null;
        reportBatch = null;
      }});
      onInitialize = null;
    };
    caller = _owner;
    canisterId = canisterId;
  });

  // 2. Configure OVS
  let ovsConfig : OVS.InitArgs = {
    namespace = "com.example.mycanister";    // Your namespace for cycle reporting
    publicNamespace = "ovs:example:mycan";   // Timer action namespace
    baseCycles = 1_000_000_000_000;          // 1 XDR base
    actionDivisor = 10_000;                  // Add bonus per 10K actions
    actionMultiplier = 1_000_000_000_000;    // 1 XDR bonus per tier
    maxCycles = 10_000_000_000_000;          // 10 XDR max
    initialWait = null;                      // Default: 7 days grace period
    period = null;                           // Default: 30 days
    asset = null;                            // Default: "cycles"
    platform = null;                         // Default: "icp"
    resetAtEndOfPeriod = true;               // Indicates that the payment is action based on a period level
  };

  func getEnvironment() : OVS.Environment {{
    var org_icdevs_timer_tool = ?org_icdevs_timer_tool;
    var collector = null;  // Default: ICRC-85 collector
    advanced = null;       // Optional: kill_switch, handler, tree
  }};

  // 3. Include OVS mixin
  include OVSMixin({
    config = {
      args = ?ovsConfig;
      pullEnvironment = ?getEnvironment;
      org_icdevs_class_plus_manager = manager;
      onInitialize = null;
    };
    caller = _owner;
    canisterId = canisterId;
  });

  // 4. Track actions in your business logic
  public shared func transfer() : async () {
    org_icdevs_ovs_fixed.trackAction();
    // ... your transfer logic
  };

  public shared query func getOVSStats() : async OVS.OVSStats {
    org_icdevs_ovs_fixed.getStats();
  };
};
```

## How It Works

OVS automatically shares cycles with the ICRC-85 collector based on:

1. **Grace Period**: 7 days after initialization before first share (configurable)
2. **Recurring Shares**: Every 30 days thereafter (configurable)
3. **Action-Based Calculation**: More actions = more cycles shared (up to maxCycles)

### Cycle Calculation Formula

```
cyclesToShare = baseCycles + (actions / actionDivisor) * actionMultiplier
cyclesToShare = min(cyclesToShare, maxCycles)
```

**Example**: With defaults of `baseCycles=1T`, `actionDivisor=10000`, `actionMultiplier=1T`:
- 0 actions: 1 XDR (base)
- 10,000 actions: 2 XDR
- 50,000 actions: 6 XDR
- 100,000+ actions: capped at maxCycles

## Core Types

### InitArgs (Configuration)

```motoko
type InitArgs = {
  namespace: Text;           // Reporting namespace (e.g., "com.example.myapp")
  publicNamespace: Text;     // Timer action namespace (e.g., "ovs:example:myapp")
  baseCycles: Nat;           // Base cycles per period (1T = 1 XDR)
  actionDivisor: Nat;        // Actions per bonus tier
  actionMultiplier: Nat;     // Cycles added per bonus tier
  maxCycles: Nat;            // Maximum cycles per period
  initialWait: ?Nat;         // Nanoseconds before first share (default: 7 days)
  period: ?Nat;              // Nanoseconds between shares (default: 30 days)
  asset: ?Text;              // Asset type (default: "cycles")
  platform: ?Text;           // Platform (default: "icp")
  resetAtEndOfPeriod: Bool;  // If True, active actions reset upon period payment, if false, active acctions acculate.
};
```

### Environment

```motoko
type Environment = {
  org_icdevs_timer_tool: ?TT.TimerTool;                        // TimerTool instance (required)
  var collector: ?Principal;                // Custom collector (default: ICRC-85)
  advanced: ?AdvancedEnvironment;           // Optional advanced settings
};

type AdvancedEnvironment = {
  kill_switch: ?Bool;                       // Disable sharing when true
  handler: ?(([(Text, Map)]) -> ());        // Custom handler (overrides default)
  tree: ?[Text];                            // Optional categorization
};
```

### State

```motoko
type State = {
  var nextCycleActionId: ?Nat;   // Scheduled timer action ID
  var lastActionReported: ?Nat;  // Timestamp of last share
  var activeActions: Nat;        // Actions since last share
};
```

### OVSStats

```motoko
type OVSStats = {
  activeActions: Nat;             // Current action count
  lastActionReported: ?Nat;       // Last share timestamp
  nextCycleActionId: ?Nat;        // Next scheduled action
  timerToolStats: ?TT.Stats;      // Underlying timer stats
};
```

## API Reference

### OVS Class Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `initialize` | `<system>() -> async* ()` | Start the OVS timer (auto-called by Init) |
| `trackAction` | `() -> ()` | Increment the action counter |
| `getStats` | `() -> OVSStats` | Get current OVS statistics |
| `calculateCyclesToShare` | `() -> (cycles: Nat, actions: Nat)` | Preview cycle calculation |

### Module Functions

| Function | Description |
|----------|-------------|
| `OVS.Init(config)` | Create OVS initializer with auto-start |
| `OVS.initialState()` | Create initial state for storage |
| `OVS.shareCycles<system>(request)` | Low-level cycle sharing (for custom implementations) |

## ClassPlus Direct Pattern

For more control, use the ClassPlus pattern directly:

```motoko
import OVS "mo:ovs-fixed";
import ClassPlus "mo:class-plus";
import TTMixin "mo:timer-tool/TimerToolMixin";
import TT "mo:timer-tool";
import Principal "mo:core/Principal";

shared ({ caller = _owner }) persistent actor class MyCanister() = this {

  var ovs_state = OVS.initialState();
  var collectorOverride : ?Principal = null;
  
  transient let canisterId = Principal.fromActor(this);
  transient let org_icdevs_class_plus_manager = ClassPlus.ClassPlusInitializationManager<system>(_owner, canisterId, true);

  // Include TimerTool
  include TTMixin({
    config = {
      org_icdevs_class_plus_manager = manager;
      args = null;
      pullEnvironment = ?(func() : TT.Environment {{      
        advanced = null;
        reportExecution = null;
        reportError = null;
        syncUnsafe = null;
        reportBatch = null;
      }});
      onInitialize = null;
    };
    caller = _owner;
    canisterId = canisterId;
  }); 

  let ovsConfig : OVS.InitArgs = {
    namespace = "com.example.mycanister";
    publicNamespace = "ovs:example:mycanister";
    baseCycles = 1_000_000_000_000;
    actionDivisor = 10_000;
    actionMultiplier = 1_000_000_000_000;
    maxCycles = 10_000_000_000_000;
    initialWait = null;
    period = null;
    asset = null;
    platform = null;
    resetAtEndOfPeriod = true;
  };

  func getEnv() : OVS.Environment {{
    var org_icdevs_timer_tool = ?org_icdevs_timer_tool;
    var collector = collectorOverride;
    advanced = null;
  }};

  transient var ovs = OVS.Init({
    org_icdevs_class_plus_manager = manager;
    args = ?ovsConfig;
    pullEnvironment = ?getEnv;
    onInitialize = null;
    initialState = ovs_state;
    onStorageChange = func(state : OVS.State) {
      ovs_state := state;
    };
  })();

  public shared func setCollector(p: ?Principal) : async () {
    collectorOverride := p;
    ovs.environment.collector := p;
  };

  public shared func doAction() : async () {
    ovs.trackAction();
  };

  public shared query func getStats() : async OVS.OVSStats {
    ovs.getStats();
  };
};
```

## Environment Callbacks

### kill_switch

Disable cycle sharing without removing the code:

```motoko
func getEnvironment() : OVS.Environment {{
  var org_icdevs_timer_tool = ?org_icdevs_timer_tool;
  var collector = null;
  advanced = ?{
    kill_switch = ?true;  // Disables sharing
    handler = null;
    tree = null;
  };
}};
```

### handler

Override the default sharing behavior:

```motoko
func getEnvironment() : OVS.Environment {{
  var org_icdevs_timer_tool = ?org_icdevs_timer_tool;
  var collector = null;
  advanced = ?{
    kill_switch = null;
    handler = ?(func(data: [(Text, OVS.Map)]) {
      // Custom handling - data contains share info
      Debug.print("Would share: " # debug_show(data));
    });
    tree = null;
  };
}};
```

### tree

Indicates that your component uses items underneath it:

```motoko
func getEnvironment() : OVS.Environment {{
  var org_icdevs_timer_tool = ?org_icdevs_timer_tool;
  var collector = null;
  advanced = ?{
    kill_switch = null;
    handler = null;
    tree = ?["org.icdevs.timer_tool"];
  };
}};
```

### collector

Specify a custom collector (top-level, not in advanced):

```motoko
func getEnvironment() : OVS.Environment {{
  var org_icdevs_timer_tool = ?org_icdevs_timer_tool;
  var collector = ?Principal.fromText("aaaaa-aa");
  advanced = null;
}};
```

## Constants

```motoko
public let OneDay = 86_400_000_000_000;       // 24 hours in nanoseconds
public let OneXDR = 1_000_000_000_000;        // ~1 XDR in cycles
let MAX_CYCLES = 1_000_000_000_000_000;       // 1000 XDR hard limit
let COLLECTOR = "q26le-iqaaa-aaaam-actsa-cai"; // Default ICRC-85 collector
```

## Namespace Registration

Before sharing cycles, ensure you have registered or can claim your namespace with the ICRC-85 collector. The namespace should follow reverse domain notation:

- ✅ `com.example.myapp`
- ✅ `org.icdevs.libraries.mylib`
- ❌ `myapp` (too generic)

## Safety Features

1. **Balance Protection**: Never shares more than 50% of canister's cycle balance
2. **Hard Cap**: Maximum 1000 XDR per share (1,000,000,000,000,000 cycles)
3. **Grace Period**: 7 days before first share (configurable)
4. **Kill Switch**: Instant disable without code changes

## Dependencies

- [timer-tool](https://mops.one/timer-tool) - Timer management
- [class-plus](https://mops.one/class-plus) - ClassPlus pattern
- [map](https://mops.one/map) - Efficient maps
- [star](https://mops.one/star) - Result type

## License

MIT License. See [LICENSE](LICENSE) for details.

---

Built by [ICDevs.org](https://ICDevs.org). If you find this library valuable, please consider a [donation](https://icdevs.org/donations.html) to support open-source development on the Internet Computer.