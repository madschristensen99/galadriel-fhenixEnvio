/***** TAKE NOTE ******
This is a hack to get genType to work!

In order for genType to produce recursive types, it needs to be at the 
root module of a file. If it's defined in a nested module it does not 
work. So all the MockDb types and internal functions are defined in TestHelpers_MockDb
and only public functions are recreated and exported from this module.

the following module:
```rescript
module MyModule = {
  @genType
  type rec a = {fieldB: b}
  @genType and b = {fieldA: a}
}
```

produces the following in ts:
```ts
// tslint:disable-next-line:interface-over-type-literal
export type MyModule_a = { readonly fieldB: b };

// tslint:disable-next-line:interface-over-type-literal
export type MyModule_b = { readonly fieldA: MyModule_a };
```

fieldB references type b which doesn't exist because it's defined
as MyModule_b
*/

module MockDb = {
  @genType
  let createMockDb = TestHelpers_MockDb.createMockDb
}

@genType
module Addresses = {
  include TestHelpers_MockAddresses
}


module EventFunctions = {
  /**
  The arguements that get passed to a "processEvent" helper function
  */
  //Note these are made into a record to make operate in the same way
  //for Res, JS and TS.
  @genType
  type eventProcessorArgs<'eventArgs> = {
    event: Types.eventLog<'eventArgs>,
    mockDb: TestHelpers_MockDb.t,
    chainId?: int,
  }

  /**
  A function composer to help create individual processEvent functions
  */
  let makeEventProcessor = (
    ~eventMod: module(Types.Event with type eventArgs = 'eventArgs),
  ) => {
    async (args) => {
      let eventMod = eventMod->Types.eventModToInternal
      let {event, mockDb, ?chainId} = args->(Utils.magic: eventProcessorArgs<'eventArgs> => eventProcessorArgs<Types.internalEventArgs>)
      let module(Event) = eventMod
      let config = RegisterHandlers.registerAllHandlers()

      // The user can specify a chainId of an event or leave it off
      // and it will default to the first chain in the config
      let chain = switch chainId {
        | Some(chainId) => {
          config->Config.getChain(~chainId)
        }
        | None => switch config.defaultChain {
          | Some(chainConfig) => chainConfig.chain
          | None => Js.Exn.raiseError("No default chain Id found, please add at least 1 chain to your config.yaml")
        }
      }

      //Create an individual logging context for traceability
      let logger = Logging.createChild(
        ~params={
          "Context": `Test Processor for "${Event.name}" event on contract "${Event.contractName}"`,
          "Chain ID": chain->ChainMap.Chain.toChainId,
          "event": event,
        },
      )

      //Deep copy the data in mockDb, mutate the clone and return the clone
      //So no side effects occur here and state can be compared between process
      //steps
      let mockDbClone = mockDb->TestHelpers_MockDb.cloneMockDb

      let registeredEvent = switch RegisteredEvents.global->RegisteredEvents.get(eventMod) {
      | Some(l) => l
      | None =>
        Not_found->ErrorHandling.mkLogAndRaise(
          ~logger,
          ~msg=`No registered handler found for "${Event.name}" on contract "${Event.contractName}"`,
        )
      }
      //Construct a new instance of an in memory store to run for the given event
      let inMemoryStore = InMemoryStore.make()
      let loadLayer = LoadLayer.make(
        ~loadEntitiesByIds=TestHelpers_MockDb.makeLoadEntitiesByIds(mockDbClone),
        ~makeLoadEntitiesByField=(~entityMod) => TestHelpers_MockDb.makeLoadEntitiesByField(mockDbClone, ~entityMod),
      )

      //No need to check contract is registered or return anything.
      //The only purpose is to test the registerContract function and to
      //add the entity to the in memory store for asserting registrations

      switch registeredEvent.contractRegister {
      | Some(contractRegister) =>
        switch contractRegister->EventProcessing.runEventContractRegister(
          ~logger,
          ~event,
          ~eventBatchQueueItem={
            event,
            eventMod,
            chain,
            logIndex: event.logIndex,
            timestamp: event.block.timestamp,
            blockNumber: event.block.number,
          },
          ~checkContractIsRegistered=(~chain as _, ~contractAddress as _, ~contractName as _) =>
            false,
          ~dynamicContractRegistrations=None,
          ~inMemoryStore,
        ) {
        | Ok(_) => ()
        | Error(e) => e->ErrorHandling.logAndRaise
        }
      | None => () //No need to run contract registration
      }

      let latestProcessedBlocks = EventProcessing.EventsProcessed.makeEmpty(~config)

      switch registeredEvent.loaderHandler {
      | Some(handler) =>
        switch await event->EventProcessing.runEventHandler(
          ~inMemoryStore,
          ~loadLayer,
          ~handler,
          ~eventMod,
          ~chain,
          ~logger,
          ~latestProcessedBlocks,
          ~config,
        ) {
        | Ok(_) => ()
        | Error(e) => e->ErrorHandling.logAndRaise
        }
      | None => ()//No need to run loaders or handlers
      }

      //In mem store can still contatin raw events and dynamic contracts for the
      //testing framework in cases where either contract register or loaderHandler
      //is None
      mockDbClone->TestHelpers_MockDb.writeFromMemoryStore(~inMemoryStore)
      mockDbClone
    }
  }

  module MockBlock = {
    open Belt
    type t = {
      number?: int,
      timestamp?: int,
      hash?: string,
      parentHash?: string,
    }

    let toBlock = (mock: t): Types.Block.t => {
      number: mock.number->Option.getWithDefault(0),
      timestamp: mock.timestamp->Option.getWithDefault(0),
      hash: mock.hash->Option.getWithDefault("foo"),
      parentHash: mock.parentHash->Option.getWithDefault("foo"),
    }
  }

  module MockTransaction = {
    type t = {
      hash?: string,
      transactionIndex?: int,
    }

    let toTransaction = (_mock: t): Types.Transaction.t => {
      hash: _mock.hash->Belt.Option.getWithDefault("foo"),
      transactionIndex: _mock.transactionIndex->Belt.Option.getWithDefault(0),
    }
  }

  @genType
  type mockEventData = {
    chainId?: int,
    srcAddress?: Ethers.ethAddress,
    logIndex?: int,
    block?: MockBlock.t,
    transaction?: MockTransaction.t,
  }

  /**
  Applies optional paramters with defaults for all common eventLog field
  */
  let makeEventMocker = (
    ~params: 'eventParams,
    ~mockEventData: option<mockEventData>,
  ): Types.eventLog<'eventParams> => {
    let {?block, ?transaction, ?srcAddress, ?chainId, ?logIndex} =
      mockEventData->Belt.Option.getWithDefault({})
    let block = block->Belt.Option.getWithDefault({})->MockBlock.toBlock
    let transaction = transaction->Belt.Option.getWithDefault({})->MockTransaction.toTransaction
    {
      params,
      transaction,
      chainId: chainId->Belt.Option.getWithDefault(1),
      block,
      srcAddress: srcAddress->Belt.Option.getWithDefault(Addresses.defaultAddress),
      logIndex: logIndex->Belt.Option.getWithDefault(0),
    }
  }
}


