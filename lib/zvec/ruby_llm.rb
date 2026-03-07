require "zvec"

module Zvec
  module RubyLLM
    # A vector store backend for the ruby_llm gem.
    #
    # Usage with ruby_llm:
    #   store = Zvec::RubyLLM::Store.new("/path/to/db", dimension: 1536)
    #   store.add("doc-1", embedding: [...], metadata: { title: "Hello" })
    #   results = store.search([0.1, 0.2, ...], top_k: 5)
    #
    class Store
      DEFAULT_VECTOR_FIELD = "embedding"
      DEFAULT_CONTENT_FIELD = "content"

      attr_reader :collection, :dimension

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
      def add(id, embedding:, content: nil, metadata: {})
        doc = Zvec::Doc.new(pk: id, schema: @schema)
        doc[@vector_field] = embedding
        doc[@content_field] = content if content
        metadata.each { |k, v| doc[k] = v }
        @collection.insert(doc)
      end

      # Batch-add documents.
      # docs: array of { id:, embedding:, content:, metadata: {} }
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

      # Delete documents by IDs.
      def delete(*ids)
        @collection.delete(*ids.flatten)
      end

      # Fetch documents by IDs.
      def fetch(*ids)
        @collection.fetch(*ids.flatten)
      end

      def flush
        @collection.flush
      end

      def count
        @collection.doc_count
      end
    end
  end
end
