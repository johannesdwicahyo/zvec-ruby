#!/usr/bin/env ruby
require "zvec"

# Define schema with a vector field and scalar fields
schema = Zvec::Schema.new("my_docs") do
  string "title"
  string "category", nullable: true
  int32  "year"
  vector "embedding", dimension: 4,
         index: Zvec::Ext::HnswIndexParams.new(Zvec::COSINE)
end

# Create collection
path = "/tmp/zvec_ruby_example"
FileUtils.rm_rf(path) if Dir.exist?(path)

collection = Zvec::Collection.create_and_open(path, schema)

# Insert documents
docs = [
  { pk: "doc1", title: "Ruby Gems", category: "programming", year: 2024,
    embedding: [0.1, 0.2, 0.3, 0.4] },
  { pk: "doc2", title: "Vector Databases", category: "databases", year: 2025,
    embedding: [0.4, 0.3, 0.2, 0.1] },
  { pk: "doc3", title: "Machine Learning", category: "ai", year: 2025,
    embedding: [0.2, 0.4, 0.1, 0.3] },
]

docs.each do |d|
  collection.add(pk: d[:pk], **d.except(:pk))
end

puts "Inserted #{collection.doc_count} documents"

# Search
query_vector = [0.1, 0.2, 0.3, 0.4]
results = collection.search(query_vector, top_k: 2)

puts "\nSearch results (top 2):"
results.each do |doc|
  puts "  #{doc.pk}: score=#{doc.score}, title=#{doc["title"]}"
end

# Fetch by ID
fetched = collection.fetch("doc2")
puts "\nFetched doc2: #{fetched["doc2"]&.to_h}"

# Filter query
results = collection.query(
  field_name: "embedding",
  vector: query_vector,
  topk: 10,
  filter: "year == 2025"
)

puts "\nFiltered results (year=2025):"
results.each do |doc|
  puts "  #{doc.pk}: #{doc["title"]}"
end

# Cleanup
collection.destroy
puts "\nDone!"
