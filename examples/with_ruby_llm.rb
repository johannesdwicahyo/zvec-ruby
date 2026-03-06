#!/usr/bin/env ruby
require "zvec/ruby_llm"
# require "ruby_llm"  # Uncomment when ruby_llm is installed

# This example shows how to use Zvec as a vector store with the ruby_llm gem.
#
# Prerequisites:
#   gem install ruby_llm
#   export OPENAI_API_KEY=your_key
#
# The Zvec::RubyLLM::Store provides a simple interface for storing and
# retrieving embeddings that can be used with any LLM framework.

DIMENSION = 4  # Use 1536 for OpenAI text-embedding-3-small

# Create a vector store
store = Zvec::RubyLLM::Store.new(
  "/tmp/zvec_ruby_llm_example",
  dimension: DIMENSION,
  metric: :cosine
)

# --- Option A: Manual embeddings (for demo without API keys) ---

store.add("chunk-1",
  embedding: [0.1, 0.2, 0.3, 0.4],
  content: "Ruby is a dynamic, open source programming language."
)

store.add("chunk-2",
  embedding: [0.4, 0.3, 0.2, 0.1],
  content: "Vector databases store and search high-dimensional vectors."
)

store.add_many([
  {
    id: "chunk-3",
    embedding: [0.2, 0.4, 0.1, 0.3],
    content: "Machine learning models generate embeddings from text."
  },
  {
    id: "chunk-4",
    embedding: [0.3, 0.1, 0.4, 0.2],
    content: "Retrieval-augmented generation improves LLM responses."
  }
])

store.flush

puts "Stored #{store.count} documents"

# Search
results = store.search([0.1, 0.2, 0.3, 0.4], top_k: 3)

puts "\nSearch results:"
results.each do |r|
  puts "  [#{r[:score].round(4)}] #{r[:id]}: #{r[:content]}"
end

# --- Option B: With ruby_llm (uncomment below) ---
#
# RubyLLM.configure do |config|
#   config.openai_api_key = ENV["OPENAI_API_KEY"]
# end
#
# # Use OpenAI to generate real embeddings
# embed = ->(text) { RubyLLM.embed(text).vectors.first }
#
# store.add("real-1",
#   embedding: embed.call("The quick brown fox"),
#   content: "The quick brown fox jumps over the lazy dog."
# )
#
# query_embedding = embed.call("fast animal")
# results = store.search(query_embedding, top_k: 5)

# Cleanup
store.collection.destroy
puts "\nDone!"
