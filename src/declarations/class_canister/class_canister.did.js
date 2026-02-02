export const idlFactory = ({ IDL }) => {
  const Time = IDL.Nat;
  const ActionId = IDL.Record({ 'id' : IDL.Nat, 'time' : Time });
  const Action = IDL.Record({
    'aSync' : IDL.Opt(IDL.Nat),
    'actionType' : IDL.Text,
    'params' : IDL.Vec(IDL.Nat8),
    'retries' : IDL.Nat,
  });
  const ActionDetail = IDL.Tuple(ActionId, Action);
  const TimerId = IDL.Nat;
  const Stats = IDL.Record({
    'timers' : IDL.Nat,
    'maxExecutions' : IDL.Nat,
    'minAction' : IDL.Opt(ActionDetail),
    'cycles' : IDL.Nat,
    'nextActionId' : IDL.Nat,
    'nextTimer' : IDL.Opt(TimerId),
    'expectedExecutionTime' : IDL.Opt(Time),
    'lastExecutionTime' : Time,
  });
  const OVSStats = IDL.Record({
    'activeActions' : IDL.Nat,
    'nextCycleActionId' : IDL.Opt(IDL.Nat),
    'lastActionReported' : IDL.Opt(IDL.Nat),
    'timerToolStats' : IDL.Opt(Stats),
  });
  const ClassCanister = IDL.Service({
    'getStats' : IDL.Func([], [OVSStats], ['query']),
    'manualInit' : IDL.Func([], [], []),
    'setCollector' : IDL.Func([IDL.Principal], [], []),
    'triggerInfo' : IDL.Func([], [], []),
  });
  return ClassCanister;
};
export const init = ({ IDL }) => { return []; };
