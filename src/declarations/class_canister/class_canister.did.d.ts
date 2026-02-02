import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface Action {
  'aSync' : [] | [bigint],
  'actionType' : string,
  'params' : Uint8Array | number[],
  'retries' : bigint,
}
export type ActionDetail = [ActionId, Action];
export interface ActionId { 'id' : bigint, 'time' : Time }
export interface ClassCanister {
  'getStats' : ActorMethod<[], OVSStats>,
  'manualInit' : ActorMethod<[], undefined>,
  'setCollector' : ActorMethod<[Principal], undefined>,
  'triggerInfo' : ActorMethod<[], undefined>,
}
export interface OVSStats {
  'activeActions' : bigint,
  'nextCycleActionId' : [] | [bigint],
  'lastActionReported' : [] | [bigint],
  'timerToolStats' : [] | [Stats],
}
export interface Stats {
  'timers' : bigint,
  'maxExecutions' : bigint,
  'minAction' : [] | [ActionDetail],
  'cycles' : bigint,
  'nextActionId' : bigint,
  'nextTimer' : [] | [TimerId],
  'expectedExecutionTime' : [] | [Time],
  'lastExecutionTime' : Time,
}
export type Time = bigint;
export type TimerId = bigint;
export interface _SERVICE extends ClassCanister {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
