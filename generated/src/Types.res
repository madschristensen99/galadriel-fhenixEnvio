//*************
//***ENTITIES**
//*************
@genType.as("Id")
type id = string

@genType
type contractRegistrations = {
  //TODO only add contracts we've registered for the event in the config
  addAnthropicChatGpt: (Ethers.ethAddress) => unit,
  addBenchmarkMarketplace: (Ethers.ethAddress) => unit,
}

@genType
type entityLoaderContext<'entity, 'indexedFieldOperations> = {
  get: id => promise<option<'entity>>,
  getWhere: 'indexedFieldOperations,
}

@genType
type loaderContext = {
  log: Logs.userLogger,
  @as("Benchmark") benchmark: entityLoaderContext<Entities.Benchmark.t, Entities.Benchmark.indexedFieldOperations>,
  @as("Chat") chat: entityLoaderContext<Entities.Chat.t, Entities.Chat.indexedFieldOperations>,
  @as("Game") game: entityLoaderContext<Entities.Game.t, Entities.Game.indexedFieldOperations>,
  @as("LlmResponse") llmResponse: entityLoaderContext<Entities.LlmResponse.t, Entities.LlmResponse.indexedFieldOperations>,
  @as("Message") message: entityLoaderContext<Entities.Message.t, Entities.Message.indexedFieldOperations>,
  @as("Stake") stake: entityLoaderContext<Entities.Stake.t, Entities.Stake.indexedFieldOperations>,
  @as("WinningClaim") winningClaim: entityLoaderContext<Entities.WinningClaim.t, Entities.WinningClaim.indexedFieldOperations>,
}

@genType
type entityHandlerContext<'entity> = {
  get: id => promise<option<'entity>>,
  set: 'entity => unit,
  deleteUnsafe: id => unit,
}


@genType
type handlerContext = {
  log: Logs.userLogger,
  @as("Benchmark") benchmark: entityHandlerContext<Entities.Benchmark.t>,
  @as("Chat") chat: entityHandlerContext<Entities.Chat.t>,
  @as("Game") game: entityHandlerContext<Entities.Game.t>,
  @as("LlmResponse") llmResponse: entityHandlerContext<Entities.LlmResponse.t>,
  @as("Message") message: entityHandlerContext<Entities.Message.t>,
  @as("Stake") stake: entityHandlerContext<Entities.Stake.t>,
  @as("WinningClaim") winningClaim: entityHandlerContext<Entities.WinningClaim.t>,
}

//Re-exporting types for backwards compatability
@genType.as("Benchmark")
type benchmark = Entities.Benchmark.t
@genType.as("Chat")
type chat = Entities.Chat.t
@genType.as("Game")
type game = Entities.Game.t
@genType.as("LlmResponse")
type llmResponse = Entities.LlmResponse.t
@genType.as("Message")
type message = Entities.Message.t
@genType.as("Stake")
type stake = Entities.Stake.t
@genType.as("WinningClaim")
type winningClaim = Entities.WinningClaim.t

type eventIdentifier = {
  chainId: int,
  blockTimestamp: int,
  blockNumber: int,
  logIndex: int,
}

type entityUpdateAction<'entityType> =
  | Set('entityType)
  | Delete

type entityUpdate<'entityType> = {
  eventIdentifier: eventIdentifier,
  shouldSaveHistory: bool,
  entityId: id,
  entityUpdateAction: entityUpdateAction<'entityType>,
}

let mkEntityUpdate = (~shouldSaveHistory=true, ~eventIdentifier, ~entityId, entityUpdateAction) => {
  entityId,
  shouldSaveHistory,
  eventIdentifier,
  entityUpdateAction,
}

