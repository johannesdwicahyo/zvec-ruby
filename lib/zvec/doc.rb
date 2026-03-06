module Zvec
  class Doc
    attr_reader :ext_doc

    def initialize(pk: nil, fields: {}, schema: nil)
      @ext_doc = Ext::Doc.new
      @ext_doc.pk = pk.to_s if pk
      @schema = schema
      fields.each { |k, v| set(k, v) } if schema
    end

    def pk
      @ext_doc.pk
    end

    def pk=(value)
      @ext_doc.pk = value.to_s
    end

    def score
      @ext_doc.score
    end

    def [](field_name)
      get(field_name)
    end

    def []=(field_name, value)
      set(field_name, value)
    end

    def set(field_name, value)
      field_name = field_name.to_s
      return @ext_doc.set_null(field_name) if value.nil?

      if @schema
        type = @schema.field_type(field_name)
        if type
          setter = DataTypes::SETTER_FOR[type]
          return @ext_doc.send(setter, field_name, value) if setter
        end
      end

      # Auto-detect type
      case value
      when String  then @ext_doc.set_string(field_name, value)
      when Integer then @ext_doc.set_int64(field_name, value)
      when Float   then @ext_doc.set_double(field_name, value)
      when TrueClass, FalseClass then @ext_doc.set_bool(field_name, value)
      when Array
        if value.empty? || value.first.is_a?(Float) || value.first.is_a?(Integer)
          @ext_doc.set_float_vector(field_name, value.map(&:to_f))
        elsif value.first.is_a?(String)
          @ext_doc.set_string_array(field_name, value)
        end
      end
    end

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

    def field_names
      @ext_doc.field_names
    end

    def empty?
      @ext_doc.empty?
    end

    def to_h
      h = { "pk" => pk, "score" => score }
      field_names.each { |f| h[f] = get(f) }
      h
    end

    def to_s
      @ext_doc.to_s
    end

    # Wrap a C++ Doc::Ptr into a Ruby Doc
    def self.from_ext(ext_doc, schema: nil)
      doc = allocate
      doc.instance_variable_set(:@ext_doc, ext_doc)
      doc.instance_variable_set(:@schema, schema)
      doc
    end
  end
end
