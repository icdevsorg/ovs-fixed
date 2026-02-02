export const idlFactory = ({ IDL }) => {
  const ShareNotification = IDL.Record({
    'actions' : IDL.Nat,
    'timestamp' : IDL.Int,
    'caller' : IDL.Principal,
    'cycles_received' : IDL.Nat,
    'namespace' : IDL.Text,
  });
  const ShareArgs = IDL.Vec(IDL.Tuple(IDL.Text, IDL.Nat));
  const DummyCollector = IDL.Service({
    'getStats' : IDL.Func(
        [],
        [
          IDL.Record({
            'logs' : IDL.Vec(ShareNotification),
            'count' : IDL.Nat,
            'total_cycles' : IDL.Nat,
          }),
        ],
        ['query'],
      ),
    'icrc85_deposit_cycles_notify' : IDL.Func([ShareArgs], [], []),
  });
  return DummyCollector;
};
export const init = ({ IDL }) => { return []; };
