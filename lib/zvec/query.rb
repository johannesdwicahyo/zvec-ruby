module Zvec
  # Represents a vector similarity search query.
  #
  # == Filter Expression Syntax
  #
  # Filters narrow search results using scalar field conditions. The syntax
  # supports the following operators and combinators:
  #
  # === Comparison Operators
  #
  #   field == value       # equality
  #   field != value       # inequality
  #   field > value        # greater than
  #   field >= value       # greater than or equal
  #   field < value        # less than
  #   field <= value       # less than or equal
  #
  # === Logical Operators
  #
  #   expr AND expr        # both conditions must match
  #   expr OR expr         # either condition matches
  #   NOT expr             # negation
  #   (expr)               # grouping
  #
  # === Set / Range Operators
  #
  #   field IN [v1, v2]    # field equals any value in the list
  #   field NOT IN [v1]    # field does not equal any value in the list
  #
  # === String Operators
  #
  #   field LIKE "pattern" # SQL-style LIKE with % and _ wildcards
  #
  # === Examples
  #
  #   "year > 2024"
  #   "year >= 2020 AND year <= 2025"
  #   "category IN ['science', 'tech']"
  #   "title LIKE '%Ruby%'"
  #   "active == true AND rating > 4.0"
  #   "(year > 2020 OR featured == true) AND active == true"
  #
  # @example Basic query
  #   query = Zvec::VectorQuery.new(
  #     field_name: "embedding",
  #     vector: [0.1, 0.2, 0.3, 0.4],
  #     topk: 10
  #   )
  #
  # @example Query with filter
  #   query = Zvec::VectorQuery.new(
  #     field_name: "embedding",
  #     vector: [0.1, 0.2, 0.3, 0.4],
  #     topk: 5,
  #     filter: "year > 2024 AND category == 'science'"
  #   )
  #
  # @example Query with HNSW search params
  #   query = Zvec::VectorQuery.new(
  #     field_name: "embedding",
  #     vector: [0.1, 0.2, 0.3, 0.4],
  #     topk: 10,
  #     query_params: Zvec::Ext::HnswQueryParams.new(ef: 300)
  #   )
  #
  class VectorQuery
    # @return [Ext::VectorQuery] the underlying C++ query object
    attr_reader :ext_query

    # Create a new vector similarity query.
    #
    # @param field_name [String, Symbol] the vector field to search
    #   (must be non-empty)
    # @param vector [Array<Numeric>] the query vector (must be non-empty,
    #   all elements must be Numeric)
    # @param topk [Integer] number of nearest results to return (must be > 0)
    # @param filter [String, nil] optional filter expression
    #   (see class-level docs for syntax)
    # @param include_vector [Boolean] whether to include the stored vectors
    #   in results
    # @param output_fields [Array<String>, nil] specific fields to return
    #   (nil returns all)
    # @param query_params [Ext::HnswQueryParams, Ext::IVFQueryParams,
    #   Ext::FlatQueryParams, nil] optional search-time tuning params
    # @return [VectorQuery]
    # @raise [Zvec::QueryError] if field_name, vector, or topk are invalid
    #
    # @example
    #   vq = Zvec::VectorQuery.new(
    #     field_name: "embedding",
    #     vector: [0.1, 0.2, 0.3],
    #     topk: 5,
    #     filter: "year > 2024",
    #     output_fields: ["title", "year"]
    #   )
    def initialize(field_name:, vector:, topk: 10, filter: nil,
                   include_vector: false, output_fields: nil, query_params: nil)
      if field_name.nil? || field_name.to_s.strip.empty?
        raise QueryError, "field_name must be a non-empty string"
      end
      unless vector.is_a?(Array) && !vector.empty?
        raise QueryError, "vector must be a non-empty Array"
      end
      unless topk.is_a?(Integer) && topk > 0
        raise QueryError, "topk must be a positive integer"
      end

      # Validate all vector elements are numeric
      vector.each_with_index do |v, i|
        unless v.is_a?(Numeric)
          raise QueryError,
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
          raise QueryError, "Unknown query_params type: #{query_params.class}"
        end
      end
    end
  end
end
