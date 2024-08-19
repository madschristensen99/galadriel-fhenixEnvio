  @genType
module AnthropicChatGpt = {
  module OracleLlmResponseReceived = RegisteredEvents.MakeRegister(Types.AnthropicChatGpt.OracleLlmResponseReceived)
  module ChatCreated = RegisteredEvents.MakeRegister(Types.AnthropicChatGpt.ChatCreated)
  module MessageAdded = RegisteredEvents.MakeRegister(Types.AnthropicChatGpt.MessageAdded)
}

  @genType
module BenchmarkMarketplace = {
  module BenchmarkCreated = RegisteredEvents.MakeRegister(Types.BenchmarkMarketplace.BenchmarkCreated)
  module BenchmarkUpdated = RegisteredEvents.MakeRegister(Types.BenchmarkMarketplace.BenchmarkUpdated)
  module BenchmarkCompleted = RegisteredEvents.MakeRegister(Types.BenchmarkMarketplace.BenchmarkCompleted)
  module GameApproved = RegisteredEvents.MakeRegister(Types.BenchmarkMarketplace.GameApproved)
  module GameRemoved = RegisteredEvents.MakeRegister(Types.BenchmarkMarketplace.GameRemoved)
  module StakePlaced = RegisteredEvents.MakeRegister(Types.BenchmarkMarketplace.StakePlaced)
  module WinningsClaimed = RegisteredEvents.MakeRegister(Types.BenchmarkMarketplace.WinningsClaimed)
}

