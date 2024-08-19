open Table
open Enums.EntityType
type id = string

type internalEntity
module type Entity = {
  type t
  let key: string
  let name: Enums.EntityType.t
  let schema: S.schema<t>
  let rowsSchema: S.schema<array<t>>
  let table: Table.table
}
module type InternalEntity = Entity with type t = internalEntity
external entityModToInternal: module(Entity with type t = 'a) => module(InternalEntity) = "%identity"

//shorthand for punning
let isPrimaryKey = true
let isNullable = true
let isArray = true
let isIndex = true

@genType
type whereOperations<'entity, 'fieldType> = {eq: 'fieldType => promise<array<'entity>>}

module Benchmark = {
  let key = "Benchmark"
  let name = Benchmark
  @genType
  type t = {
    active: bool,
    deadline: bigint,
    finalScore: option<bigint>,
    gameAddress: string,
    id: id,
    odds: bigint,
    
    targetScore: bigint,
    totalStake: bigint,
    winner: option<string>,
  }

  let schema = S.object((s): t => {
    active: s.field("active", S.bool),
    deadline: s.field("deadline", BigInt.schema),
    finalScore: s.field("finalScore", S.null(BigInt.schema)),
    gameAddress: s.field("gameAddress", S.string),
    id: s.field("id", S.string),
    odds: s.field("odds", BigInt.schema),
    
    targetScore: s.field("targetScore", BigInt.schema),
    totalStake: s.field("totalStake", BigInt.schema),
    winner: s.field("winner", S.null(S.string)),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "active", 
      Boolean,
      
      
      
      
      
      ),
      mkField(
      "deadline", 
      Numeric,
      
      
      
      
      
      ),
      mkField(
      "finalScore", 
      Numeric,
      
      ~isNullable,
      
      
      
      ),
      mkField(
      "gameAddress", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "odds", 
      Numeric,
      
      
      
      
      
      ),
      mkField(
      "targetScore", 
      Numeric,
      
      
      
      
      
      ),
      mkField(
      "totalStake", 
      Numeric,
      
      
      
      
      
      ),
      mkField(
      "winner", 
      Text,
      
      ~isNullable,
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
      mkDerivedFromField(
      "stakes", 
      ~derivedFromEntity="Stake",
      ~derivedFromField="benchmark",
      ),
    ],
  )
}
 
module Chat = {
  let key = "Chat"
  let name = Chat
  @genType
  type t = {
    createdAt: bigint,
    id: id,
    
    owner: string,
  }

  let schema = S.object((s): t => {
    createdAt: s.field("createdAt", BigInt.schema),
    id: s.field("id", S.string),
    
    owner: s.field("owner", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "createdAt", 
      Numeric,
      
      
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "owner", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
      mkDerivedFromField(
      "messages", 
      ~derivedFromEntity="Message",
      ~derivedFromField="chat",
      ),
    ],
  )
}
 
module Game = {
  let key = "Game"
  let name = Game
  @genType
  type t = {
    approved: bool,
    id: id,
    name: string,
  }

  let schema = S.object((s): t => {
    approved: s.field("approved", S.bool),
    id: s.field("id", S.string),
    name: s.field("name", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "approved", 
      Boolean,
      
      
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "name", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 
module LlmResponse = {
  let key = "LlmResponse"
  let name = LlmResponse
  @genType
  type t = {
    chat_id: id,
    content: string,
    errorMessage: option<string>,
    functionArguments: option<string>,
    functionName: option<string>,
    id: id,
    timestamp: bigint,
  }

  let schema = S.object((s): t => {
    chat_id: s.field("chat_id", S.string),
    content: s.field("content", S.string),
    errorMessage: s.field("errorMessage", S.null(S.string)),
    functionArguments: s.field("functionArguments", S.null(S.string)),
    functionName: s.field("functionName", S.null(S.string)),
    id: s.field("id", S.string),
    timestamp: s.field("timestamp", BigInt.schema),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "chat", 
      Text,
      
      
      
      
      ~linkedEntity="Chat",
      ),
      mkField(
      "content", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "errorMessage", 
      Text,
      
      ~isNullable,
      
      
      
      ),
      mkField(
      "functionArguments", 
      Text,
      
      ~isNullable,
      
      
      
      ),
      mkField(
      "functionName", 
      Text,
      
      ~isNullable,
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "timestamp", 
      Numeric,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 
module Message = {
  let key = "Message"
  let name = Message
  @genType
  type t = {
    chat_id: id,
    content: string,
    id: id,
    role: string,
    sender: string,
    timestamp: bigint,
  }

  let schema = S.object((s): t => {
    chat_id: s.field("chat_id", S.string),
    content: s.field("content", S.string),
    id: s.field("id", S.string),
    role: s.field("role", S.string),
    sender: s.field("sender", S.string),
    timestamp: s.field("timestamp", BigInt.schema),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
      @as("chat_id") chat_id: whereOperations<t, id>,
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "chat", 
      Text,
      
      
      
      
      ~linkedEntity="Chat",
      ),
      mkField(
      "content", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "role", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "sender", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "timestamp", 
      Numeric,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 
module Stake = {
  let key = "Stake"
  let name = Stake
  @genType
  type t = {
    amount: bigint,
    benchmark_id: id,
    id: id,
    player: string,
  }

  let schema = S.object((s): t => {
    amount: s.field("amount", BigInt.schema),
    benchmark_id: s.field("benchmark_id", S.string),
    id: s.field("id", S.string),
    player: s.field("player", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
      @as("benchmark_id") benchmark_id: whereOperations<t, id>,
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "amount", 
      Numeric,
      
      
      
      
      
      ),
      mkField(
      "benchmark", 
      Text,
      
      
      
      
      ~linkedEntity="Benchmark",
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "player", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 
module WinningClaim = {
  let key = "WinningClaim"
  let name = WinningClaim
  @genType
  type t = {
    amount: bigint,
    benchmark_id: id,
    id: id,
    player: string,
  }

  let schema = S.object((s): t => {
    amount: s.field("amount", BigInt.schema),
    benchmark_id: s.field("benchmark_id", S.string),
    id: s.field("id", S.string),
    player: s.field("player", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "amount", 
      Numeric,
      
      
      
      
      
      ),
      mkField(
      "benchmark", 
      Text,
      
      
      
      
      ~linkedEntity="Benchmark",
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "player", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 

type entity = 
  | Benchmark(Benchmark.t)
  | Chat(Chat.t)
  | Game(Game.t)
  | LlmResponse(LlmResponse.t)
  | Message(Message.t)
  | Stake(Stake.t)
  | WinningClaim(WinningClaim.t)

let makeGetter = (schema, accessor) => json => json->S.parseWith(schema)->Belt.Result.map(accessor)

let getEntityParamsDecoder = (entityName: Enums.EntityType.t) =>
  switch entityName {
  | Benchmark => makeGetter(Benchmark.schema, e => Benchmark(e))
  | Chat => makeGetter(Chat.schema, e => Chat(e))
  | Game => makeGetter(Game.schema, e => Game(e))
  | LlmResponse => makeGetter(LlmResponse.schema, e => LlmResponse(e))
  | Message => makeGetter(Message.schema, e => Message(e))
  | Stake => makeGetter(Stake.schema, e => Stake(e))
  | WinningClaim => makeGetter(WinningClaim.schema, e => WinningClaim(e))
  }

let allTables: array<table> = [
  Benchmark.table,
  Chat.table,
  Game.table,
  LlmResponse.table,
  Message.table,
  Stake.table,
  WinningClaim.table,
]
let schema = Schema.make(allTables)

@get
external getEntityId: internalEntity => string = "id"

exception UnexpectedIdNotDefinedOnEntity
let getEntityIdUnsafe = (entity: 'entity): id =>
  switch Utils.magic(entity)["id"] {
  | Some(id) => id
  | None =>
    UnexpectedIdNotDefinedOnEntity->ErrorHandling.mkLogAndRaise(
      ~msg="Property 'id' does not exist on expected entity object",
    )
  }