type entityValueAtStartOfBatch<'entityType> =
  | NotSet // The entity isn't in the DB yet
  | AlreadySet('entityType)

type existingValueInDb<'entityType> =
  | Retrieved(entityValueAtStartOfBatch<'entityType>)
  // NOTE: We use an postgres function solve the issue of this entities previous value not being known.
  | Unknown

type updatedValue<'entityType> = {
  // Initial value within a batch
  initial: existingValueInDb<'entityType>,
  latest: entityUpdate<'entityType>,
  history: array<entityUpdate<'entityType>>,
}
@genType
type inMemoryStoreRowEntity<'entityType> =
  | Updated(updatedValue<'entityType>)
  | InitialReadFromDb(entityValueAtStartOfBatch<'entityType>) // This means there is no change from the db.

//*************
//**CONTRACTS**
//*************

module Log = {
  type t = {
    address: Address.t,
    data: string,
    topics: array<Ethers.EventFilter.topic>,
    logIndex: int,
  }

  let fieldNames = ["address", "data", "topics", "logIndex"]
}

module Transaction = {
  @genType
  type t = {
    hash: string,
    transactionIndex: int,
  }

  let schema: S.schema<t> = S.object((_s): t => {
    hash: _s.field("hash", S.string),
    transactionIndex: _s.field("transactionIndex", S.int),
  })

  let querySelection: array<HyperSyncClient.QueryTypes.transactionField> = [
    Hash,
    TransactionIndex,
  ]

  let fieldNames: array<string> = [
    "hash",
    "transactionIndex",
  ]
}

module Block = {
  type selectableFields = {
    parentHash: string,
  }

  let schema: S.schema<selectableFields> = S.object((_s): selectableFields => {
    parentHash: _s.field("parentHash", S.string),
  })

  @genType
  type t = {
    number: int,
    timestamp: int,
    hash: string,
    ...selectableFields,
  }

  let getSelectableFields = ({
    parentHash,
    }: t): selectableFields => {
    parentHash: parentHash,
    }

  let querySelection: array<HyperSyncClient.QueryTypes.blockField> = [
    Number,
    Timestamp,
    Hash,
    ParentHash,
  ]

  let fieldNames: array<string> = [
    "number",
    "timestamp",
    "hash",
    "parentHash",
  ]
}

@genType.as("EventLog")
type eventLog<'a> = {
  params: 'a,
  chainId: int,
  srcAddress: Ethers.ethAddress,
  logIndex: int,
  transaction: Transaction.t,
  block: Block.t,
}

type internalEventArgs

module type Event = {
  let key: string
  let name: string
  let contractName: string
  type eventArgs
  let eventArgsSchema: S.schema<eventArgs>
  let convertHyperSyncEventArgs: HyperSyncClient.Decoder.decodedEvent => eventArgs
}
module type InternalEvent = Event with type eventArgs = internalEventArgs

external eventToInternal: eventLog<'a> => eventLog<internalEventArgs> = "%identity"
external eventModToInternal: module(Event with type eventArgs = 'a) => module(InternalEvent) = "%identity"
external eventModWithoutArgTypeToInternal: module(Event) => module(InternalEvent) = "%identity"

module AnthropicChatGpt = {
  module OracleLlmResponseReceived = {
    let key = "AnthropicChatGpt_0x6c14f3d7dd6ae6e2d8c8816896daead0b5e7febf7547442aad7634ced8b40d6d"
    let name = "OracleLlmResponseReceived"
    let contractName = "AnthropicChatGpt"

    @genType
    type eventArgs = {
      @as("runId")
      runId: bigint,
      @as("content")
      content: string,
      @as("functionName")
      functionName: string,
      @as("functionArguments")
      functionArguments: string,
      @as("errorMessage")
      errorMessage: string,
    }

    let eventArgsSchema = S.object(s => {
      runId: s.field("runId", BigInt.schema),
      content: s.field("content", S.string),
      functionName: s.field("functionName", S.string),
      functionArguments: s.field("functionArguments", S.string),
      errorMessage: s.field("errorMessage", S.string),
    })

    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        runId: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        content: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        functionName: decodedEvent.body->Js.Array2.unsafe_get(2)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        functionArguments: decodedEvent.body->Js.Array2.unsafe_get(3)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        errorMessage: decodedEvent.body->Js.Array2.unsafe_get(4)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
  }

  module ChatCreated = {
    let key = "AnthropicChatGpt_0xd1de2c4de50323207202f3df0bb1dec1a42e233aec245f25519d674c10bd72ca"
    let name = "ChatCreated"
    let contractName = "AnthropicChatGpt"

    @genType
    type eventArgs = {
      @as("owner")
      owner: Ethers.ethAddress,
      @as("chatId")
      chatId: bigint,
    }

    let eventArgsSchema = S.object(s => {
      owner: s.field("owner", Ethers.ethAddressSchema),
      chatId: s.field("chatId", BigInt.schema),
    })

    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        owner: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        chatId: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
  }

  module MessageAdded = {
    let key = "AnthropicChatGpt_0x04f05716f2a71826f9fb2de2e8e652fa813602db4ea3774e0283f75d598de4cb"
    let name = "MessageAdded"
    let contractName = "AnthropicChatGpt"

    @genType
    type eventArgs = {
      @as("chatId")
      chatId: bigint,
      @as("sender")
      sender: Ethers.ethAddress,
      @as("role")
      role: string,
    }

    let eventArgsSchema = S.object(s => {
      chatId: s.field("chatId", BigInt.schema),
      sender: s.field("sender", Ethers.ethAddressSchema),
      role: s.field("role", S.string),
    })

    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        chatId: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        sender: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        role: decodedEvent.body->Js.Array2.unsafe_get(2)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
  }

}

module BenchmarkMarketplace = {
  module BenchmarkCreated = {
    let key = "BenchmarkMarketplace_0x9c752cfa978da5045e61651da44d96ab6e5e5bebda578b690d0ac6f54eb42667"
    let name = "BenchmarkCreated"
    let contractName = "BenchmarkMarketplace"

    @genType
    type eventArgs = {
      @as("benchmarkId")
      benchmarkId: bigint,
      @as("gameAddress")
      gameAddress: Ethers.ethAddress,
      @as("targetScore")
      targetScore: bigint,
      @as("odds")
      odds: bigint,
      @as("deadline")
      deadline: bigint,
    }

    let eventArgsSchema = S.object(s => {
      benchmarkId: s.field("benchmarkId", BigInt.schema),
      gameAddress: s.field("gameAddress", Ethers.ethAddressSchema),
      targetScore: s.field("targetScore", BigInt.schema),
      odds: s.field("odds", BigInt.schema),
      deadline: s.field("deadline", BigInt.schema),
    })

    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        benchmarkId: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        gameAddress: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        targetScore: decodedEvent.body->Js.Array2.unsafe_get(2)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        odds: decodedEvent.body->Js.Array2.unsafe_get(3)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        deadline: decodedEvent.body->Js.Array2.unsafe_get(4)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
  }

  module BenchmarkUpdated = {
    let key = "BenchmarkMarketplace_0x2a3b0a05c210e9c1fc700dc881105bb80a88d565c3646cc9bd52d2423c92e28f"
    let name = "BenchmarkUpdated"
    let contractName = "BenchmarkMarketplace"

    @genType
    type eventArgs = {
      @as("benchmarkId")
      benchmarkId: bigint,
      @as("newOdds")
      newOdds: bigint,
    }

    let eventArgsSchema = S.object(s => {
      benchmarkId: s.field("benchmarkId", BigInt.schema),
      newOdds: s.field("newOdds", BigInt.schema),
    })

    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        benchmarkId: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        newOdds: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
  }

  module BenchmarkCompleted = {
    let key = "BenchmarkMarketplace_0xec1ff46066723e8f8f9869a013802a54c31e497ff3c783d56b3d20ae5673894b"
    let name = "BenchmarkCompleted"
    let contractName = "BenchmarkMarketplace"

    @genType
    type eventArgs = {
      @as("benchmarkId")
      benchmarkId: bigint,
      @as("winner")
      winner: Ethers.ethAddress,
      @as("score")
      score: bigint,
    }

    let eventArgsSchema = S.object(s => {
      benchmarkId: s.field("benchmarkId", BigInt.schema),
      winner: s.field("winner", Ethers.ethAddressSchema),
      score: s.field("score", BigInt.schema),
    })

    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        benchmarkId: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        winner: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        score: decodedEvent.body->Js.Array2.unsafe_get(2)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
  }

  module GameApproved = {
    let key = "BenchmarkMarketplace_0x03a96652c2af62a7ca19860b8e86b20aa0bf88659c2f39aa540d101bf582ef5d"
    let name = "GameApproved"
    let contractName = "BenchmarkMarketplace"

    @genType
    type eventArgs = {
      @as("gameAddress")
      gameAddress: Ethers.ethAddress,
      @as("name")
      name: string,
    }

    let eventArgsSchema = S.object(s => {
      gameAddress: s.field("gameAddress", Ethers.ethAddressSchema),
      name: s.field("name", S.string),
    })

    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        gameAddress: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        name: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
  }

  module GameRemoved = {
    let key = "BenchmarkMarketplace_0x79e522c2ccc4f9a35ab9a2d60c7a3d2ea971f1fe148f392afef6283a3f9395f1"
    let name = "GameRemoved"
    let contractName = "BenchmarkMarketplace"

    @genType
    type eventArgs = {
      @as("gameAddress")
      gameAddress: Ethers.ethAddress,
    }

    let eventArgsSchema = S.object(s => {
      gameAddress: s.field("gameAddress", Ethers.ethAddressSchema),
    })

    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        gameAddress: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
  }

  module StakePlaced = {
    let key = "BenchmarkMarketplace_0xdf10bb3bcdbed673d1617ae247e30a091bd3041df07c5df494ebd136f0f118d0"
    let name = "StakePlaced"
    let contractName = "BenchmarkMarketplace"

    @genType
    type eventArgs = {
      @as("benchmarkId")
      benchmarkId: bigint,
      @as("player")
      player: Ethers.ethAddress,
      @as("amount")
      amount: bigint,
    }

    let eventArgsSchema = S.object(s => {
      benchmarkId: s.field("benchmarkId", BigInt.schema),
      player: s.field("player", Ethers.ethAddressSchema),
      amount: s.field("amount", BigInt.schema),
    })

    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        benchmarkId: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        player: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        amount: decodedEvent.body->Js.Array2.unsafe_get(2)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
  }

  module WinningsClaimed = {
    let key = "BenchmarkMarketplace_0x5380cf6fe903b40c6d5a9e0dfbca2f3a423f0a21520b4d5947ed5169bdba946d"
    let name = "WinningsClaimed"
    let contractName = "BenchmarkMarketplace"

    @genType
    type eventArgs = {
      @as("benchmarkId")
      benchmarkId: bigint,
      @as("player")
      player: Ethers.ethAddress,
      @as("amount")
      amount: bigint,
    }

    let eventArgsSchema = S.object(s => {
      benchmarkId: s.field("benchmarkId", BigInt.schema),
      player: s.field("player", Ethers.ethAddressSchema),
      amount: s.field("amount", BigInt.schema),
    })

    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        benchmarkId: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        player: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        amount: decodedEvent.body->Js.Array2.unsafe_get(2)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
  }

}

@genType
type chainId = int

type eventBatchQueueItem = {
  timestamp: int,
  chain: ChainMap.Chain.t,
  blockNumber: int,
  logIndex: int,
  event: eventLog<internalEventArgs>,
  eventMod: module(InternalEvent),
  //Default to false, if an event needs to
  //be reprocessed after it has loaded dynamic contracts
  //This gets set to true and does not try and reload events
  hasRegisteredDynamicContracts?: bool,
}
