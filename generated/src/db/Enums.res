// Graphql Enum Type Variants
type enumType<'a> = {
  name: string,
  variants: array<'a>,
}

let mkEnum = (~name, ~variants) => {
  name,
  variants,
}

module type Enum = {
  type t
  let enum: enumType<t>
}

module ContractType = {
  @genType
  type t = 
    | @as("AnthropicChatGpt") AnthropicChatGpt
    | @as("BenchmarkMarketplace") BenchmarkMarketplace

  let schema = 
    S.union([
      S.literal(AnthropicChatGpt), 
      S.literal(BenchmarkMarketplace), 
    ])

  let name = "CONTRACT_TYPE"
  let variants = [
    AnthropicChatGpt,
    BenchmarkMarketplace,
  ]
  let enum = mkEnum(~name, ~variants)
}

module EntityType = {
  @genType
  type t = 
    | @as("Benchmark") Benchmark
    | @as("Chat") Chat
    | @as("Game") Game
    | @as("LlmResponse") LlmResponse
    | @as("Message") Message
    | @as("Stake") Stake
    | @as("WinningClaim") WinningClaim

  let schema = S.union([
    S.literal(Benchmark), 
    S.literal(Chat), 
    S.literal(Game), 
    S.literal(LlmResponse), 
    S.literal(Message), 
    S.literal(Stake), 
    S.literal(WinningClaim), 
  ])

  let name = "ENTITY_TYPE"
  let variants = [
    Benchmark,
    Chat,
    Game,
    LlmResponse,
    Message,
    Stake,
    WinningClaim,
  ]

  let enum = mkEnum(~name, ~variants)
}


let allEnums: array<module(Enum)> = [
  module(ContractType), 
  module(EntityType),
]
