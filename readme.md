# ICRC-85 Fixed Open Value Sharing Strategy

## Overview

This project implements an Open Value Sharing (OVS) strategy that facilitates the sharing of a specified number of cycles within the Internet Computer ecosystem. The core functionality is defined in a single module that handles the sharing process based on various configurable parameters.

## Key Features

- **Cycle Sharing:** Efficiently shares cycles with a specified collector.
- **Configurable Environment:** Allows customization through the `ICRC85Environment` type, including options for a kill switch, handler, period, asset, platform, and tree.
- **Debugging Support:** Provides debug channels for announcements and cycle-sharing events.

## Dependencies

The module depends on several base libraries:

- `Array`
- `Buffer`
- `Cycles`
- `Error`
- `Debug`
- `Principal`

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

### Sharing Cycles

The `shareCycles` function initiates the cycle-sharing process based on the provided request. The request includes the environment configuration, the number of cycles to share, the number of actions, the reporting period, a namespace, and a scheduling function.

#### Example Usage

```motoko
import Principal "mo:base/Principal";

let environment : ICRC85Environment = ?{
  kill_switch = null;
  handler = null;
  period = ?(86_400_000_000_000); // 1 day
  asset = ;
  platform = ;
  tree = null;
  collector = ?Principal.fromText("q26le-iqaaa-aaaam-actsa-cai");
};

await shareCycles({
  environment = environment;
  cycles = 1_000_000_000;
  actions = 100;
  report_period = 86_400_000_000_000;
  namespace = "example";
  schedule = func (interval: Nat) : async* () {
    // Custom scheduling logic
  };
});
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

This library was incentivized by [ICDevs](https://ICDevs.org). If you use this library and gain value from it, please consider a [donation](https://icdevs.org/donations.html) to ICDevs.