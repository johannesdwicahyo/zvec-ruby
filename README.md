# zvec-ruby

Ruby bindings for [zvec](https://github.com/alibaba/zvec), a high-performance C++ vector database from Alibaba. Built with [Rice](https://github.com/jasonroelofs/rice) (Ruby's C++ binding library).

## Prerequisites

1. **Build and install zvec** from source:
   ```bash
   git clone https://github.com/alibaba/zvec
   cd zvec && mkdir build && cd build
   cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
   make -j$(nproc) && sudo make install
   ```

2. **Install Rice**: `gem install rice`

## Installation

```ruby
# Gemfile
gem "zvec"
```

If zvec is installed in a non-standard location:
```bash
ZVEC_DIR=/path/to/zvec gem install zvec
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
  filter: "category == 'tech'",
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

## License

Apache-2.0 (same as zvec)
