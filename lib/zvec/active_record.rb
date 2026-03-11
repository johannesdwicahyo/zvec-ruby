require "zvec"
require "active_support/concern"

module Zvec
  module ActiveRecord
    # Rails concern that adds vector search capabilities to ActiveRecord models.
    #
    # When included in a model, call +vectorize+ to configure which text field
    # to embed, the vector dimension, and the embedding function.
    #
    # @example Basic usage
    #   class Article < ApplicationRecord
    #     include Zvec::ActiveRecord::Vectorize
    #
    #     vectorize :content,
    #       dimensions: 1536,
    #       prefix: "articles",
    #       embed_with: ->(text) { OpenAI.embed(text) }
    #   end
    #
    # @example Searching
    #   Article.vector_search("Ruby programming", top_k: 5)
    #   Article.vector_search([0.1, 0.2, ...], top_k: 5, embed: false)
    #
    # @example Instance methods
    #   article.zvec_update_embedding!   # re-embed and store
    #   article.zvec_remove_embedding!   # remove from vector store
    #   article.zvec_embedding           # fetch stored embedding doc
    #
    module Vectorize
      extend ActiveSupport::Concern

      class_methods do
        # Configure vector search for this model.
        #
        # @param field [String, Symbol] the text field to embed
        # @param dimensions [Integer] the vector dimension
        # @param prefix [String, nil] collection prefix (defaults to table_name)
        # @param embed_with [Proc, nil] a callable that takes text and returns
        #   a vector Array (e.g., +-> (text) { OpenAI.embed(text) }+)
        # @param metric [Symbol] similarity metric (+:cosine+, +:l2+, or +:ip+)
        # @param zvec_path [String, nil] path for the zvec collection
        #   (defaults to +tmp/zvec/<prefix>+)
        # @return [void]
        def vectorize(field, dimensions:, prefix: nil, embed_with: nil,
                      metric: :cosine, zvec_path: nil)
          prefix ||= table_name
          zvec_path ||= Rails.root.join("tmp", "zvec", prefix).to_s if defined?(Rails)
          zvec_path ||= File.join("tmp", "zvec", prefix)

          class_attribute :zvec_config, instance_writer: false
          self.zvec_config = {
            field: field.to_s,
            dimensions: dimensions,
            prefix: prefix,
            embed_with: embed_with,
            metric: metric,
            zvec_path: zvec_path
          }

          after_save :zvec_update_embedding!, if: -> { saved_change_to_attribute?(zvec_config[:field]) }
          after_destroy :zvec_remove_embedding!

          include InstanceMethods
          extend SearchMethods
        end
      end

      # Instance methods mixed into the model.
      module InstanceMethods
        # Re-embed the configured text field and store the embedding.
        #
        # @return [void]
        # @raise [Zvec::Error] if no +embed_with+ function is configured
        def zvec_update_embedding!
          cfg = self.class.zvec_config
          text = send(cfg[:field])
          return if text.blank?

          embed_fn = cfg[:embed_with]
          raise Zvec::Error, "No embed_with function configured" unless embed_fn

          embedding = embed_fn.call(text)
          store = self.class.zvec_store
          store.add(id.to_s, embedding: embedding, content: text)
          store.flush
        end

        # Remove this record's embedding from the vector store.
        #
        # @return [void]
        def zvec_remove_embedding!
          self.class.zvec_store.delete(id.to_s)
        rescue
          # Silently ignore if document doesn't exist
        end

        # Fetch this record's stored embedding document.
        #
        # @return [Zvec::Doc, nil] the stored document, or nil if not found
        def zvec_embedding
          result = self.class.zvec_store.fetch(id.to_s)
          result[id.to_s]
        end
      end

      # Class methods mixed into the model.
      module SearchMethods
        # Access the shared {Zvec::RubyLLM::Store} instance for this model.
        #
        # @return [Zvec::RubyLLM::Store]
        def zvec_store
          @zvec_store ||= begin
            cfg = zvec_config
            Zvec::RubyLLM::Store.new(
              cfg[:zvec_path],
              dimension: cfg[:dimensions],
              metric: cfg[:metric]
            )
          end
        end

        # Search for records by vector similarity.
        #
        # When +query+ is a String and +embed+ is true, the configured
        # +embed_with+ function is called to convert it to a vector first.
        #
        # @param query [Array<Numeric>, String] query vector or text to embed
        # @param top_k [Integer] maximum number of results (default: 10)
        # @param embed [Boolean] whether to embed a String query (default: true)
        # @return [Array<ActiveRecord::Base>] matching records, each with a
        #   +zvec_score+ singleton method returning the similarity score
        # @raise [ArgumentError] if query is a String but no +embed_with+ is
        #   configured
        def vector_search(query, top_k: 10, embed: true)
          cfg = zvec_config

          query_vector = if embed && query.is_a?(String) && cfg[:embed_with]
                           cfg[:embed_with].call(query)
                         elsif query.is_a?(Array)
                           query
                         else
                           raise ArgumentError, "query must be a vector Array or a String with embed_with configured"
                         end

          results = zvec_store.search(query_vector, top_k: top_k)
          ids = results.map { |r| r[:id] }
          records = where(id: ids).index_by { |r| r.id.to_s }

          results.filter_map do |r|
            record = records[r[:id]]
            next unless record
            record.define_singleton_method(:zvec_score) { r[:score] }
            record
          end
        end
      end
    end
  end
end
