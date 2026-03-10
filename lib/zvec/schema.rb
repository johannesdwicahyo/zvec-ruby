module Zvec
  class Schema
    attr_reader :ext_schema

    def initialize(name, &block)
      raise ArgumentError, "Schema name must be a non-empty string" if name.nil? || name.to_s.strip.empty?

      @ext_schema = Ext::CollectionSchema.new(name.to_s)
      @field_types = {}
      @field_dimensions = {}
      instance_eval(&block) if block
    end

    def field(name, type, dimension: nil, nullable: false, index: nil)
      name = name.to_s
      raise ArgumentError, "Field name must be a non-empty string" if name.strip.empty?

      fs = Ext::FieldSchema.new(name, type)
      fs.dimension = dimension if dimension
      fs.nullable = nullable
      fs.set_index_params(index) if index
      @ext_schema.add_field(fs)
      @field_types[name] = type
      @field_dimensions[name] = dimension if dimension
      self
    end

    def vector(name, dimension:, type: DataTypes::VECTOR_FP32, index: nil)
      raise ArgumentError, "Vector dimension must be a positive integer, got #{dimension.inspect}" unless dimension.is_a?(Integer) && dimension > 0

      field(name, type, dimension: dimension, index: index)
    end

    def string(name, **opts)
      field(name, DataTypes::STRING, **opts)
    end

    def int32(name, **opts)
      field(name, DataTypes::INT32, **opts)
    end

    def int64(name, **opts)
      field(name, DataTypes::INT64, **opts)
    end

    def float(name, **opts)
      field(name, DataTypes::FLOAT, **opts)
    end

    def double(name, **opts)
      field(name, DataTypes::DOUBLE, **opts)
    end

    def bool(name, **opts)
      field(name, DataTypes::BOOL, **opts)
    end

    def name
      @ext_schema.name
    end

    def field_names
      @ext_schema.field_names
    end

    def field_type(name)
      @field_types[name.to_s]
    end

    def field_dimension(name)
      @field_dimensions[name.to_s]
    end

    def has_field?(name)
      @ext_schema.has_field?(name.to_s)
    end

    # Returns an array of [field_name, dimension] for all vector fields.
    def vector_fields_with_dimensions
      @field_dimensions.select { |name, _| DataTypes::VECTOR_TYPES.include?(@field_types[name]) }
    end

    def to_s
      @ext_schema.to_s
    end
  end
end
