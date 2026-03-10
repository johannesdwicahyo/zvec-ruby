module Zvec
  module DataTypes
    # Re-export C++ enum values as Ruby-friendly constants
    BINARY   = Ext::DataType::BINARY
    STRING   = Ext::DataType::STRING
    BOOL     = Ext::DataType::BOOL
    INT32    = Ext::DataType::INT32
    INT64    = Ext::DataType::INT64
    UINT32   = Ext::DataType::UINT32
    UINT64   = Ext::DataType::UINT64
    FLOAT    = Ext::DataType::FLOAT
    DOUBLE   = Ext::DataType::DOUBLE

    VECTOR_FP32 = Ext::DataType::VECTOR_FP32
    VECTOR_FP64 = Ext::DataType::VECTOR_FP64
    VECTOR_FP16 = Ext::DataType::VECTOR_FP16
    VECTOR_INT8 = Ext::DataType::VECTOR_INT8

    SPARSE_VECTOR_FP32 = Ext::DataType::SPARSE_VECTOR_FP32
    SPARSE_VECTOR_FP16 = Ext::DataType::SPARSE_VECTOR_FP16

    ARRAY_STRING = Ext::DataType::ARRAY_STRING
    ARRAY_INT32  = Ext::DataType::ARRAY_INT32
    ARRAY_INT64  = Ext::DataType::ARRAY_INT64
    ARRAY_FLOAT  = Ext::DataType::ARRAY_FLOAT
    ARRAY_DOUBLE = Ext::DataType::ARRAY_DOUBLE
    ARRAY_BOOL   = Ext::DataType::ARRAY_BOOL

    # Metric types
    L2     = Ext::MetricType::L2
    IP     = Ext::MetricType::IP
    COSINE = Ext::MetricType::COSINE

    # Vector data types for dimension validation
    VECTOR_TYPES = [
      Ext::DataType::VECTOR_FP32,
      Ext::DataType::VECTOR_FP64,
      Ext::DataType::VECTOR_FP16,
      Ext::DataType::VECTOR_INT8,
    ].freeze

    # Setter dispatch table: DataType -> Doc setter method name
    SETTER_FOR = {
      Ext::DataType::STRING => :set_string,
      Ext::DataType::BOOL   => :set_bool,
      Ext::DataType::INT32  => :set_int32,
      Ext::DataType::INT64  => :set_int64,
      Ext::DataType::UINT32 => :set_uint32,
      Ext::DataType::UINT64 => :set_uint64,
      Ext::DataType::FLOAT  => :set_float,
      Ext::DataType::DOUBLE => :set_double,
      Ext::DataType::VECTOR_FP32 => :set_float_vector,
      Ext::DataType::VECTOR_FP64 => :set_double_vector,
      Ext::DataType::ARRAY_STRING => :set_string_array,
    }.freeze

    GETTER_FOR = {
      Ext::DataType::STRING => :get_string,
      Ext::DataType::BOOL   => :get_bool,
      Ext::DataType::INT32  => :get_int32,
      Ext::DataType::INT64  => :get_int64,
      Ext::DataType::UINT32 => :get_int32,
      Ext::DataType::UINT64 => :get_int64,
      Ext::DataType::FLOAT  => :get_float,
      Ext::DataType::DOUBLE => :get_double,
      Ext::DataType::VECTOR_FP32 => :get_float_vector,
      Ext::DataType::VECTOR_FP64 => :get_double_vector,
      Ext::DataType::ARRAY_STRING => :get_string_array,
    }.freeze

    # Detect the zvec data type for a Ruby value.
    # Handles edge cases: Integer vs Float, String booleans, nil, empty arrays.
    def self.detect_type(value)
      case value
      when NilClass              then nil
      when String                then Ext::DataType::STRING
      when Integer               then Ext::DataType::INT64
      when Float                 then Ext::DataType::DOUBLE
      when TrueClass, FalseClass then Ext::DataType::BOOL
      when Array                 then detect_array_type(value)
      end
    end

    # Coerce a Ruby value into a form suitable for the given zvec data type.
    # Returns the coerced value, or raises ArgumentError on impossible coercion.
    def self.coerce_value(value, target_type, field_name: nil)
      return value if value.nil?

      ctx = field_name ? " for field '#{field_name}'" : ""

      case target_type
      when Ext::DataType::STRING
        value.to_s
      when Ext::DataType::BOOL
        coerce_bool(value, ctx)
      when Ext::DataType::INT32, Ext::DataType::INT64,
           Ext::DataType::UINT32, Ext::DataType::UINT64
        coerce_integer(value, ctx)
      when Ext::DataType::FLOAT, Ext::DataType::DOUBLE
        coerce_float(value, ctx)
      when Ext::DataType::VECTOR_FP32, Ext::DataType::VECTOR_FP64
        coerce_float_vector(value, ctx)
      when Ext::DataType::ARRAY_STRING
        coerce_string_array(value, ctx)
      else
        value
      end
    end

    class << self
      private

      def detect_array_type(arr)
        return Ext::DataType::VECTOR_FP32 if arr.empty?

        first_non_nil = arr.find { |v| !v.nil? }
        return Ext::DataType::VECTOR_FP32 if first_non_nil.nil?

        case first_non_nil
        when Float   then Ext::DataType::VECTOR_FP32
        when Integer then Ext::DataType::VECTOR_FP32
        when String  then Ext::DataType::ARRAY_STRING
        when TrueClass, FalseClass then Ext::DataType::ARRAY_BOOL
        else Ext::DataType::VECTOR_FP32
        end
      end

      def coerce_bool(value, ctx)
        case value
        when TrueClass, FalseClass then value
        when "true", "1"           then true
        when "false", "0"          then false
        when Integer               then !value.zero?
        else
          raise ArgumentError,
            "Cannot coerce #{value.class} (#{value.inspect}) to Bool#{ctx}"
        end
      end

      def coerce_integer(value, ctx)
        case value
        when Integer then value
        when Float   then value.to_i
        when String
          Integer(value)
        else
          raise ArgumentError,
            "Cannot coerce #{value.class} (#{value.inspect}) to Integer#{ctx}"
        end
      rescue ::ArgumentError
        raise ArgumentError,
          "Cannot coerce #{value.class} (#{value.inspect}) to Integer#{ctx}"
      end

      def coerce_float(value, ctx)
        case value
        when Numeric then value.to_f
        when String
          Float(value)
        else
          raise ArgumentError,
            "Cannot coerce #{value.class} (#{value.inspect}) to Float#{ctx}"
        end
      rescue ::ArgumentError
        raise ArgumentError,
          "Cannot coerce #{value.class} (#{value.inspect}) to Float#{ctx}"
      end

      def coerce_float_vector(value, ctx)
        unless value.is_a?(Array)
          raise ArgumentError, "Expected Array for vector#{ctx}, got #{value.class}"
        end
        value.map do |v|
          next 0.0 if v.nil?
          unless v.is_a?(Numeric)
            raise ArgumentError,
              "Vector#{ctx} contains non-numeric element: #{v.inspect}"
          end
          v.to_f
        end
      end

      def coerce_string_array(value, ctx)
        unless value.is_a?(Array)
          raise ArgumentError, "Expected Array for string array#{ctx}, got #{value.class}"
        end
        value.map { |v| v.nil? ? "" : v.to_s }
      end
    end
  end
end
