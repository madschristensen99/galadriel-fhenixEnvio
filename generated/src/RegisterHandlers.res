@val external require: string => unit = "require"

let registerContractHandlers = (
  ~contractName,
  ~handlerPathRelativeToRoot,
  ~handlerPathRelativeToConfig,
) => {
  try {
    require("root/" ++ handlerPathRelativeToRoot)
  } catch {
  | exn =>
    let params = {
      "Contract Name": contractName,
      "Expected Handler Path": handlerPathRelativeToConfig,
      "Code": "EE500",
    }
    let logger = Logging.createChild(~params)

    let errHandler = exn->ErrorHandling.make(~msg="Failed to import handler file", ~logger)
    errHandler->ErrorHandling.log
    errHandler->ErrorHandling.raiseExn
  }
}

// TODO: Start using only config returned by registerAllHandlers instead of Config.getGenerated and Config.setGenerated
%%private(
  let chains = [
    {
      Config.confirmedBlockThreshold: 200,
      syncSource: 
        Rpc({
          provider: Ethers.JsonRpcProvider.make(
            ~rpcUrls=["https://devnet.galadriel.com"],
            ~chainId=696969,
            ~fallbackStallTimeout=10000,
          ),
          syncConfig: Config.getSyncConfig({
            initialBlockInterval: 10000,
            backoffMultiplicative: 0.8,
            accelerationAdditive: 2000,
            intervalCeiling: 10000,
            backoffMillis: 5000,
            queryTimeoutMillis: 20000,
          }),
        }),
      startBlock: 31251043,
      endBlock:  None ,
      chain: ChainMap.Chain.makeUnsafe(~chainId=696969),
      contracts: [
        {
          name: "AnthropicChatGpt",
          abi: Abis.anthropicChatGptAbi->Ethers.makeAbi,
          addresses: [
            "0xAdB7FE1e1d46166CaBD853bAB8E20c3650992A98"->Ethers.getAddressFromStringUnsafe,
          ],
          events: [
            module(Types.AnthropicChatGpt.OracleLlmResponseReceived),
            module(Types.AnthropicChatGpt.ChatCreated),
            module(Types.AnthropicChatGpt.MessageAdded),
          ],
        },
      ],
    },
    {
      Config.confirmedBlockThreshold: 200,
      syncSource: 
        Rpc({
          provider: Ethers.JsonRpcProvider.make(
            ~rpcUrls=["https://api.helium.fhenix.zone"],
            ~chainId=8008135,
            ~fallbackStallTimeout=10000,
          ),
          syncConfig: Config.getSyncConfig({
            initialBlockInterval: 10000,
            backoffMultiplicative: 0.8,
            accelerationAdditive: 2000,
            intervalCeiling: 10000,
            backoffMillis: 5000,
            queryTimeoutMillis: 20000,
          }),
        }),
      startBlock: 214247,
      endBlock:  None ,
      chain: ChainMap.Chain.makeUnsafe(~chainId=8008135),
      contracts: [
        {
          name: "BenchmarkMarketplace",
          abi: Abis.benchmarkMarketplaceAbi->Ethers.makeAbi,
          addresses: [
            "0x56E203846e90235EDBCeaf98c9a45B73cD9Ffe5d"->Ethers.getAddressFromStringUnsafe,
          ],
          events: [
            module(Types.BenchmarkMarketplace.BenchmarkCreated),
            module(Types.BenchmarkMarketplace.BenchmarkUpdated),
            module(Types.BenchmarkMarketplace.BenchmarkCompleted),
            module(Types.BenchmarkMarketplace.GameApproved),
            module(Types.BenchmarkMarketplace.GameRemoved),
            module(Types.BenchmarkMarketplace.StakePlaced),
            module(Types.BenchmarkMarketplace.WinningsClaimed),
          ],
        },
      ],
    },
  ]

  let config = Config.make(
    ~shouldRollbackOnReorg=true,
    ~shouldSaveFullHistory=false,
    ~shouldUseHypersyncClientDecoder=true,
    ~isUnorderedMultichainMode=false,
    ~chains,
    ~enableRawEvents=false,
    ~entities=[
      module(Entities.Benchmark),
      module(Entities.Chat),
      module(Entities.Game),
      module(Entities.LlmResponse),
      module(Entities.Message),
      module(Entities.Stake),
      module(Entities.WinningClaim),
    ],
  )
  Config.setGenerated(config)
)

let registerAllHandlers = () => {
  registerContractHandlers(
    ~contractName="AnthropicChatGpt",
    ~handlerPathRelativeToRoot="src/EventHandlers.js",
    ~handlerPathRelativeToConfig="src/EventHandlers.js",
  )
  registerContractHandlers(
    ~contractName="BenchmarkMarketplace",
    ~handlerPathRelativeToRoot="src/EventHandlers.js",
    ~handlerPathRelativeToConfig="src/EventHandlers.js",
  )
  config
}
