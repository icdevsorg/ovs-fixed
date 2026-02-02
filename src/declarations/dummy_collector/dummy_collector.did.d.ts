import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface DummyCollector {
  'getStats' : ActorMethod<
    [],
    {
      'logs' : Array<ShareNotification>,
      'count' : bigint,
      'total_cycles' : bigint,
    }
  >,
  'icrc85_deposit_cycles_notify' : ActorMethod<[ShareArgs], undefined>,
}
export type ShareArgs = Array<[string, bigint]>;
export interface ShareNotification {
  'actions' : bigint,
  'timestamp' : bigint,
  'caller' : Principal,
  'cycles_received' : bigint,
  'namespace' : string,
}
export interface _SERVICE extends DummyCollector {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
