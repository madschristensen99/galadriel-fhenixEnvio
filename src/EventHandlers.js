const { AnthropicChatGpt, BenchmarkMarketplace } = require("generated");

// AnthropicChatGpt Event Handlers
AnthropicChatGpt.OracleLlmResponseReceived.handler(async ({ event, context }) => {
  const { runId, content, functionName, functionArguments, errorMessage } = event.params;
  
  const chat = await context.Chat.get(runId.toString());
  if (!chat) {
    console.error(`Chat not found for runId: ${runId}`);
    return;
  }

  const llmResponse = {
    id: `${event.transactionHash}-${event.logIndex}`,
    chat: chat.id,
    content,
    functionName,
    functionArguments,
    errorMessage,
    timestamp: event.blockTimestamp
  };

  context.LlmResponse.set(llmResponse);
});

AnthropicChatGpt.ChatCreated.handler(async ({ event, context }) => {
  const { owner, chatId } = event.params;
  
  const chat = {
    id: chatId.toString(),
    owner,
    createdAt: event.blockTimestamp
  };

  context.Chat.set(chat);
});

AnthropicChatGpt.MessageAdded.handler(async ({ event, context }) => {
  const { chatId, sender, role } = event.params;
  
  const message = {
    id: `${event.transactionHash}-${event.logIndex}`,
    chat: chatId.toString(),
    sender,
    role,
    content: '', // Note: The actual content isn't included in the event, you might need to fetch it separately
    timestamp: event.blockTimestamp
  };

  context.Message.set(message);
});

// BenchmarkMarketplace Event Handlers
BenchmarkMarketplace.BenchmarkCreated.handler(async ({ event, context }) => {
  const { benchmarkId, gameAddress, targetScore, odds, deadline } = event.params;
  
  const benchmark = {
    id: benchmarkId.toString(),
    gameAddress,
    targetScore: targetScore.toString(),
    odds: odds.toString(),
    deadline: deadline.toString(),
    totalStake: '0',
    active: true
  };

  context.Benchmark.set(benchmark);
});

BenchmarkMarketplace.BenchmarkUpdated.handler(async ({ event, context }) => {
  const { benchmarkId, newOdds } = event.params;
  
  const benchmark = await context.Benchmark.get(benchmarkId.toString());
  if (benchmark) {
    context.Benchmark.set({
      ...benchmark,
      odds: newOdds.toString()
    });
  }
});

BenchmarkMarketplace.BenchmarkCompleted.handler(async ({ event, context }) => {
  const { benchmarkId, winner, score } = event.params;
  
  const benchmark = await context.Benchmark.get(benchmarkId.toString());
  if (benchmark) {
    context.Benchmark.set({
      ...benchmark,
      active: false,
      winner,
      finalScore: score.toString()
    });
  }
});

BenchmarkMarketplace.GameApproved.handler(async ({ event, context }) => {
  const { gameAddress, name } = event.params;
  
  const game = {
    id: gameAddress,
    name,
    approved: true
  };

  context.Game.set(game);
});

BenchmarkMarketplace.GameRemoved.handler(async ({ event, context }) => {
  const { gameAddress } = event.params;
  
  const game = await context.Game.get(gameAddress);
  if (game) {
    context.Game.set({
      ...game,
      approved: false
    });
  }
});

BenchmarkMarketplace.StakePlaced.handler(async ({ event, context }) => {
  const { benchmarkId, player, amount } = event.params;
  
  const stake = {
    id: `${event.transactionHash}-${event.logIndex}`,
    benchmark: benchmarkId.toString(),
    player,
    amount: amount.toString()
  };

  context.Stake.set(stake);

  // Update total stake in the benchmark
  const benchmark = await context.Benchmark.get(benchmarkId.toString());
  if (benchmark) {
    const newTotalStake = (BigInt(benchmark.totalStake) + BigInt(amount)).toString();
    context.Benchmark.set({
      ...benchmark,
      totalStake: newTotalStake
    });
  }
});

BenchmarkMarketplace.WinningsClaimed.handler(async ({ event, context }) => {
  const { benchmarkId, player, amount } = event.params;
  
  const winningClaim = {
    id: `${event.transactionHash}-${event.logIndex}`,
    benchmark: benchmarkId.toString(),
    player,
    amount: amount.toString()
  };

  context.WinningClaim.set(winningClaim);
});
