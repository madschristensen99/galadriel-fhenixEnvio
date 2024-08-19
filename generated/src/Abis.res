module EventSignatures = {
let anthropicChatGpt = [
    "OracleLlmResponseReceived(uint256 runId, string content, string functionName, string functionArguments, string errorMessage)",
    "ChatCreated(address owner, uint256 chatId)",
    "MessageAdded(uint256 chatId, address sender, string role)",
  ]

let benchmarkMarketplace = [
    "BenchmarkCreated(uint256 benchmarkId, address gameAddress, uint256 targetScore, uint256 odds, uint256 deadline)",
    "BenchmarkUpdated(uint256 benchmarkId, uint256 newOdds)",
    "BenchmarkCompleted(uint256 benchmarkId, address winner, uint256 score)",
    "GameApproved(address gameAddress, string name)",
    "GameRemoved(address gameAddress)",
    "StakePlaced(uint256 benchmarkId, address player, uint256 amount)",
    "WinningsClaimed(uint256 benchmarkId, address player, uint256 amount)",
  ]

let all = [
   anthropicChatGpt,
   benchmarkMarketplace,
  ]->Belt.Array.concatMany
}

let
anthropicChatGptAbi = `
[{"type":"event","name":"ChatCreated","inputs":[{"name":"owner","type":"address","indexed":false},{"name":"chatId","type":"uint256","indexed":false}],"anonymous":false},{"type":"event","name":"MessageAdded","inputs":[{"name":"chatId","type":"uint256","indexed":false},{"name":"sender","type":"address","indexed":false},{"name":"role","type":"string","indexed":false}],"anonymous":false},{"type":"event","name":"OracleLlmResponseReceived","inputs":[{"name":"runId","type":"uint256","indexed":false},{"name":"content","type":"string","indexed":false},{"name":"functionName","type":"string","indexed":false},{"name":"functionArguments","type":"string","indexed":false},{"name":"errorMessage","type":"string","indexed":false}],"anonymous":false}]
`->Js.Json.parseExn
let
benchmarkMarketplaceAbi = `
[{"type":"event","name":"BenchmarkCompleted","inputs":[{"name":"benchmarkId","type":"uint256","indexed":false},{"name":"winner","type":"address","indexed":false},{"name":"score","type":"uint256","indexed":false}],"anonymous":false},{"type":"event","name":"BenchmarkCreated","inputs":[{"name":"benchmarkId","type":"uint256","indexed":false},{"name":"gameAddress","type":"address","indexed":false},{"name":"targetScore","type":"uint256","indexed":false},{"name":"odds","type":"uint256","indexed":false},{"name":"deadline","type":"uint256","indexed":false}],"anonymous":false},{"type":"event","name":"BenchmarkUpdated","inputs":[{"name":"benchmarkId","type":"uint256","indexed":false},{"name":"newOdds","type":"uint256","indexed":false}],"anonymous":false},{"type":"event","name":"GameApproved","inputs":[{"name":"gameAddress","type":"address","indexed":false},{"name":"name","type":"string","indexed":false}],"anonymous":false},{"type":"event","name":"GameRemoved","inputs":[{"name":"gameAddress","type":"address","indexed":false}],"anonymous":false},{"type":"event","name":"StakePlaced","inputs":[{"name":"benchmarkId","type":"uint256","indexed":false},{"name":"player","type":"address","indexed":false},{"name":"amount","type":"uint256","indexed":false}],"anonymous":false},{"type":"event","name":"WinningsClaimed","inputs":[{"name":"benchmarkId","type":"uint256","indexed":false},{"name":"player","type":"address","indexed":false},{"name":"amount","type":"uint256","indexed":false}],"anonymous":false}]
`->Js.Json.parseExn
