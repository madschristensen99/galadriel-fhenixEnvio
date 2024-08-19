open Types

/**
The context holds all the state for a given events loader and handler.
*/
type t<'eventArgs> = {
  logger: Pino.t,
  chain: ChainMap.Chain.t,
  addedDynamicContractRegistrations: array<TablesStatic.DynamicContractRegistry.t>,
  event: Types.eventLog<'eventArgs>,
}

let getUserLogger = (logger): Logs.userLogger => {
  info: (message: string) => logger->Logging.uinfo(message),
  debug: (message: string) => logger->Logging.udebug(message),
  warn: (message: string) => logger->Logging.uwarn(message),
  error: (message: string) => logger->Logging.uerror(message),
  errorWithExn: (exn: option<Js.Exn.t>, message: string) =>
    logger->Logging.uerrorWithExn(exn, message),
}

let makeEventIdentifier = (event: Types.eventLog<'a>): Types.eventIdentifier => {
  chainId: event.chainId,
  blockTimestamp: event.block.timestamp,
  blockNumber: event.block.number,
  logIndex: event.logIndex,
}

let getEventId = (event: Types.eventLog<'a>) => {
  EventUtils.packEventIndex(~blockNumber=event.block.number, ~logIndex=event.logIndex)
}

let make = (~chain, ~event: Types.eventLog<'eventArgs>, ~eventMod: module(Types.InternalEvent), ~logger) => {
  let {block, logIndex} = event
  let module(Event) = eventMod
  let logger = logger->(
    Logging.createChildFrom(
      ~logger=_,
      ~params={
        "context": `Event '${Event.name}' for contract '${Event.contractName}'`,
        "chainId": chain->ChainMap.Chain.toChainId,
        "block": block.number,
        "logIndex": logIndex,
      },
    )
  )

  {
    event,
    logger,
    chain,
    addedDynamicContractRegistrations: [],
  }
}

let getAddedDynamicContractRegistrations = (contextEnv: t<'eventArgs>) =>
  contextEnv.addedDynamicContractRegistrations

let makeDynamicContractRegisterFn = (~contextEnv: t<'eventArgs>, ~contractName, ~inMemoryStore) => (
  contractAddress: Ethers.ethAddress,
) => {
  let {event, chain, addedDynamicContractRegistrations} = contextEnv

  let eventId = event->getEventId
  let chainId = chain->ChainMap.Chain.toChainId
  let dynamicContractRegistration: TablesStatic.DynamicContractRegistry.t = {
    chainId,
    eventId,
    blockTimestamp: event.block.timestamp,
    contractAddress,
    contractType: contractName,
  }

  addedDynamicContractRegistrations->Js.Array2.push(dynamicContractRegistration)->ignore

  inMemoryStore.InMemoryStore.dynamicContractRegistry->InMemoryTable.set(
    {chainId, contractAddress},
    dynamicContractRegistration,
  )
}

let makeWhereLoader = (loadLayer, ~entityMod, ~inMemoryStore, ~fieldName, ~fieldValueSchema, ~logger) => {
  Entities.eq: loadLayer->LoadLayer.makeWhereEqLoader(~entityMod, ~fieldName, ~fieldValueSchema, ~inMemoryStore, ~logger)
}

let makeEntityHandlerContext = (
  type entity,
  ~eventIdentifier,
  ~inMemoryStore,
  ~entityMod: module(Entities.Entity with type t = entity),
  ~logger,
  ~getKey,
  ~loadLayer,
): entityHandlerContext<entity> => {
  let inMemTable = inMemoryStore->InMemoryStore.getInMemTable(~entityMod)
  {
    set: entity => {
      inMemTable->InMemoryTable.Entity.set(
        Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId=getKey(entity)),
      )
    },
    deleteUnsafe: entityId => {
      inMemTable->InMemoryTable.Entity.set(
        Delete->Types.mkEntityUpdate(~eventIdentifier, ~entityId),
      )
    },
    get: loadLayer->LoadLayer.makeLoader(~entityMod, ~logger, ~inMemoryStore),
  }
}

let getContractRegisterContext = (contextEnv, ~inMemoryStore) => {
  //TODO only add contracts we've registered for the event in the config
  addAnthropicChatGpt:  makeDynamicContractRegisterFn(~contextEnv, ~inMemoryStore, ~contractName=AnthropicChatGpt),
  addBenchmarkMarketplace:  makeDynamicContractRegisterFn(~contextEnv, ~inMemoryStore, ~contractName=BenchmarkMarketplace),
}

let getLoaderContext = (contextEnv: t<'eventArgs>, ~inMemoryStore: InMemoryStore.t, ~loadLayer: LoadLayer.t): loaderContext => {
  let {logger} = contextEnv
  {
    log: logger->getUserLogger,
    benchmark: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.Benchmark),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
    chat: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.Chat),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
    game: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.Game),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
    llmResponse: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.LlmResponse),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
    message: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.Message),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
        chat_id: loadLayer->makeWhereLoader(
          ~entityMod=module(Entities.Message),
          ~inMemoryStore,
          ~fieldName="chat_id",
          ~fieldValueSchema=S.string,
          ~logger,
        ),
      
      },
    },
    stake: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.Stake),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
        benchmark_id: loadLayer->makeWhereLoader(
          ~entityMod=module(Entities.Stake),
          ~inMemoryStore,
          ~fieldName="benchmark_id",
          ~fieldValueSchema=S.string,
          ~logger,
        ),
      
      },
    },
    winningClaim: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.WinningClaim),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
  }
}

let getHandlerContext = (context, ~inMemoryStore: InMemoryStore.t, ~loadLayer) => {
  let {event, logger} = context

  let eventIdentifier = event->makeEventIdentifier
  {
    log: logger->getUserLogger,
    benchmark: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.Benchmark),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    chat: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.Chat),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    game: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.Game),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    llmResponse: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.LlmResponse),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    message: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.Message),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    stake: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.Stake),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    winningClaim: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.WinningClaim),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
  }
}

let getContractRegisterArgs = (contextEnv, ~inMemoryStore) => {
  RegisteredEvents.event: contextEnv.event,
  context: contextEnv->getContractRegisterContext(~inMemoryStore),
}

let getLoaderArgs = (contextEnv, ~inMemoryStore, ~loadLayer) => {
  RegisteredEvents.event: contextEnv.event,
  context: contextEnv->getLoaderContext(~inMemoryStore, ~loadLayer),
}

let getHandlerArgs = (contextEnv, ~inMemoryStore, ~loaderReturn, ~loadLayer) => {
  RegisteredEvents.event: contextEnv.event,
  context: contextEnv->getHandlerContext(~inMemoryStore, ~loadLayer),
  loaderReturn,
}
