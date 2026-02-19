import Array "mo:core/Array";
import List "mo:core/List";
import Cycles "mo:core/Cycles";
import Error "mo:core/Error";
import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Runtime "mo:core/Runtime";
import Blob "mo:core/Blob";
import Time "mo:core/Time";
import Timer "mo:core/Timer";
import Star "mo:star/star";
import TT "mo:timer-tool";
import ClassPlusLib "mo:class-plus";

module {

    let debug_channel = {
      announce = true;
      cycles = true;

    };

    public let OneDay = 86_400_000_000_000;
    public let OneXDR = 1_000_000_000_000;  // ~1 XDR in cycles
    let MAX_CYCLES = 1_000_000_000_000_000;

    let COLLECTOR = "q26le-iqaaa-aaaam-actsa-cai";

    public type Map = [(Text, Value)];

    /// State type for ClassPlus
    public type State = {
      var nextCycleActionId: ?Nat;
      var lastActionReported: ?Nat;
      var activeActions: Nat;
      var resetAtEndOfPeriod : Bool;
    };

    // Alias for backward compatibility or direct use
    public type OVSState = State;

    /// Convenience alias
    public type ICRC85State = {
      var nextCycleActionId: ?Nat;
      var lastActionReported: ?Nat;
      var activeActions: Nat;
    };

    /// Statistics returned by getStats()
    public type OVSStats = {
      activeActions: Nat;
      lastActionReported: ?Nat;
      nextCycleActionId: ?Nat;
      timerToolStats: ?TT.Stats;
    };

    public type Value = {
      #Int : Int;
      #Map : Map;
      #Nat : Nat;
      #Blob : Blob;
      #Text : Text;
      #Array : [Value];
    };

    /// Advanced environment options (all optional)
    public type AdvancedEnvironment = {
      kill_switch: ?Bool;
      handler: ?(([(Text, Map)]) -> ());
      tree: ?[Text];
    };

    /// Environment type for ClassPlus
    public type Environment = {
      var org_icdevs_timer_tool: ?TT.TimerTool;                     // TimerTool instance (required)
      var collector: ?Principal;             // Custom collector (default: ICRC-85)
      advanced: ?AdvancedEnvironment;        // Optional advanced settings
    };


    /// InitArgs type for ClassPlus
    public type InitArgs = {
      namespace: Text;              // e.g., "org.icdevs.icrc85.icrc1"
      publicNamespace: Text;        // e.g., "icrc85:ovs:shareaction:icrc1" for timer actions
      baseCycles: Nat;              // Base cycles per period (e.g., 1 XDR = 1_000_000_000_000)
      actionDivisor: Nat;           // Actions per bonus (e.g., 10000 = 1 XDR per 10K actions)
      actionMultiplier: Nat;        // Cycles per bonus unit (e.g., 1 XDR = 1_000_000_000_000)
      maxCycles: Nat;               // Maximum cycles per period (e.g., 100 XDR)
      initialWait: ?Nat;            // Initial wait before first share (default: 7 days grace period)
      period: ?Nat;                 // Period between shares (default: 30 days)
      asset: ?Text;                 // default cycles
      platform: ?Text;              // defult icp
      resetAtEndOfPeriod: Bool;     // do active actions reset at end of period?
    };

    // Alias
    public type OVSConfig = InitArgs;

    /// Create initial OVS state - call this once and store in stable memory
    public func initialState() : State {
      {
        var nextCycleActionId = null;
        var lastActionReported = null;
        var activeActions = 0;
        var resetAtEndOfPeriod = true;
      };
    };

    public type InitFunctionArgs = {
        org_icdevs_class_plus_manager : ClassPlusLib.ClassPlusInitializationManager;
        initialState : State;
        args : ?InitArgs;
        pullEnvironment : ?(() -> Environment);
        onInitialize : ?((OVS) -> async* ());
        onStorageChange : (State) -> ();
    };

    public type MixinFunctionArgs = {
      org_icdevs_class_plus_manager : ClassPlusLib.ClassPlusInitializationManager;
      args : ?InitArgs;
      pullEnvironment : ?(() -> Environment);
      onInitialize : ?((OVS) -> async* ());
    };

    /// ClassPlus Initialization wrapper
    public func Init(config : InitFunctionArgs) : () -> OVS {



        //Debug.print("Subscriber Init");
        switch(config.pullEnvironment){
          case(?_val) { };
          case(null) {
            debug if(debug_channel.announce) Debug.print("pull environment is null");
            Runtime.trap("environment required");
          };
        };  
    
        // Wrap onInitialize to ensure ICRC-85 timer is started
        let wrappedOnInitialize = func (instance: OVS) : async* () {
            debug if(debug_channel.announce) Debug.print("Auto-initializing ICRC-85 timer for OVS");
            // We can call this because we are in an async* context with system capability from ClassPlus
            await* instance.initialize<system>();
            
            switch(config.onInitialize){
                case(?cb) await* cb(instance);
                case(null) {};
            };
        };
         ClassPlusLib.ClassPlus<
          OVS, 
          State,
          InitArgs,
          Environment>({config with 
            constructor = OVS;
            onInitialize = ?wrappedOnInitialize
          }).get;
    };

    /// The OVS class manages automatic cycle sharing
    public class OVS(
      stored: ?State, 
      _caller: Principal, 
      _canister: Principal, 
      args: ?InitArgs, 
      environment_passed: ?Environment,
      storageChange: (State) -> ()
    ) {      
      //var _environment = environment;
      public let state : State = switch(stored){
        case(null) initialState();
        case(?val) val;
      };

      public var environment : Environment = switch(environment_passed){
        case(null) Runtime.trap("EnvironmentRequired");
        case(?e) e;
      };

      // Ensure storage is linked
      storageChange(state);

      

      let config = switch(args) {
        case(null) Runtime.trap("OVS: InitArgs required");
        case(?val) val;
      };

      switch(environment.org_icdevs_timer_tool){
        case(null) Runtime.trap("TimerTool required on environment");
        case(?_tt){}; //initialize later
      };

      state.resetAtEndOfPeriod := config.resetAtEndOfPeriod;

      var initialized = false;

 

      /// Initialize the OVS system - sets up timers
      /// Call this once during canister initialization
      public func initialize<system>() : async* () {
        if (initialized) return;
        initialized := true;

        let timerTool = ensureTT<system>();
        
        // Register our action handler
        timerTool.registerExecutionListenerAsync(?config.publicNamespace, handleOVSAction);

        // Schedule first cycle share after grace period
        let waitTime = switch(config.initialWait) {
          case(?val) val;
          case(null) 7 * OneDay; // Default 7 day grace period
        };
        
        // Using TT is better for upgrades.
        
        // Check if we already have a scheduled action
        switch(state.nextCycleActionId) {
            case(null) {
               let result = timerTool.setActionSync<system>(
                  Int.abs(Time.now()) + waitTime,
                  { actionType = config.publicNamespace; params = Blob.fromArray([]) }
               );
               state.nextCycleActionId := ?result.id;
            };
            case(_){};
        };

        debug if (debug_channel.announce) Debug.print("OVS initialized for " # config.namespace);
      };

      /// Track an action (transfer, mint, burn, etc.)
      /// Call this whenever a billable action occurs
      public func trackAction() : () {
        state.activeActions := state.activeActions + 1;
      };

      /// Get current OVS statistics
      public func getStats() : OVSStats {
        {
          activeActions = state.activeActions;
          lastActionReported = state.lastActionReported;
          nextCycleActionId = state.nextCycleActionId;
          timerToolStats = switch(environment.org_icdevs_timer_tool) {
            case(?tt) ?tt.getStats();
            case(null) null;
          };
        };
      };

      /// Calculate cycles to share based on current actions
      public func calculateCyclesToShare() : (cycles: Nat, actions: Nat) {
        let actions = if (state.activeActions > 0) state.activeActions else 1;
        
        var cyclesToShare = config.baseCycles;
        
        if (actions > 0 and config.actionDivisor > 0) {
          let additional = Nat.div(actions, config.actionDivisor);
          cyclesToShare := cyclesToShare + (additional * config.actionMultiplier);
          if (cyclesToShare > config.maxCycles) {
            cyclesToShare := config.maxCycles;
          };
        };

        (cyclesToShare, actions);
      };

      // Private: Ensure timer tool is initialized
      private func ensureTT<system>() : TT.TimerTool {
        switch(environment.org_icdevs_timer_tool) {
          case(?val) val;
          case(null) {
            //unreachable
            Runtime.trap("Unreachable - no timer tool set in environment");
          };
        };
      };


      // Private: Handle the OVS action from timer-tool
      private func handleOVSAction<system>(id: TT.ActionId, action: TT.Action) : async* Star.Star<TT.ActionId, TT.Error> {
        debug if (debug_channel.announce) Debug.print("OVS action triggered: " # debug_show(action.actionType));
        
        if (action.actionType == config.publicNamespace) {
          await* doShareCycles<system>();
          #awaited(id);
        } else {
          #trappable(id);
        };
      };

      // Private: Actually share the cycles
      private func doShareCycles<system>() : async* () {
        debug if (debug_channel.cycles) Debug.print("OVS: Starting cycle share");

        let (cyclesToShare, actions) = calculateCyclesToShare();
        
        debug if (debug_channel.cycles) Debug.print("OVS: Actions=" # Nat.toText(actions) # ", Cycles=" # Nat.toText(cyclesToShare));

        // Reset counter
        if(state.resetAtEndOfPeriod){
          state.activeActions := 0;
        };

        let _period = switch(config.period) {
          case(?val) val;
          case(null) 30 * OneDay;
        };

        try {
          await* shareCycles<system>({
            environment = environment;
            namespace = config.namespace;
            actions = actions;
            schedule = func<system>(schedulePeriod: Nat) : async* () {
              let timerTool = ensureTT<system>();
              let result = timerTool.setActionSync<system>(
                Int.abs(Time.now()) + schedulePeriod,
                { actionType = config.publicNamespace; params = Blob.fromArray([]) }
              );
              state.nextCycleActionId := ?result.id;
            };
            cycles = cyclesToShare;
            period = config.period;
            asset = config.asset;
            platform = config.platform;
          });
          state.lastActionReported := ?Int.abs(Time.now());
        } catch (e) {
          // Restore actions on error
          state.activeActions := actions;
          debug if (debug_channel.cycles) Debug.print("OVS error: " # Error.message(e));
        };
      };
    };

    public type ActionId = {
      time: Nat;
      id: Nat;
    };

    public type Action = {
      actionType: Text;
      params: Blob;
      aSync: ?Nat;
      retries: Nat;
    };

    public type Error = {
      error_code : Nat;
      message : Text;
    };

    public func shareCycles<system>(request: {
        environment: Environment;
        cycles: Nat;
        actions: Nat;
        namespace: Text;
        schedule: <system>(Nat) -> async* ();
        period: ?Nat;
        asset: ?Text;
        platform: ?Text;
      }) : async* (){
      debug if (debug_channel.announce) Debug.print("sharing cycles");

      let period : Nat = switch(request.period){
        case(?val) val;
        case(null) (OneDay * 30);
      };

      let local_collector : Text = switch(do?{request.environment.collector!}){
        case(?val) Principal.toText(val);
        case(null) COLLECTOR;
      };

      let asset : Text = switch(request.asset){
        case(?val) val;
        case(null) "cycles";
      };

      let platform : Text = switch(request.platform){
        case(?val) val;
        case(null) "icp";
      };

      let tree : ?Value = switch(do?{request.environment.advanced!.tree!}){
        case(?val){
          ?#Array(Array.map<Text, Value>(val, func(x: Text) : Value {#Text(x)}));
        };
        case(null) null;
      };

      await* request.schedule<system>(period);

      switch(do?{request.environment.advanced!.kill_switch!}){
        case(?val){
          if(val == true) return;
        };
        case(_){};
      };

      switch(do?{request.environment.advanced!.handler!}){
        case(?val){
          let map = List.empty<(Text,Value)>();
          List.add(map, ("report_period", #Nat(period)));
          switch(tree){
            case(?treeVal) List.add(map, ("tree", treeVal));
            case(null) {};
          };
          List.add(map, ("principal", #Text(local_collector)));
          List.add(map, ("asset", #Text(asset)));
          List.add(map, ("platform", #Text(platform)));
          List.add(map, ("units", #Nat(request.actions)));

          val([("icrc85:ovs:shareaction", List.toArray(map))]);
        };
        case(null){

          debug if (debug_channel.cycles) Debug.print("about to share cycles");

          let shareCyclesService : actor{
            icrc85_deposit_cycles_notify : ([(Text,Nat)]) -> ();
          } = actor(local_collector);

          let currentBalance = Cycles.balance();
          var cyclesToShare = request.cycles;

          debug if (debug_channel.cycles) Debug.print("cycle balance" # debug_show(currentBalance));

          //make sure we don't drain someone's cycles
          if(cyclesToShare * 2 > currentBalance ) cyclesToShare := currentBalance / 2;

          if(cyclesToShare > MAX_CYCLES) cyclesToShare := MAX_CYCLES;

          try{
          
            
            (with cycles = cyclesToShare) shareCyclesService.icrc85_deposit_cycles_notify([(request.namespace, request.actions)]);

            debug if (debug_channel.cycles) Debug.print("cycle shared");
            
          } catch(e){
            debug if (debug_channel.cycles) Debug.print("error sharing cycles" # Error.message(e));
          };
        };
      };
    };
};