module AnthropicChatGpt = {
  module OracleLlmResponseReceived = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.AnthropicChatGpt.OracleLlmResponseReceived),
    )

    @genType
    type createMockArgs = {
      @as("runId")
      runId?: bigint,
      @as("content")
      content?: string,
      @as("functionName")
      functionName?: string,
      @as("functionArguments")
      functionArguments?: string,
      @as("errorMessage")
      errorMessage?: string,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?runId,
        ?content,
        ?functionName,
        ?functionArguments,
        ?errorMessage,
        ?mockEventData,
      } = args

      let params: Types.AnthropicChatGpt.OracleLlmResponseReceived.eventArgs = 
      {
       runId: runId->Belt.Option.getWithDefault(0n),
       content: content->Belt.Option.getWithDefault("foo"),
       functionName: functionName->Belt.Option.getWithDefault("foo"),
       functionArguments: functionArguments->Belt.Option.getWithDefault("foo"),
       errorMessage: errorMessage->Belt.Option.getWithDefault("foo"),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

  module ChatCreated = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.AnthropicChatGpt.ChatCreated),
    )

    @genType
    type createMockArgs = {
      @as("owner")
      owner?: Ethers.ethAddress,
      @as("chatId")
      chatId?: bigint,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?owner,
        ?chatId,
        ?mockEventData,
      } = args

      let params: Types.AnthropicChatGpt.ChatCreated.eventArgs = 
      {
       owner: owner->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       chatId: chatId->Belt.Option.getWithDefault(0n),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

  module MessageAdded = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.AnthropicChatGpt.MessageAdded),
    )

    @genType
    type createMockArgs = {
      @as("chatId")
      chatId?: bigint,
      @as("sender")
      sender?: Ethers.ethAddress,
      @as("role")
      role?: string,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?chatId,
        ?sender,
        ?role,
        ?mockEventData,
      } = args

      let params: Types.AnthropicChatGpt.MessageAdded.eventArgs = 
      {
       chatId: chatId->Belt.Option.getWithDefault(0n),
       sender: sender->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       role: role->Belt.Option.getWithDefault("foo"),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

}


