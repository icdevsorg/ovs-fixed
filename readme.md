# ICRC-85 Fixed Open Value Sharing Strategy

## Overview

This project implements an Open Value Sharing (OVS) strategy that facilitates the sharing of a specified number of cycles within the Internet Computer ecosystem. The core functionality is defined in a single module that handles the sharing process based on various configurable parameters.

## Key Features

- **Cycle Sharing:** Efficiently shares cycles with a specified collector.
- **Configurable Environment:** Allows customization through the `ICRC85Environment` type, including options for a kill switch, handler, period, asset, platform, and tree.
- **Debugging Support:** Provides debug channels for announcements and cycle-sharing events.

## Dependencies

Dependencies can be found in the mops.toml file.

## Usage

### Environment Configuration

The environment configuration is specified using the `ICRC85Environment` type, which includes optional parameters:

- `kill_switch`: A boolean flag to stop the sharing process if set to true.
- `handler`: A function to handle custom actions and will override the default behavior as specified in ICRC85.
- `period`: The interval between cycle-sharing actions.
- `asset`: The type of asset being shared (default is "cycles").
- `platform`: The platform identifier (default is "icp").
- `tree`: An optional array of text values.
- `collector`: The principal identifier of the cycle collector (default is `COLLECTOR`).

### State configuration

This library assumes you are tracking ICRC85 state in the following format:

```motoko
    public type ICRC85State = {
      var nextCycleActionId: ?Nat; //next timer action Id
      var lastActionReported: ?Nat; //last report of cycles
      var activeActions: Nat; //number of active actions used to report with
    };
```

### Sharing Cycles

The `shareCycles` function initiates the cycle-sharing process based on the provided request. The request includes the environment configuration, the number of cycles to share, the number of actions, the reporting period, a namespace, and a scheduling function.

#### Example Usage

If you use the Class Plus patter we suggest using the following function in your class Initialization function to trigger the initial cycle share:

```motoko

public let ICRC85_Timer_Namespace = "icrc85:ovs:shareaction:your_class";
public let ICRC85_Payment_Namespace = "com.your_com.libraries.your_class";


public func Init<system>(config : {
    manager: ClassPlusLib.ClassPlusInitializationManager;
    initialState: State;
    args : ?InitArgs;
    pullEnvironment : ?(() -> Environment);
    onInitialize: ?(YourClass -> async*());
    onStorageChange : ((State) ->())
  }) : () -> YourClass {

    let instance = ClassPlusLib.ClassPlus<system,
      YourClass,
      State,
      InitArgs,
      Environment>({config with constructor = Local_log}).get;

    ovsfixed.initialize_cycleShare<system>({
      namespace = ICRC85_Timer_Namespace;
      icrc_85_state = instance().getState().icrc85;
      wait = null;
      registerExecutionListenerAsync = instance().environment.tt.registerExecutionListenerAsync;
      setActionSync = instance().environment.tt.setActionSync;  
      existingIndex = instance().environment.tt.getState().actionIdIndex;
      handler = instance().handleIcrc85Action;
    });
    
    instance;
  };
```

And then in your main class body you need the ICRC85 action handler:

```
////////// ICRC85 OVS cycle sharing pattern /////////

  public func handleIcrc85Action<system>(id: TT.ActionId, action: TT.Action) : async* Star.Star<TT.ActionId, TT.Error> {
      switch (action.actionType) {
        case (ICRC85_Timer_Namespace) {
          await* ovsfixed.standardShareCycles({
            icrc_85_state = state.icrc85;
            icrc_85_environment = do?{environment.advanced!.icrc85!};
            setActionSync = environment.tt.setActionSync;
            timerNamespace = ICRC85_Timer_Namespace;
            paymentNamespace = ICRC85_Payment_Namespace;
            baseCycles = 200_000_000_000; // .2 XDR
            maxCycles = 1_000_000_000_000; // 1 XDR
            actionDivisor = 10000;
            actionMultiplier = 200_000_000_000; // .2 XDR
          });
          #awaited(id);
        };
        case (_) #trappable(id);
      };
    };

```

### Debugging

Debugging can be enabled by setting the appropriate flags in the `debug_channel` object:

- `announce`: Enables debug announcements.
- `cycles`: Enables cycle-sharing debug logs.

### Default Behavior

The default behavior is to share cycles to the OVS Ledger at q26le-iqaaa-aaaam-actsa-cai with the namespace specified. Ensure that you have claimed or can claim the namespace in the future before sharing cycles.

Currently the module cannot share more than 1,000 T cycles per period.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

This library was built by [ICDevs](https://ICDevs.org). If you use this library and gain value from it, please consider a [donation](https://icdevs.org/donations.html) to ICDevs.