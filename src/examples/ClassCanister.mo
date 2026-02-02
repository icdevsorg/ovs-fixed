import OVS "../lib";
import ClassPlus "mo:class-plus";
import Principal "mo:core/Principal";
import Timer "mo:core/Timer";
import TTMixin "mo:timer-tool/TimerToolMixin";
import TT "mo:timer-tool";
import D "mo:core/Debug";

shared ({ caller = _owner }) persistent actor class ClassCanister(collector : ?Principal) = this {

  var ovs_state = OVS.initialState();
  var collectorCanister = collector;
  
  transient let org_icdevs_class_plus_manager = ClassPlus.ClassPlusInitializationManager<system>(_owner, Principal.fromActor(this), true);

  transient let canisterId = Principal.fromActor(this);

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
      namespace = "org.icdevs.ovs.test.class";
      publicNamespace = "ovs:test:class";
      baseCycles = 1_000_000_000;
      actionDivisor = 1;
      actionMultiplier = 1_000_000;
      maxCycles = 100_000_000_000;
      initialWait = ?0; 
      period = ?5_000_000_000; // 5 seconds
      asset = null;
      platform = null;
      resetAtEndOfPeriod = true;
  };

  func getEnv() : OVS.Environment {
     {
        var org_icdevs_timer_tool = ?org_icdevs_timer_tool;
        var collector = collectorCanister;
        advanced = null;
     }
  };

  transient var ovs = OVS.Init({
      org_icdevs_class_plus_manager = org_icdevs_class_plus_manager;
      args = ?ovsConfig;
      pullEnvironment = ?getEnv;
      onInitialize = null;
      initialState = ovs_state;
      onStorageChange = func(_state : OVS.State){
        ovs_state := _state;
      };
  })();

  public shared func manualInit() : async () {
      await* ovs.initialize<system>();
  };

  public shared func setCollector(p: ?Principal) : async () {
    collectorCanister := p;
    ovs.environment.collector := p;
  };

  public shared func triggerInfo() : async () {
      ovs.trackAction();
  };
  
  public shared query func getStats() : async OVS.OVSStats {
      ovs.getStats();
  };

    private func reportExecution(execInfo: TT.ExecutionReport): Bool{
      return false;
  };

  private func reportError(errInfo: TT.ErrorReport) : ?Nat{
    D.print("in report error" # debug_show(errInfo));
    return null;
  };
};
