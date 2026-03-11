module Zvec
  # Data type constants, coercion utilities, and dispatch tables for mapping
  # between Ruby types and the underlying C++ zvec engine types.
  #
  # == Scalar Types
  #
  # * {BINARY} -- Raw binary data
  # * {STRING} -- UTF-8 string
  # * {BOOL} -- Boolean (true/false)
  # * {INT32} -- 32-bit signed integer
  # * {INT64} -- 64-bit signed integer
  # * {UINT32} -- 32-bit unsigned integer
  # * {UINT64} -- 64-bit unsigned integer
  # * {FLOAT} -- 32-bit IEEE 754 float
  # * {DOUBLE} -- 64-bit IEEE 754 double
  #
  # == Dense Vector Types
  #
  # Dense vectors store a fixed-length array of numeric values. Choose the
  # precision that balances accuracy vs. memory:
  #
  # * {VECTOR_FP32} -- 32-bit float vector (default, best accuracy)
  # * {VECTOR_FP64} -- 64-bit double vector (highest accuracy, 2x memory)
  # * {VECTOR_FP16} -- 16-bit half-precision vector (half the memory of FP32)
  # * {VECTOR_INT8} -- 8-bit integer vector (smallest, for quantized models)
  #
  # == Sparse Vector Types
  #
  # Sparse vectors store only non-zero elements, ideal for high-dimensional
  # data where most values are zero (e.g., BM25 or TF-IDF features):
  #
  # * {SPARSE_VECTOR_FP32} -- Sparse vector with 32-bit float values
  # * {SPARSE_VECTOR_FP16} -- Sparse vector with 16-bit float values
  #
  # == Binary Vectors
  #
  # Binary vectors use the {BINARY} type and store bit-packed data, useful for
  # binary hash codes or Hamming distance searches.
  #
  # == Array Types
  #
  # * {ARRAY_STRING} -- Array of strings (e.g., tags)
  # * {ARRAY_INT32} -- Array of 32-bit integers
  # * {ARRAY_INT64} -- Array of 64-bit integers
  # * {ARRAY_FLOAT} -- Array of 32-bit floats
  # * {ARRAY_DOUBLE} -- Array of 64-bit doubles
  # * {ARRAY_BOOL} -- Array of booleans
  #
  # == Quantization Types
  #
  # Quantization reduces memory usage and speeds up search at the cost of some
  # accuracy. Specify a quantization type when creating an index:
  #
  #   Ext::HnswIndexParams.new(metric, quantize_type: Ext::QuantizeType::INT8)
  #
  # Available quantization types (via +Ext::QuantizeType+):
  #
  # * +FP16+ -- Half-precision (16-bit) quantization. Good balance of speed
  #   and accuracy. Halves memory vs. FP32.
  # * +INT8+ -- 8-bit integer quantization. ~4x memory reduction vs. FP32.
  #   Slight accuracy loss.
  # * +INT4+ -- 4-bit integer quantization. ~8x memory reduction vs. FP32.
  #   Larger accuracy loss, best for large-scale approximate search.
  #
  # == Metric Types
  #
  # * {L2} -- Euclidean (L2) distance. Lower is more similar.
  # * {IP} -- Inner product. Higher is more similar.
  # * {COSINE} -- Cosine similarity. Higher is more similar. Vectors are
  #   normalized internally.
  #
  module DataTypes
    # Re-export C++ enum values as Ruby-friendly constants

    # @return [Symbol] Raw binary data type
    BINARY   = Ext::DataType::BINARY
    # @return [Symbol] UTF-8 string data type
    STRING   = Ext::DataType::STRING
    # @return [Symbol] Boolean data type
    BOOL     = Ext::DataType::BOOL
    # @return [Symbol] 32-bit signed integer data type
    INT32    = Ext::DataType::INT32
    # @return [Symbol] 64-bit signed integer data type
    INT64    = Ext::DataType::INT64
    # @return [Symbol] 32-bit unsigned integer data type
    UINT32   = Ext::DataType::UINT32
    # @return [Symbol] 64-bit unsigned integer data type
    UINT64   = Ext::DataType::UINT64
    # @return [Symbol] 32-bit float data type
    FLOAT    = Ext::DataType::FLOAT
    # @return [Symbol] 64-bit double data type
    DOUBLE   = Ext::DataType::DOUBLE

    # @return [Symbol] 32-bit float dense vector
    VECTOR_FP32 = Ext::DataType::VECTOR_FP32
    # @return [Symbol] 64-bit double dense vector
    VECTOR_FP64 = Ext::DataType::VECTOR_FP64
    # @return [Symbol] 16-bit half-precision dense vector
    VECTOR_FP16 = Ext::DataType::VECTOR_FP16
    # @return [Symbol] 8-bit integer dense vector (quantized)
    VECTOR_INT8 = Ext::DataType::VECTOR_INT8

    # @return [Symbol] 32-bit float sparse vector
    SPARSE_VECTOR_FP32 = Ext::DataType::SPARSE_VECTOR_FP32
    # @return [Symbol] 16-bit float sparse vector
    SPARSE_VECTOR_FP16 = Ext::DataType::SPARSE_VECTOR_FP16

    # @return [Symbol] Array of strings
    ARRAY_STRING = Ext::DataType::ARRAY_STRING
    # @return [Symbol] Array of 32-bit integers
    ARRAY_INT32  = Ext::DataType::ARRAY_INT32
    # @return [Symbol] Array of 64-bit integers
    ARRAY_INT64  = Ext::DataType::ARRAY_INT64
    # @return [Symbol] Array of 32-bit floats
    ARRAY_FLOAT  = Ext::DataType::ARRAY_FLOAT
    # @return [Symbol] Array of 64-bit doubles
    ARRAY_DOUBLE = Ext::DataType::ARRAY_DOUBLE
    # @return [Symbol] Array of booleans
    ARRAY_BOOL   = Ext::DataType::ARRAY_BOOL

    # Metric types

    # @return [Symbol] Euclidean (L2) distance metric
    L2     = Ext::MetricType::L2
    # @return [Symbol] Inner product metric
    IP     = Ext::MetricType::IP
    # @return [Symbol] Cosine similarity metric
    COSINE = Ext::MetricType::COSINE

    # Vector data types for dimension validation
    # @return [Array<Symbol>] All dense vector data type constants
    VECTOR_TYPES = [
      Ext::DataType::VECTOR_FP32,
      Ext::DataType::VECTOR_FP64,
      Ext::DataType::VECTOR_FP16,
      Ext::DataType::VECTOR_INT8,
    ].freeze

    # Setter dispatch table: DataType -> Doc setter method name
    # @return [Hash{Symbol => Symbol}]
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

    # Getter dispatch table: DataType -> Doc getter method name
    # @return [Hash{Symbol => Symbol}]
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
    #
    # Handles edge cases: Integer vs Float, String booleans, nil, empty arrays.
    #
    # @param value [Object] the Ruby value to inspect
    # @return [Symbol, nil] the zvec data type constant, or nil for nil input
    #
    # @example
    #   DataTypes.detect_type("hello")  #=> Ext::DataType::STRING
    #   DataTypes.detect_type(42)       #=> Ext::DataType::INT64
    #   DataTypes.detect_type([1.0])    #=> Ext::DataType::VECTOR_FP32
    #   DataTypes.detect_type(nil)      #=> nil
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
    #
    # @param value [Object] the value to coerce
    # @param target_type [Symbol] the target zvec data type constant
    # @param field_name [String, nil] optional field name for error messages
    # @return [Object] the coerced value
    # @raise [ArgumentError] if the value cannot be coerced to the target type
    #
    # @example
    #   DataTypes.coerce_value(42, Ext::DataType::STRING)  #=> "42"
    #   DataTypes.coerce_value("3.14", Ext::DataType::DOUBLE)  #=> 3.14
    #   DataTypes.coerce_value([1, 2], Ext::DataType::VECTOR_FP32)  #=> [1.0, 2.0]
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

      # @param arr [Array] the array to detect the element type for
      # @return [Symbol] the detected zvec data type
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
