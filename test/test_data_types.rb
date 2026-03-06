require_relative "test_helper"

class TestDataTypes < Minitest::Test
  # --- Scalar data type constants ---

  def test_string_type_defined
    refute_nil Zvec::DataTypes::STRING
  end

  def test_bool_type_defined
    refute_nil Zvec::DataTypes::BOOL
  end

  def test_int32_type_defined
    refute_nil Zvec::DataTypes::INT32
  end

  def test_int64_type_defined
    refute_nil Zvec::DataTypes::INT64
  end

  def test_uint32_type_defined
    refute_nil Zvec::DataTypes::UINT32
  end

  def test_uint64_type_defined
    refute_nil Zvec::DataTypes::UINT64
  end

  def test_float_type_defined
    refute_nil Zvec::DataTypes::FLOAT
  end

  def test_double_type_defined
    refute_nil Zvec::DataTypes::DOUBLE
  end

  # --- Vector data type constants ---

  def test_vector_fp32_defined
    refute_nil Zvec::DataTypes::VECTOR_FP32
  end

  def test_vector_fp64_defined
    refute_nil Zvec::DataTypes::VECTOR_FP64
  end

  def test_vector_fp16_defined
    refute_nil Zvec::DataTypes::VECTOR_FP16
  end

  def test_vector_int8_defined
    refute_nil Zvec::DataTypes::VECTOR_INT8
  end

  # --- Sparse vector data type constants ---

  def test_sparse_vector_fp32_defined
    refute_nil Zvec::DataTypes::SPARSE_VECTOR_FP32
  end

  def test_sparse_vector_fp16_defined
    refute_nil Zvec::DataTypes::SPARSE_VECTOR_FP16
  end

  # --- Array data type constants ---

  def test_array_string_defined
    refute_nil Zvec::DataTypes::ARRAY_STRING
  end

  def test_array_int32_defined
    refute_nil Zvec::DataTypes::ARRAY_INT32
  end

  def test_array_float_defined
    refute_nil Zvec::DataTypes::ARRAY_FLOAT
  end

  def test_array_bool_defined
    refute_nil Zvec::DataTypes::ARRAY_BOOL
  end

  # --- Metric type constants ---

  def test_l2_metric_defined
    refute_nil Zvec::DataTypes::L2
  end

  def test_ip_metric_defined
    refute_nil Zvec::DataTypes::IP
  end

  def test_cosine_metric_defined
    refute_nil Zvec::DataTypes::COSINE
  end

  # --- Top-level module includes DataTypes ---

  def test_zvec_includes_cosine
    refute_nil Zvec::COSINE
  end

  def test_zvec_includes_vector_fp32
    refute_nil Zvec::VECTOR_FP32
  end

  def test_zvec_includes_string
    refute_nil Zvec::STRING
  end

  # --- Dispatch tables ---

  def test_setter_for_has_string
    assert_equal :set_string, Zvec::DataTypes::SETTER_FOR[Zvec::Ext::DataType::STRING]
  end

  def test_setter_for_has_bool
    assert_equal :set_bool, Zvec::DataTypes::SETTER_FOR[Zvec::Ext::DataType::BOOL]
  end

  def test_setter_for_has_int32
    assert_equal :set_int32, Zvec::DataTypes::SETTER_FOR[Zvec::Ext::DataType::INT32]
  end

  def test_setter_for_has_int64
    assert_equal :set_int64, Zvec::DataTypes::SETTER_FOR[Zvec::Ext::DataType::INT64]
  end

  def test_setter_for_has_float
    assert_equal :set_float, Zvec::DataTypes::SETTER_FOR[Zvec::Ext::DataType::FLOAT]
  end

  def test_setter_for_has_double
    assert_equal :set_double, Zvec::DataTypes::SETTER_FOR[Zvec::Ext::DataType::DOUBLE]
  end

  def test_setter_for_has_vector_fp32
    assert_equal :set_float_vector, Zvec::DataTypes::SETTER_FOR[Zvec::Ext::DataType::VECTOR_FP32]
  end

  def test_setter_for_has_vector_fp64
    assert_equal :set_double_vector, Zvec::DataTypes::SETTER_FOR[Zvec::Ext::DataType::VECTOR_FP64]
  end

  def test_setter_for_has_array_string
    assert_equal :set_string_array, Zvec::DataTypes::SETTER_FOR[Zvec::Ext::DataType::ARRAY_STRING]
  end

  def test_setter_for_is_frozen
    assert Zvec::DataTypes::SETTER_FOR.frozen?
  end

  def test_getter_for_has_string
    assert_equal :get_string, Zvec::DataTypes::GETTER_FOR[Zvec::Ext::DataType::STRING]
  end

  def test_getter_for_has_float_vector
    assert_equal :get_float_vector, Zvec::DataTypes::GETTER_FOR[Zvec::Ext::DataType::VECTOR_FP32]
  end

  def test_getter_for_is_frozen
    assert Zvec::DataTypes::GETTER_FOR.frozen?
  end
end
