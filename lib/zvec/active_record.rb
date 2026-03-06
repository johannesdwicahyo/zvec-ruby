require "zvec"
require "active_support/concern"

module Zvec
  module ActiveRecord
    # Rails concern that adds vector search capabilities to ActiveRecord models.
    #
    # Usage:
    #   class Article < ApplicationRecord
    #     include Zvec::ActiveRecord::Vectorize
    #
    #     vectorize :content,
    #       dimensions: 1536,
    #       prefix: "articles",
    #       embed_with: ->(text) { OpenAI.embed(text) }
    #   end
    #
    #   Article.vector_search([0.1, 0.2, ...], top_k: 5)
    #   article.update_embedding!
    #
    module Vectorize
      extend ActiveSupport::Concern

      class_methods do
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

      module InstanceMethods
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

        def zvec_remove_embedding!
          self.class.zvec_store.delete(id.to_s)
        rescue => e
          # Silently ignore if document doesn't exist
        end

        def zvec_embedding
          result = self.class.zvec_store.fetch(id.to_s)
          result[id.to_s]
        end
      end

      module SearchMethods
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
