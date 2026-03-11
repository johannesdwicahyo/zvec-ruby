module Zvec
  # Defines the structure of a collection: its name, fields, types, and
  # vector dimensions.
  #
  # Schemas are immutable once created -- fields can be added during
  # initialization but not removed afterward.
  #
  # @example Creating a schema with a DSL block
  #   schema = Zvec::Schema.new("articles") do
  #     string "title"
  #     string "body", nullable: true
  #     int32  "year"
  #     float  "rating"
  #     bool   "published"
  #     vector "embedding", dimension: 384,
  #            index: Zvec::Ext::HnswIndexParams.new(Zvec::COSINE)
  #   end
  #
  # @example Binary vector field
  #   schema = Zvec::Schema.new("hashes") do
  #     field "hash_vec", DataTypes::BINARY, dimension: 128
  #   end
  #
  # @example Sparse vector field
  #   schema = Zvec::Schema.new("sparse_docs") do
  #     field "tfidf", DataTypes::SPARSE_VECTOR_FP32, dimension: 30000
  #   end
  #
  class Schema
    # @return [Ext::CollectionSchema] the underlying C++ schema object
    attr_reader :ext_schema

    # Create a new schema.
    #
    # @param name [String, Symbol] the collection name (must be non-empty)
    # @yield optional DSL block evaluated in the schema's context
    # @raise [Zvec::SchemaError] if name is nil or blank
    #
    # @example
    #   schema = Zvec::Schema.new("my_collection") do
    #     string "title"
    #     vector "embedding", dimension: 128
    #   end
    def initialize(name, &block)
      if name.nil? || name.to_s.strip.empty?
        raise SchemaError, "Schema name must be a non-empty string"
      end

      @ext_schema = Ext::CollectionSchema.new(name.to_s)
      @field_types = {}
      @field_dimensions = {}
      instance_eval(&block) if block
    end

    # Add a field with an explicit data type.
    #
    # @param name [String, Symbol] the field name (must be non-empty)
    # @param type [Symbol] a DataTypes constant (e.g., +DataTypes::STRING+)
    # @param dimension [Integer, nil] required for vector fields
    # @param nullable [Boolean] whether the field allows null values
    # @param index [Ext::HnswIndexParams, Ext::FlatIndexParams, Ext::IVFIndexParams, nil]
    #   optional index parameters for this field
    # @return [self] for method chaining
    # @raise [Zvec::SchemaError] if field name is blank
    #
    # @example
    #   schema.field("tags", DataTypes::ARRAY_STRING)
    #   schema.field("embedding", DataTypes::VECTOR_FP32, dimension: 128)
    def field(name, type, dimension: nil, nullable: false, index: nil)
      name = name.to_s
      if name.strip.empty?
        raise SchemaError, "Field name must be a non-empty string"
      end

      fs = Ext::FieldSchema.new(name, type)
      fs.dimension = dimension if dimension
      fs.nullable = nullable
      fs.set_index_params(index) if index
      @ext_schema.add_field(fs)
      @field_types[name] = type
      @field_dimensions[name] = dimension if dimension
      self
    end

    # Add a dense vector field. Defaults to FP32 precision.
    #
    # @param name [String, Symbol] the field name
    # @param dimension [Integer] the vector dimension (must be > 0)
    # @param type [Symbol] vector data type (default: {DataTypes::VECTOR_FP32}).
    #   Also accepts {DataTypes::VECTOR_FP64}, {DataTypes::VECTOR_FP16},
    #   or {DataTypes::VECTOR_INT8}.
    # @param index [Ext::HnswIndexParams, Ext::FlatIndexParams, Ext::IVFIndexParams, nil]
    #   optional index parameters
    # @return [self]
    # @raise [ArgumentError] if dimension is not a positive integer
    #
    # @example Standard FP32 vector with HNSW index
    #   schema.vector "embedding", dimension: 384,
    #                 index: Ext::HnswIndexParams.new(Zvec::COSINE)
    #
    # @example FP16 vector (half memory)
    #   schema.vector "embedding", dimension: 384,
    #                 type: DataTypes::VECTOR_FP16
    #
    # @example INT8 quantized vector (minimal memory)
    #   schema.vector "embedding", dimension: 384,
    #                 type: DataTypes::VECTOR_INT8
    def vector(name, dimension:, type: DataTypes::VECTOR_FP32, index: nil)
      raise ArgumentError, "Vector dimension must be a positive integer, got #{dimension.inspect}" unless dimension.is_a?(Integer) && dimension > 0

      field(name, type, dimension: dimension, index: index)
    end

    # Add a string field.
    #
    # @param name [String, Symbol] the field name
    # @param opts [Hash] options passed to {#field} (+nullable:+, +index:+)
    # @return [self]
    def string(name, **opts)
      field(name, DataTypes::STRING, **opts)
    end

    # Add a 32-bit integer field.
    #
    # @param name [String, Symbol] the field name
    # @param opts [Hash] options passed to {#field}
    # @return [self]
    def int32(name, **opts)
      field(name, DataTypes::INT32, **opts)
    end

    # Add a 64-bit integer field.
    #
    # @param name [String, Symbol] the field name
    # @param opts [Hash] options passed to {#field}
    # @return [self]
    def int64(name, **opts)
      field(name, DataTypes::INT64, **opts)
    end

    # Add a 32-bit float field.
    #
    # @param name [String, Symbol] the field name
    # @param opts [Hash] options passed to {#field}
    # @return [self]
    def float(name, **opts)
      field(name, DataTypes::FLOAT, **opts)
    end

    # Add a 64-bit double field.
    #
    # @param name [String, Symbol] the field name
    # @param opts [Hash] options passed to {#field}
    # @return [self]
    def double(name, **opts)
      field(name, DataTypes::DOUBLE, **opts)
    end

    # Add a boolean field.
    #
    # @param name [String, Symbol] the field name
    # @param opts [Hash] options passed to {#field}
    # @return [self]
    def bool(name, **opts)
      field(name, DataTypes::BOOL, **opts)
    end

    # @return [String] the collection name
    def name
      @ext_schema.name
    end

    # @return [Array<String>] all field names in this schema
    def field_names
      @ext_schema.field_names
    end

    # Look up the data type of a field by name.
    #
    # @param name [String, Symbol] the field name
    # @return [Symbol, nil] the data type constant, or nil if not found
    def field_type(name)
      @field_types[name.to_s]
    end

    # Look up the dimension of a vector field.
    #
    # @param name [String, Symbol] the field name
    # @return [Integer, nil] the dimension, or nil if the field is not a vector
    def field_dimension(name)
      @field_dimensions[name.to_s]
    end

    # Check whether a field exists in the schema.
    #
    # @param name [String, Symbol] the field name
    # @return [Boolean]
    def has_field?(name)
      @ext_schema.has_field?(name.to_s)
    end

    # Returns a hash of vector field names to their dimensions.
    #
    # @return [Hash{String => Integer}] e.g. +{"embedding" => 384}+
    def vector_fields_with_dimensions
      @field_dimensions.select { |name, _| DataTypes::VECTOR_TYPES.include?(@field_types[name]) }
    end

    # @return [String] human-readable representation of the schema
    def to_s
      @ext_schema.to_s
    end
  end
end
