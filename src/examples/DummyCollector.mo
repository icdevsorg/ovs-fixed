// Dummy Collector for tests
import Cycles "mo:core/Cycles";
import Array "mo:core/Array";
import D "mo:core/Debug";
import Principal "mo:core/Principal";
import Time "mo:core/Time";

shared persistent actor class DummyCollector() = this {

  public type ShareNotification = {
    namespace: Text;
    actions: Nat;
    cycles_received: Nat;
    timestamp: Int;
    caller: Principal;
  };

  public type ShareArgs = [(Text, Nat)];

  var notifications : [ShareNotification] = [];
  var total_cycles_received : Nat = 0;
  var total_notifications : Nat = 0;

  // Standard endpoint
  public shared ({ caller }) func icrc85_deposit_cycles_notify(request: ShareArgs) : async () {
    let amount = Cycles.available();
    let accepted = Cycles.accept<system>(amount);
    
    let newNotifications = Array.map<(Text, Nat), ShareNotification>(request, func((namespace, actions)) {
      {
        namespace = namespace;
        actions = actions;
        cycles_received = accepted;
        timestamp = Time.now();
        caller = caller;
      }
    });
    
    notifications := append(notifications, newNotifications);
    total_cycles_received += accepted;
    total_notifications += 1;
    
    D.print("Accepted cycles: " # debug_show(accepted));
  };

  private func append<A>(xs : [A], ys : [A]) : [A] {
      let size = xs.size() + ys.size();
      Array.tabulate<A>(size, func(i) {
        if (i < xs.size()) xs[i] else ys[i - xs.size()]
      })
  };
  
  public query func getStats() : async { total_cycles: Nat; count: Nat; logs: [ShareNotification] } {
    {
        total_cycles = total_cycles_received;
        count = total_notifications;
        logs = notifications;
    };
  };
};
