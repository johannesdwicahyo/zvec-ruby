module Zvec
  class VectorQuery
    attr_reader :ext_query

    def initialize(field_name:, vector:, topk: 10, filter: nil,
                   include_vector: false, output_fields: nil, query_params: nil)
      @ext_query = Ext::VectorQuery.new
      @ext_query.field_name = field_name.to_s
      @ext_query.topk = topk
      @ext_query.set_query_vector(vector.map(&:to_f))
      @ext_query.filter = filter if filter
      @ext_query.include_vector = include_vector
      @ext_query.set_output_fields(output_fields.map(&:to_s)) if output_fields
      @ext_query.set_query_params(query_params) if query_params
    end
  end
end
