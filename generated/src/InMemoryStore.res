
@genType
type rawEventsKey = {
  chainId: int,
  eventId: string,
}

let hashRawEventsKey = (key: rawEventsKey) =>
  EventUtils.getEventIdKeyString(~chainId=key.chainId, ~eventId=key.eventId)

@genType
type dynamicContractRegistryKey = {
  chainId: int,
  contractAddress: Ethers.ethAddress,
}

let hashDynamicContractRegistryKey = ({chainId, contractAddress}) =>
  EventUtils.getContractAddressKeyString(~chainId, ~contractAddress)

type t = {
  eventSyncState: InMemoryTable.t<int, TablesStatic.EventSyncState.t>,
  rawEvents: InMemoryTable.t<rawEventsKey, TablesStatic.RawEvents.t>,
  dynamicContractRegistry: InMemoryTable.t<
    dynamicContractRegistryKey,
    TablesStatic.DynamicContractRegistry.t,
  >,
  @as("Benchmark") 
  benchmark: InMemoryTable.Entity.t<Entities.Benchmark.t>,
  @as("Chat") 
  chat: InMemoryTable.Entity.t<Entities.Chat.t>,
  @as("Game") 
  game: InMemoryTable.Entity.t<Entities.Game.t>,
  @as("LlmResponse") 
  llmResponse: InMemoryTable.Entity.t<Entities.LlmResponse.t>,
  @as("Message") 
  message: InMemoryTable.Entity.t<Entities.Message.t>,
  @as("Stake") 
  stake: InMemoryTable.Entity.t<Entities.Stake.t>,
  @as("WinningClaim") 
  winningClaim: InMemoryTable.Entity.t<Entities.WinningClaim.t>,
  rollBackEventIdentifier: option<Types.eventIdentifier>,
}

let makeWithRollBackEventIdentifier = (rollBackEventIdentifier): t => {
  eventSyncState: InMemoryTable.make(~hash=v => v->Belt.Int.toString),
  rawEvents: InMemoryTable.make(~hash=hashRawEventsKey),
  dynamicContractRegistry: InMemoryTable.make(~hash=hashDynamicContractRegistryKey),
  benchmark: InMemoryTable.Entity.make(),
  chat: InMemoryTable.Entity.make(),
  game: InMemoryTable.Entity.make(),
  llmResponse: InMemoryTable.Entity.make(),
  message: InMemoryTable.Entity.make(),
  stake: InMemoryTable.Entity.make(),
  winningClaim: InMemoryTable.Entity.make(),
  rollBackEventIdentifier,
}

let make = () => makeWithRollBackEventIdentifier(None)

let clone = (self: t) => {
  eventSyncState: self.eventSyncState->InMemoryTable.clone,
  rawEvents: self.rawEvents->InMemoryTable.clone,
  dynamicContractRegistry: self.dynamicContractRegistry->InMemoryTable.clone,
  benchmark: self.benchmark->InMemoryTable.Entity.clone,
  chat: self.chat->InMemoryTable.Entity.clone,
  game: self.game->InMemoryTable.Entity.clone,
  llmResponse: self.llmResponse->InMemoryTable.Entity.clone,
  message: self.message->InMemoryTable.Entity.clone,
  stake: self.stake->InMemoryTable.Entity.clone,
  winningClaim: self.winningClaim->InMemoryTable.Entity.clone,
  rollBackEventIdentifier: self.rollBackEventIdentifier->InMemoryTable.structuredClone,
}


let getInMemTable = (
  type entity,
  inMemoryStore: t,
  ~entityMod: module(Entities.Entity with type t = entity),
): InMemoryTable.Entity.t<entity> => {
  let module(Entity) = entityMod->Entities.entityModToInternal
  inMemoryStore->Utils.magic->Js.Dict.unsafeGet(Entity.key)
}
