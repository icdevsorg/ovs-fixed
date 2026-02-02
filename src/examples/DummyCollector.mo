// Dummy Collector for tests
import Cycles "mo:core/Cycles";
import Array "mo:base/Array";
import D "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";

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
    
    notifications := Array.append(notifications, newNotifications);
    total_cycles_received += accepted;
    total_notifications += 1;
    
    D.print("Accepted cycles: " # debug_show(accepted));
  };
  
  public query func getStats() : async { total_cycles: Nat; count: Nat; logs: [ShareNotification] } {
    {
        total_cycles = total_cycles_received;
        count = total_notifications;
        logs = notifications;
    };
  };
};
