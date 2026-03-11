require "zvec"

module Zvec
  module RubyLLM
    # A vector store backend for the ruby_llm gem.
    #
    # Provides a simple add/search/delete interface on top of a {Zvec::Collection}.
    # Compatible with the ruby_llm vector store protocol.
    #
    # @example Basic usage
    #   store = Zvec::RubyLLM::Store.new("/path/to/db", dimension: 1536)
    #   store.add("doc-1", embedding: [...], content: "Hello world")
    #   results = store.search([0.1, 0.2, ...], top_k: 5)
    #   results.first  #=> { id: "doc-1", score: 0.98, content: "Hello world", metadata: {} }
    #
    # @example With metadata
    #   store.add("doc-2", embedding: [...], content: "Ruby", metadata: { category: "lang" })
    #
    class Store
      # @return [String] default vector field name
      DEFAULT_VECTOR_FIELD = "embedding"
      # @return [String] default content field name
      DEFAULT_CONTENT_FIELD = "content"

      # @return [Zvec::Collection] the underlying collection
      attr_reader :collection
      # @return [Integer] the vector dimension
      attr_reader :dimension

      # Create a new store, opening an existing collection or creating one.
      #
      # @param path [String] directory path for the collection data
      # @param dimension [Integer] the vector dimension (must be > 0)
      # @param metric [Symbol] similarity metric (+:cosine+, +:l2+, or +:ip+)
      # @param vector_field [String] name of the vector field (default: "embedding")
      # @param content_field [String] name of the content field (default: "content")
      # @raise [ArgumentError] if metric is not one of +:cosine+, +:l2+, +:ip+
      #
      # @example
      #   store = Zvec::RubyLLM::Store.new("/tmp/store", dimension: 384, metric: :l2)
      def initialize(path, dimension:, metric: :cosine, vector_field: DEFAULT_VECTOR_FIELD,
                     content_field: DEFAULT_CONTENT_FIELD)
        @vector_field = vector_field.to_s
        @content_field = content_field.to_s
        @dimension = dimension

        metric_type = case metric.to_sym
                      when :cosine then Zvec::DataTypes::COSINE
                      when :l2     then Zvec::DataTypes::L2
                      when :ip     then Zvec::DataTypes::IP
                      else raise ArgumentError, "Unknown metric: #{metric}"
                      end

        cf = @content_field
        vf = @vector_field
        dim = dimension
        schema = Zvec::Schema.new("ruby_llm_store") do
          string cf, nullable: true
          vector vf, dimension: dim,
                 index: Zvec::Ext::HnswIndexParams.new(metric_type)
        end

        @schema = schema

        if Dir.exist?(path)
          @collection = Zvec::Collection.open(path)
        else
          @collection = Zvec::Collection.create_and_open(path, schema)
        end
      end

      # Add a document with its embedding and optional metadata.
      #
      # @param id [String, Integer] the document's primary key
      # @param embedding [Array<Numeric>] the vector embedding
      # @param content [String, nil] optional text content
      # @param metadata [Hash{String, Symbol => Object}] additional fields to store
      # @return [Array] write results from the collection
      #
      # @example
      #   store.add("doc-1", embedding: [0.1, 0.2, 0.3], content: "Hello")
      def add(id, embedding:, content: nil, metadata: {})
        doc = Zvec::Doc.new(pk: id, schema: @schema)
        doc[@vector_field] = embedding
        doc[@content_field] = content if content
        metadata.each { |k, v| doc[k] = v }
        @collection.insert(doc)
      end

      # Batch-add multiple documents at once.
      #
      # @param docs [Array<Hash>] documents, each containing:
      #   * +:id+ [String, Integer] -- primary key (required)
      #   * +:embedding+ [Array<Numeric>] -- the vector (required)
      #   * +:content+ [String, nil] -- optional text content
      #   * +:metadata+ [Hash, nil] -- optional additional fields
      # @return [Array] write results from the collection
      #
      # @example
      #   store.add_many([
      #     { id: "a", embedding: [0.1, 0.2], content: "Hello" },
      #     { id: "b", embedding: [0.3, 0.4], content: "World" },
      #   ])
      def add_many(docs)
        zvec_docs = docs.map do |d|
          doc = Zvec::Doc.new(pk: d[:id], schema: @schema)
          doc[@vector_field] = d[:embedding]
          doc[@content_field] = d[:content] if d[:content]
          (d[:metadata] || {}).each { |k, v| doc[k] = v }
          doc
        end
        @collection.insert(zvec_docs)
      end

      # Search for similar vectors.
      #
      # @param query_vector [Array<Numeric>] the query vector
      # @param top_k [Integer] maximum number of results (default: 10)
      # @param filter [String, nil] optional filter expression
      #   (see {Zvec::VectorQuery} for filter syntax)
      # @return [Array<Hash>] results, each containing:
      #   * +:id+ [String] -- document primary key
      #   * +:score+ [Float] -- similarity score
      #   * +:content+ [String, nil] -- the content field value
      #   * +:metadata+ [Hash] -- all other stored fields
      #
      # @example
      #   results = store.search([0.1, 0.2, 0.3], top_k: 5)
      #   results.first[:id]      #=> "doc-1"
      #   results.first[:score]   #=> 0.95
      #   results.first[:content] #=> "Hello"
      def search(query_vector, top_k: 10, filter: nil)
        results = @collection.query(
          field_name: @vector_field,
          vector: query_vector,
          topk: top_k,
          filter: filter
        )
        results.map do |doc|
          {
            id: doc.pk,
            score: doc.score,
            content: doc[@content_field],
            metadata: doc.to_h.reject { |k, _| ["pk", "score", @vector_field, @content_field].include?(k) }
          }
        end
      end

      # Delete documents by primary key(s).
      #
      # @param ids [Array<String, Integer>] one or more primary keys
      # @return [Array] write results from the collection
      def delete(*ids)
        @collection.delete(*ids.flatten)
      end

      # Fetch documents by primary key(s).
      #
      # @param ids [Array<String, Integer>] one or more primary keys
      # @return [Hash{String => Zvec::Doc}] mapping of pk to document
      def fetch(*ids)
        @collection.fetch(*ids.flatten)
      end

      # Flush pending writes to disk.
      #
      # @return [self]
      def flush
        @collection.flush
      end

      # Return the number of documents in the store.
      #
      # @return [Integer]
      def count
        @collection.doc_count
      end
    end
  end
end
