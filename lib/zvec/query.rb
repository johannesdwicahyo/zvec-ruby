module Zvec
  class VectorQuery
    attr_reader :ext_query

    def initialize(field_name:, vector:, topk: 10, filter: nil,
                   include_vector: false, output_fields: nil, query_params: nil)
      raise ArgumentError, "field_name must be a non-empty string" if field_name.nil? || field_name.to_s.strip.empty?
      raise ArgumentError, "vector must be a non-empty Array" unless vector.is_a?(Array) && !vector.empty?
      raise ArgumentError, "topk must be a positive integer" unless topk.is_a?(Integer) && topk > 0

      # Validate all vector elements are numeric
      vector.each_with_index do |v, i|
        unless v.is_a?(Numeric)
          raise ArgumentError,
            "Query vector contains non-numeric element at index #{i}: #{v.inspect}"
        end
      end

      @ext_query = Ext::VectorQuery.new
      @ext_query.field_name = field_name.to_s
      @ext_query.topk = topk
      @ext_query.set_query_vector(vector.map(&:to_f))
      @ext_query.filter = filter if filter
      @ext_query.include_vector = include_vector
      @ext_query.set_output_fields(output_fields.map(&:to_s)) if output_fields
      if query_params
        case query_params
        when Ext::HnswQueryParams
          @ext_query.set_hnsw_query_params(query_params)
        when Ext::IVFQueryParams
          @ext_query.set_ivf_query_params(query_params)
        when Ext::FlatQueryParams
          @ext_query.set_flat_query_params(query_params)
        else
          raise ArgumentError, "Unknown query_params type: #{query_params.class}"
        end
      end
    end
  end
end
