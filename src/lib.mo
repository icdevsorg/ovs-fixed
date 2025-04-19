import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import D "mo:base/Debug";
import Principal "mo:base/Principal";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Time "mo:base/Time";
import Timer "mo:base/Timer";
import TimerTool "mo:timer-tool";
import Map "mo:map/Map";
import Star "mo:star/star";


module {

    let debug_channel = {
      announce = false;
      cycles = false;
    };

    let OneMinute = 60_000_000_000;
    let OneDay =  86_400_000_000_000;
    let MAX_CYCLES = 1_000_000_000_000_000;

    let COLLECTOR = "q26le-iqaaa-aaaam-actsa-cai";

    public type Map = [(Text, Value)];

    public type ICRC85State = {
      var nextCycleActionId: ?Nat;
      var lastActionReported: ?Nat;
      var activeActions: Nat;
    };

    public type Value = {
      #Int : Int;
      #Map : Map;
      #Nat : Nat;
      #Blob : Blob;
      #Text : Text;
      #Array : [Value];
    };

    public type ICRC85Environment = ?{
      kill_switch: ?Bool;
      handler: ?(([(Text, Map)]) -> ());
      period: ?Nat;
      asset: ?Text;
      platform: ?Text;
      tree: ?[Text];
      collector: ?Principal;
    };

    private func getDelayedFunc<system>( args: {
          icrc_85_state: ICRC85State;
          tt: TimerTool.TimerTool;
          namespace: Text;
        }) : (() -> async()) {
        
        let afunc = func<system>() : async () {
            scheduleCycleShare<system>(
              args.icrc_85_state,
              args.tt,
              args.namespace
            )
          };
        return afunc;
    };

    public func initialize_cycleShare<system>({
      namespace: Text;
      icrc_85_state: ICRC85State;
      wait: ?Nat;
      tt: TimerTool.TimerTool;
      handler: TimerTool.ExecutionAsyncHandler
    }) : () {
      ignore Timer.setTimer<system>(#nanoseconds(switch(wait){
        case(?val) val;
        case(null) OneDay;
      }), getDelayedFunc<system>({
        icrc_85_state = icrc_85_state;
        tt = tt;
        namespace = namespace;
      }));
      tt.registerExecutionListenerAsync(?namespace, handler);
    };

    public func scheduleCycleShare<system>(icrc_85_state: ICRC85State, tt: TimerTool.TimerTool, namespace: Text) : () {
      switch (icrc_85_state.nextCycleActionId) {
        case (?val) {
          switch (Map.get(tt.getState().actionIdIndex, Map.nhash, val)) {
            case (?time) { return };
            case (null) {};
          };
        };
        case (null) {};
      };
      let result = tt.setActionSync<system>(Int.abs(Time.now()), ({
        actionType = namespace;
        params = Blob.fromArray([]);
      }));
      icrc_85_state.nextCycleActionId := ?result.id;
    };

    public func standardShareCycles<system>(args: {
      icrc_85_state: ICRC85State;
      icrc_85_environment: ICRC85Environment;
      tt: TimerTool.TimerTool;
      timerNamespace: Text;
      paymentNamespace: Text;
      baseCycles: Nat;
      actionDivisor: Nat;
      actionMultiplier: Nat;
      maxCycles: Nat;
    }) : async* () {
      let lastReportId = switch (args.icrc_85_state.lastActionReported) {
        case (?val) val; case (null) 0;
      };
      let actions = if (args.icrc_85_state.activeActions > 0) args.icrc_85_state.activeActions else 1;
      args.icrc_85_state.activeActions := 0;
      var cyclesToShare = args.baseCycles; // .2 XDR
      if (actions > 0) {
        let additional = Nat.div(actions, args.actionDivisor);
        cyclesToShare := cyclesToShare + (additional * args.actionMultiplier);
        if (cyclesToShare > args.maxCycles) cyclesToShare := args.maxCycles;
      };
      try {
        await* shareCycles<system>({
          environment = args.icrc_85_environment;
          namespace = args.paymentNamespace;
          actions = actions;
          schedule = func <system>(period: Nat) : async* () {
            let result = args.tt.setActionSync<system>(Int.abs(Time.now()) + period, {
              actionType = args.timerNamespace;
              params = Blob.fromArray([]);
            });
            args.icrc_85_state.nextCycleActionId := ?result.id;
          };
          cycles = cyclesToShare;
        });
        args.icrc_85_state.lastActionReported := ?Int.abs(Time.now());
      } catch (e) {
        args.icrc_85_state.activeActions := actions;
        D.print("Error occurred during shareCycles: " # Error.message(e));
      };
    };

    public func shareCycles<system>(request: {
        environment: ICRC85Environment;
        cycles: Nat;
        actions: Nat;
        namespace: Text;
        schedule: <system>(Nat) -> async* ()
      }) : async* (){
      debug if (debug_channel.announce) D.print("sharing cycles");

      let period : Nat = switch(do?{request.environment!.period!}){
        case(?val) val;
        case(null) (OneDay * 30);
      };

      let local_collector : Text = switch(do?{request.environment!.collector!}){
        case(?val) Principal.toText(val);
        case(null) COLLECTOR;
      };

      let asset : Text = switch(do?{request.environment!.asset!}){
        case(?val) val;
        case(null) "cycles";
      };

      let platform : Text = switch(do?{request.environment!.platform!}){
        case(?val) val;
        case(null) "icp";
      };

      let tree : ?Value = switch(do?{request.environment!.tree!}){
        case(?val){
          ?#Array(Array.map<Text, Value>(val, func(x: Text) : Value {#Text(x)}));
        };
        case(null) null;
      };

      let result =  await* request.schedule<system>(period);

      switch(do?{request.environment!.kill_switch!}){
        case(?val){
          if(val == true) return;
        };
        case(_){};
      };

      switch(do?{request.environment!.handler!}){
        case(?val){
          let map = Buffer.Buffer<(Text,Value)>(1);
          map.add(("report_period", #Nat(period)));
          switch(tree){
            case(?val) map.add(("tree", val));
            case(null) {};
          };
          map.add(("principal", #Text(local_collector)));
          map.add(("asset", #Text(asset)));
          map.add(("platform", #Text(platform)));
          map.add(("units", #Nat(request.actions)));

          val([("icrc85:ovs:shareaction", Buffer.toArray(map))]);
        };
        case(null){

          debug if (debug_channel.cycles) D.print("about to share cycles");

          let shareCyclesService : actor{
            icrc85_deposit_cycles_notify : ([(Text,Nat)]) -> ();
          } = actor(local_collector);

          let currentBalance = Cycles.balance();
          var cyclesToShare = request.cycles;

          debug if (debug_channel.cycles) D.print("cycle balance" # debug_show(currentBalance));

          //make sure we don't drain someone's cycles
          if(cyclesToShare * 2 > currentBalance ) cyclesToShare := currentBalance / 2;

          if(cyclesToShare > MAX_CYCLES) cyclesToShare := MAX_CYCLES;

          try{
            Cycles.add<system>(cyclesToShare);
            let result = shareCyclesService.icrc85_deposit_cycles_notify([(request.namespace, request.actions)]);

            debug if (debug_channel.cycles) D.print("cycle shared" # debug_show(result));
            
          } catch(e){
            debug if (debug_channel.cycles) D.print("error sharing cycles" # Error.message(e));
          };
        };
      };
    };
};