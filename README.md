# zvec-ruby

Ruby bindings for [zvec](https://github.com/alibaba/zvec), a high-performance C++ vector database from Alibaba. Built with [Rice](https://github.com/jasonroelofs/rice) (Ruby's C++ binding library).

## Installation

### Precompiled (recommended)

Precompiled native gems are available for:

| Platform | Architectures |
|---|---|
| Linux | x86_64, aarch64 |
| macOS | x86_64 (Intel), arm64 (Apple Silicon) |

```ruby
# Gemfile
gem "zvec"
```

```bash
gem install zvec
```

No compiler or build tools needed — the gem ships with the native extension and all zvec dependencies statically linked.

### From source

If no precompiled gem is available for your platform, you'll need to build zvec first:

```bash
# 1. Build zvec from source
git clone --depth 1 https://github.com/alibaba/zvec /tmp/zvec
cd /tmp/zvec && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# 2. Install the gem with ZVEC_DIR pointing to the build
ZVEC_DIR=/tmp/zvec gem install zvec
```

Or using the included helper script:

```bash
git clone https://github.com/johannesdwicahyo/zvec-ruby
cd zvec-ruby
./script/build_zvec.sh
ZVEC_DIR=/tmp/zvec bundle install && bundle exec rake compile
```

## Quick Start

```ruby
require "zvec"

# Define a schema
schema = Zvec::Schema.new("my_collection") do
  string "title"
  int32  "year"
  vector "embedding", dimension: 128,
         index: Zvec::Ext::HnswIndexParams.new(Zvec::COSINE)
end

# Create and populate a collection
collection = Zvec::Collection.create_and_open("/tmp/my_vectors", schema)

collection.add(pk: "doc1", title: "Hello", year: 2025,
               embedding: Array.new(128) { rand })

# Search
results = collection.search([0.1] * 128, top_k: 5)
results.each { |doc| puts "#{doc.pk}: #{doc.score}" }

# Clean up
collection.destroy
```

## Schema DSL

```ruby
schema = Zvec::Schema.new("name") do
  string  "title"
  int32   "count"
  int64   "big_count"
  float   "score"
  double  "precise_score"
  bool    "active"
  vector  "embedding", dimension: 1536
  field   "tags", Zvec::ARRAY_STRING
end
```

## Index Types

```ruby
# HNSW (default for vector search)
Zvec::Ext::HnswIndexParams.new(Zvec::COSINE, m: 16, ef_construction: 200)

# Flat (brute-force, exact)
Zvec::Ext::FlatIndexParams.new(Zvec::L2)

# IVF (inverted file index)
Zvec::Ext::IVFIndexParams.new(Zvec::IP, n_list: 1024)

# Inverted index (for scalar fields)
Zvec::Ext::InvertIndexParams.new
```

## Collection API

```ruby
# CRUD
collection.add(pk: "id", title: "text", embedding: [...])
collection.upsert(doc)
collection.delete("id1", "id2")
collection.fetch("id1")

# Search
collection.search(vector, top_k: 10, filter: "year > 2024")

# Full query control
collection.query(
  field_name: "embedding",
  vector: [...],
  topk: 10,
  filter: "category='tech'",
  include_vector: true,
  output_fields: ["title", "url"]
)

# Management
collection.flush
collection.optimize
collection.doc_count
collection.destroy
```

## ruby_llm Integration

```ruby
require "zvec/ruby_llm"

store = Zvec::RubyLLM::Store.new("/tmp/vectors", dimension: 1536, metric: :cosine)

store.add("doc-1", embedding: [...], content: "Some text")
store.search(query_embedding, top_k: 5)
```

## ActiveRecord Integration

```ruby
require "zvec/active_record"

class Article < ApplicationRecord
  include Zvec::ActiveRecord::Vectorize

  vectorize :content,
    dimensions: 1536,
    embed_with: ->(text) { MyEmbedder.embed(text) }
end

# Automatic embedding on save
article = Article.create!(title: "Hello", content: "World")

# Vector similarity search
Article.vector_search("similar articles", top_k: 5)
Article.vector_search([0.1, 0.2, ...], top_k: 10, embed: false)
```

## Development

```bash
# Build zvec
./script/build_zvec.sh

# Compile and test
ZVEC_DIR=/tmp/zvec bundle exec rake compile
ZVEC_DIR=/tmp/zvec bundle exec rake test

# Run pure Ruby tests only (no native extension needed)
bundle exec rake test_pure

# Package a native gem for your platform
ruby script/package_native_gem.rb
```

## License

Apache-2.0 (same as zvec)
