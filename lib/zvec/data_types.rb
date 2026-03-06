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
  end
end
