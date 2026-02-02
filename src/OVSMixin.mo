/////////
// OVS Mixin - Automatic Open Value Sharing Integration
//
// This mixin provides seamless OVS (ICRC-85) integration for actors.
// It wraps the OVS ClassPlus implementation.
//
// Usage:
// ```motoko
// import OVSMixin "mo:ovs-fixed/OVSMixin";
// 
// actor Token {
//
//   // Define your OVS configuration
//   let ovsConfig : OVS.InitArgs = { ... };
//
//   include OVSMixin<system>(
//      ovsConfig,
//      ovsEnvironment, // or null
//      Principal.fromActor(this),
//      Principal.fromActor(this)
//   );
//
//   public shared func transfer(...) : async ... {
//     ovs.trackAction();  // Track the action
//   };
// };
// ```
/////////

import OVS "lib";
import Principal "mo:core/Principal";
import ClassPlus "mo:class-plus";

mixin(args: {
    config: OVS.MixinFunctionArgs;
    caller: Principal;
    canisterId: Principal;
}){

  /// OVS Mixin - include this in your actor for automatic cycle sharing

   var org_icdevs_ovs_fixed_state = OVS.initialState();

   transient var org_icdevs_ovs_fixed = OVS.Init({
    initialState = org_icdevs_ovs_fixed_state;
    args = args.config.args;
  
    org_icdevs_class_plus_manager = args.config.org_icdevs_class_plus_manager;
    onInitialize = args.config.onInitialize;
    pullEnvironment = args.config.pullEnvironment;
    onStorageChange = func(state : OVS.State){
      org_icdevs_ovs_fixed_state := state;
    };
  })();


};
