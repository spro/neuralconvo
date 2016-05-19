require 'neuralconvo'
local tokenizer = require "tokenizer"
local list = require "pl.List"
local options = {}

if dataset == nil then
  cmd = torch.CmdLine()
  cmd:text('Options:')
  cmd:option('--cuda', false, 'use CUDA. Training must be done on CUDA')
  cmd:option('--opencl', false, 'use OpenCL. Training must be done on OpenCL')
  cmd:option('--debug', false, 'show debug info')
  cmd:option('--no-reverse', false, "don't reverse input sequence")
  cmd:option('--model', "data/model.t7", 'model filename')
  cmd:option('--vocab', "data/vocab.t7", 'vocab filename')
  cmd:text()
  options = cmd:parse(arg)
  options.reverse = not options['no-reverse']

  -- Data
  dataset = neuralconvo.DataSet(nil, {vocab=options.vocab})

  -- Enabled CUDA
  if options.cuda then
    require 'cutorch'
    require 'cunn'
  elseif options.opencl then
    require 'cltorch'
    require 'clnn'
  end
end

if model == nil then
  print("Loading model from " .. options.model .. " ...")
  model = torch.load(options.model)
end

-- Word IDs to sentence
function pred2sent(wordIds, i)
  local words = {}
  i = i or 1

  for _, wordId in ipairs(wordIds) do
    local word = dataset.id2word[wordId[i]]
    table.insert(words, word)
  end

  return tokenizer.join(words)
end

function printProbabilityTable(wordIds, probabilities, num)
  print(string.rep("-", num * 22))

  for p, wordId in ipairs(wordIds) do
    local line = "| "
    for i = 1, num do
      local word = dataset.id2word[wordId[i]]
      line = line .. string.format("%-10s(%4d%%)", word, probabilities[p][i] * 100) .. "  |  "
    end
    print(line)
  end

  print(string.rep("-", num * 22))
end

function say(text)
  local wordIds = {}

  for t, word in tokenizer.tokenize(text) do
    local id = dataset.word2id[word:lower()] or dataset.unknownToken
    table.insert(wordIds, id)
  end

  local wordIds, probabilities = model:eval(input)
  local input
  if options.reverse then
      input = torch.Tensor(list.reverse(wordIds))
  else
      input = torch.Tensor(wordIds)
  end

  print(">> " .. pred2sent(wordIds))

  if options.debug then
    printProbabilityTable(wordIds, probabilities, 4)
  end
end