module BenchmarkMarketplace = {
  module BenchmarkCreated = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.BenchmarkMarketplace.BenchmarkCreated),
    )

    @genType
    type createMockArgs = {
      @as("benchmarkId")
      benchmarkId?: bigint,
      @as("gameAddress")
      gameAddress?: Ethers.ethAddress,
      @as("targetScore")
      targetScore?: bigint,
      @as("odds")
      odds?: bigint,
      @as("deadline")
      deadline?: bigint,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?benchmarkId,
        ?gameAddress,
        ?targetScore,
        ?odds,
        ?deadline,
        ?mockEventData,
      } = args

      let params: Types.BenchmarkMarketplace.BenchmarkCreated.eventArgs = 
      {
       benchmarkId: benchmarkId->Belt.Option.getWithDefault(0n),
       gameAddress: gameAddress->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       targetScore: targetScore->Belt.Option.getWithDefault(0n),
       odds: odds->Belt.Option.getWithDefault(0n),
       deadline: deadline->Belt.Option.getWithDefault(0n),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

  module BenchmarkUpdated = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.BenchmarkMarketplace.BenchmarkUpdated),
    )

    @genType
    type createMockArgs = {
      @as("benchmarkId")
      benchmarkId?: bigint,
      @as("newOdds")
      newOdds?: bigint,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?benchmarkId,
        ?newOdds,
        ?mockEventData,
      } = args

      let params: Types.BenchmarkMarketplace.BenchmarkUpdated.eventArgs = 
      {
       benchmarkId: benchmarkId->Belt.Option.getWithDefault(0n),
       newOdds: newOdds->Belt.Option.getWithDefault(0n),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

  module BenchmarkCompleted = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.BenchmarkMarketplace.BenchmarkCompleted),
    )

    @genType
    type createMockArgs = {
      @as("benchmarkId")
      benchmarkId?: bigint,
      @as("winner")
      winner?: Ethers.ethAddress,
      @as("score")
      score?: bigint,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?benchmarkId,
        ?winner,
        ?score,
        ?mockEventData,
      } = args

      let params: Types.BenchmarkMarketplace.BenchmarkCompleted.eventArgs = 
      {
       benchmarkId: benchmarkId->Belt.Option.getWithDefault(0n),
       winner: winner->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       score: score->Belt.Option.getWithDefault(0n),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

  module GameApproved = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.BenchmarkMarketplace.GameApproved),
    )

    @genType
    type createMockArgs = {
      @as("gameAddress")
      gameAddress?: Ethers.ethAddress,
      @as("name")
      name?: string,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?gameAddress,
        ?name,
        ?mockEventData,
      } = args

      let params: Types.BenchmarkMarketplace.GameApproved.eventArgs = 
      {
       gameAddress: gameAddress->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       name: name->Belt.Option.getWithDefault("foo"),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

  module GameRemoved = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.BenchmarkMarketplace.GameRemoved),
    )

    @genType
    type createMockArgs = {
      @as("gameAddress")
      gameAddress?: Ethers.ethAddress,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?gameAddress,
        ?mockEventData,
      } = args

      let params: Types.BenchmarkMarketplace.GameRemoved.eventArgs = 
      {
       gameAddress: gameAddress->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

  module StakePlaced = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.BenchmarkMarketplace.StakePlaced),
    )

    @genType
    type createMockArgs = {
      @as("benchmarkId")
      benchmarkId?: bigint,
      @as("player")
      player?: Ethers.ethAddress,
      @as("amount")
      amount?: bigint,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?benchmarkId,
        ?player,
        ?amount,
        ?mockEventData,
      } = args

      let params: Types.BenchmarkMarketplace.StakePlaced.eventArgs = 
      {
       benchmarkId: benchmarkId->Belt.Option.getWithDefault(0n),
       player: player->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       amount: amount->Belt.Option.getWithDefault(0n),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

  module WinningsClaimed = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.BenchmarkMarketplace.WinningsClaimed),
    )

    @genType
    type createMockArgs = {
      @as("benchmarkId")
      benchmarkId?: bigint,
      @as("player")
      player?: Ethers.ethAddress,
      @as("amount")
      amount?: bigint,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?benchmarkId,
        ?player,
        ?amount,
        ?mockEventData,
      } = args

      let params: Types.BenchmarkMarketplace.WinningsClaimed.eventArgs = 
      {
       benchmarkId: benchmarkId->Belt.Option.getWithDefault(0n),
       player: player->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       amount: amount->Belt.Option.getWithDefault(0n),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

}

