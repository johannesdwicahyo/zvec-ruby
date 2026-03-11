module Zvec
  # A document (row) in a zvec collection. Wraps the C++ Doc object and
  # provides Ruby-friendly field access with automatic type coercion.
  #
  # Documents can be created with or without a schema. With a schema,
  # values are coerced and validated against declared field types and
  # vector dimensions. Without a schema, types are auto-detected.
  #
  # @example Creating a document with a schema
  #   doc = Zvec::Doc.new(pk: "doc-1", schema: schema)
  #   doc["title"] = "Hello World"
  #   doc["embedding"] = [0.1, 0.2, 0.3, 0.4]
  #
  # @example Schema-less document (types auto-detected)
  #   doc = Zvec::Doc.new(pk: "doc-2")
  #   doc["name"] = "Alice"       # stored as string
  #   doc["age"] = 30             # stored as int64
  #   doc["score"] = 0.95         # stored as double
  #   doc["active"] = true        # stored as bool
  #   doc["vec"] = [1.0, 2.0]     # stored as float vector
  #   doc["tags"] = ["a", "b"]    # stored as string array
  #
  class Doc
    # @return [Ext::Doc] the underlying C++ document object
    attr_reader :ext_doc

    # Create a new document.
    #
    # @param pk [String, Integer, nil] primary key (converted to String)
    # @param fields [Hash{String, Symbol => Object}] initial field values
    # @param schema [Zvec::Schema, nil] optional schema for type validation
    #
    # @example
    #   doc = Zvec::Doc.new(pk: "abc", fields: { "title" => "Hello" }, schema: schema)
    def initialize(pk: nil, fields: {}, schema: nil)
      @ext_doc = Ext::Doc.new
      @ext_doc.pk = pk.to_s if pk
      @schema = schema
      fields.each { |k, v| set(k, v) } if schema
    end

    # @return [String] the primary key
    def pk
      @ext_doc.pk
    end

    # Set the primary key.
    #
    # @param value [String, Integer] the new primary key (converted to String)
    # @return [void]
    def pk=(value)
      @ext_doc.pk = value.to_s
    end

    # @return [Float] the similarity score (set after search queries)
    def score
      @score || @ext_doc.score
    end

    # Read a field value by name (bracket accessor).
    #
    # @param field_name [String, Symbol] the field name
    # @return [Object, nil] the field value, or nil if not set
    #
    # @example
    #   doc["title"]  #=> "Hello"
    def [](field_name)
      get(field_name)
    end

    # Write a field value by name (bracket accessor).
    #
    # @param field_name [String, Symbol] the field name
    # @param value [Object] the value to set
    # @return [void]
    #
    # @example
    #   doc["title"] = "Hello"
    def []=(field_name, value)
      set(field_name, value)
    end

    # Set a field value. When a schema is present, the value is coerced to
    # the declared type and validated. Without a schema, the type is
    # auto-detected from the Ruby value.
    #
    # @param field_name [String, Symbol] the field name (must be non-empty)
    # @param value [Object] the value to set (nil sets the field to null)
    # @return [void]
    # @raise [ArgumentError] if field_name is blank or value type is unsupported
    # @raise [Zvec::DimensionError] if vector dimension doesn't match schema
    #
    # @example
    #   doc.set("title", "Hello")
    #   doc.set(:count, 42)
    #   doc.set("embedding", [0.1, 0.2, 0.3])
    def set(field_name, value)
      field_name = field_name.to_s
      raise ArgumentError, "Field name must be a non-empty string" if field_name.strip.empty?

      return @ext_doc.set_null(field_name) if value.nil?

      if @schema
        type = @schema.field_type(field_name)
        if type
          coerced = DataTypes.coerce_value(value, type, field_name: field_name)
          setter = DataTypes::SETTER_FOR[type]
          if setter
            # Validate vector dimension if schema has dimension info
            if DataTypes::VECTOR_TYPES.include?(type) && coerced.is_a?(Array)
              expected_dim = @schema.field_dimension(field_name)
              if expected_dim && !coerced.empty? && coerced.size != expected_dim
                raise DimensionError,
                  "Vector dimension mismatch for field '#{field_name}': " \
                  "expected #{expected_dim}, got #{coerced.size}"
              end
            end
            return @ext_doc.send(setter, field_name, coerced)
          end
        end
      end

      # Auto-detect type (schema-less mode)
      case value
      when String                then @ext_doc.set_string(field_name, value)
      when Integer               then @ext_doc.set_int64(field_name, value)
      when Float                 then @ext_doc.set_double(field_name, value)
      when TrueClass, FalseClass then @ext_doc.set_bool(field_name, value)
      when Array
        detected = DataTypes.detect_type(value)
        case detected
        when Ext::DataType::ARRAY_STRING
          @ext_doc.set_string_array(field_name, value.map { |v| v.nil? ? "" : v.to_s })
        else
          # Default: treat as float vector
          coerced = value.map { |v| v.nil? ? 0.0 : v.to_f }
          @ext_doc.set_float_vector(field_name, coerced)
        end
      else
        raise ArgumentError,
          "Unsupported value type #{value.class} for field '#{field_name}'"
      end
    end

    # Get a field value by name. Uses the schema getter if available,
    # otherwise tries common types in order.
    #
    # @param field_name [String, Symbol] the field name
    # @return [Object, nil] the value, or nil if not found or null
    #
    # @example
    #   doc.get("title")      #=> "Hello"
    #   doc.get(:embedding)   #=> [0.1, 0.2, 0.3]
    #   doc.get("missing")    #=> nil
    def get(field_name)
      field_name = field_name.to_s
      return nil unless @ext_doc.has?(field_name)
      return nil unless @ext_doc.has_value?(field_name)

      if @schema
        type = @schema.field_type(field_name)
        if type
          getter = DataTypes::GETTER_FOR[type]
          return @ext_doc.send(getter, field_name) if getter
        end
      end

      # Try common types in order
      %i[get_string get_int64 get_float get_double get_bool
         get_float_vector get_string_array].each do |m|
        val = @ext_doc.send(m, field_name)
        return val unless val.nil?
      end
      nil
    end

    # @return [Array<String>] names of all fields set on this document
    def field_names
      @ext_doc.field_names
    end

    # @return [Boolean] true if no fields have been set
    def empty?
      @ext_doc.empty?
    end

    # Convert the document to a plain Ruby Hash.
    #
    # @return [Hash{String => Object}] includes "pk", "score", and all fields
    #
    # @example
    #   doc.to_h  #=> {"pk" => "doc-1", "score" => 0.95, "title" => "Hello"}
    def to_h
      h = { "pk" => pk, "score" => score }
      field_names.each { |f| h[f] = get(f) }
      h
    end

    # @return [String] human-readable representation
    def to_s
      @ext_doc.to_s
    end

    # Wrap a C++ Doc::Ptr into a Ruby Doc.
    #
    # @param ext_doc [Ext::Doc] the C++ document to wrap
    # @param schema [Zvec::Schema, nil] optional schema for type-aware access
    # @return [Zvec::Doc]
    def self.from_ext(ext_doc, schema: nil)
      doc = allocate
      doc.instance_variable_set(:@ext_doc, ext_doc)
      doc.instance_variable_set(:@schema, schema)
      doc
    end
  end
end
