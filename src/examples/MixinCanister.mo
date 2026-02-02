import OVSMixin "../OVSMixin";
import OVS "../lib";
import TTMixin "mo:timer-tool/TimerToolMixin";
import TT "mo:timer-tool";
import Principal "mo:core/Principal";
import Debug "mo:core/Debug";
import ClassPlus "mo:class-plus";
import D "mo:core/Debug";

shared ({ caller = _owner }) persistent actor class MixinCanister(collectorCanister: Principal) = this {

  transient let canisterId = Principal.fromActor(this);
  transient let org_icdevs_class_plus_manager = ClassPlus.ClassPlusInitializationManager<system>(_owner, canisterId, true);


  include TTMixin({
    config = {
      org_icdevs_class_plus_manager = org_icdevs_class_plus_manager;
      args = null;
      pullEnvironment = ?(func() : TT.Environment {
        D.print("pulling environment");
        {      
          advanced = null;
          reportExecution = ?reportExecution;
          reportError = ?reportError;
          syncUnsafe = null;
          reportBatch = null;
        };
      });
      onInitialize = ?(func(a_tt: TT.TimerTool) : async*(){
        D.print("Hit initialization");
      });
    };
    caller = _owner;
    canisterId = canisterId;
  });

  // Configuration
  let ovsConfig : OVS.InitArgs = {
      namespace = "org.icdevs.ovs.test";
      publicNamespace = "ovs:test:mixin";
      baseCycles = 1_000_000_000;
      actionDivisor = 1;
      actionMultiplier = 1_000_000;
      maxCycles = 100_000_000_000;
      initialWait = ?0; // Start immediately for tests
      period = ?5_000_000_000; // 5 seconds
      asset = null;
      platform = null;
      resetAtEndOfPeriod = true;
  };
  

  // Environment function
  func getEnvironment() : OVS.Environment {
     {
        var org_icdevs_timer_tool = ?org_icdevs_timer_tool;
        var collector = ?collectorCanister;
        advanced = null;
     }
  };


  // Mixin state and instantiation
  var ovs_state = OVS.initialState();


  include OVSMixin({
     config = {
      args = ?ovsConfig;
      pullEnvironment = ?getEnvironment;
      org_icdevs_class_plus_manager = org_icdevs_class_plus_manager;
      onInitialize = null
     };
     caller =  _owner;
     canisterId = canisterId;
  });

  

  public shared func triggerInfo() : async () {
      org_icdevs_ovs_fixed.trackAction();
  };
  
  Debug.print("Mixin Canister Initialized");


  public shared query func getStats() : async OVS.OVSStats {
      org_icdevs_ovs_fixed.getStats();
  };

  private func reportExecution(execInfo: TT.ExecutionReport): Bool{
      return false;
  };

  private func reportError(errInfo: TT.ErrorReport) : ?Nat{
    D.print("in report error" # debug_show(errInfo));
    return null;
  };

};
