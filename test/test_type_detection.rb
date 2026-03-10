require_relative "test_helper"

class TestTypeDetection < Minitest::Test
  # --- DataTypes.detect_type ---

  def test_detect_type_nil
    assert_nil Zvec::DataTypes.detect_type(nil)
  end

  def test_detect_type_string
    assert_equal Zvec::Ext::DataType::STRING, Zvec::DataTypes.detect_type("hello")
  end

  def test_detect_type_integer
    assert_equal Zvec::Ext::DataType::INT64, Zvec::DataTypes.detect_type(42)
  end

  def test_detect_type_float
    assert_equal Zvec::Ext::DataType::DOUBLE, Zvec::DataTypes.detect_type(3.14)
  end

  def test_detect_type_true
    assert_equal Zvec::Ext::DataType::BOOL, Zvec::DataTypes.detect_type(true)
  end

  def test_detect_type_false
    assert_equal Zvec::Ext::DataType::BOOL, Zvec::DataTypes.detect_type(false)
  end

  # Integer vs Float distinction: 1 should be INT64, 1.0 should be DOUBLE
  def test_detect_type_integer_one
    assert_equal Zvec::Ext::DataType::INT64, Zvec::DataTypes.detect_type(1)
  end

  def test_detect_type_float_one
    assert_equal Zvec::Ext::DataType::DOUBLE, Zvec::DataTypes.detect_type(1.0)
  end

  # --- Array type detection ---

  def test_detect_type_empty_array
    # Empty arrays default to VECTOR_FP32
    assert_equal Zvec::Ext::DataType::VECTOR_FP32, Zvec::DataTypes.detect_type([])
  end

  def test_detect_type_float_array
    assert_equal Zvec::Ext::DataType::VECTOR_FP32, Zvec::DataTypes.detect_type([1.0, 2.0])
  end

  def test_detect_type_integer_array
    # Integers in arrays are treated as vectors (float)
    assert_equal Zvec::Ext::DataType::VECTOR_FP32, Zvec::DataTypes.detect_type([1, 2, 3])
  end

  def test_detect_type_string_array
    assert_equal Zvec::Ext::DataType::ARRAY_STRING, Zvec::DataTypes.detect_type(["a", "b"])
  end

  def test_detect_type_bool_array
    assert_equal Zvec::Ext::DataType::ARRAY_BOOL, Zvec::DataTypes.detect_type([true, false])
  end

  def test_detect_type_nil_filled_array
    # Array of all nils defaults to VECTOR_FP32
    assert_equal Zvec::Ext::DataType::VECTOR_FP32, Zvec::DataTypes.detect_type([nil, nil, nil])
  end

  def test_detect_type_array_with_leading_nil
    # Skips nils to find first real element
    assert_equal Zvec::Ext::DataType::ARRAY_STRING, Zvec::DataTypes.detect_type([nil, "hello", "world"])
  end

  # --- DataTypes.coerce_value ---

  def test_coerce_nil_returns_nil
    assert_nil Zvec::DataTypes.coerce_value(nil, Zvec::Ext::DataType::STRING)
  end

  def test_coerce_to_string
    assert_equal "42", Zvec::DataTypes.coerce_value(42, Zvec::Ext::DataType::STRING)
  end

  def test_coerce_string_true_to_bool
    assert_equal true, Zvec::DataTypes.coerce_value("true", Zvec::Ext::DataType::BOOL)
  end

  def test_coerce_string_false_to_bool
    assert_equal false, Zvec::DataTypes.coerce_value("false", Zvec::Ext::DataType::BOOL)
  end

  def test_coerce_actual_bool_true
    assert_equal true, Zvec::DataTypes.coerce_value(true, Zvec::Ext::DataType::BOOL)
  end

  def test_coerce_actual_bool_false
    assert_equal false, Zvec::DataTypes.coerce_value(false, Zvec::Ext::DataType::BOOL)
  end

  def test_coerce_integer_to_bool_nonzero
    assert_equal true, Zvec::DataTypes.coerce_value(1, Zvec::Ext::DataType::BOOL)
  end

  def test_coerce_integer_to_bool_zero
    assert_equal false, Zvec::DataTypes.coerce_value(0, Zvec::Ext::DataType::BOOL)
  end

  def test_coerce_invalid_string_to_bool_raises
    assert_raises(ArgumentError) do
      Zvec::DataTypes.coerce_value("maybe", Zvec::Ext::DataType::BOOL)
    end
  end

  def test_coerce_float_to_integer
    assert_equal 3, Zvec::DataTypes.coerce_value(3.7, Zvec::Ext::DataType::INT64)
  end

  def test_coerce_string_to_integer
    assert_equal 42, Zvec::DataTypes.coerce_value("42", Zvec::Ext::DataType::INT64)
  end

  def test_coerce_bad_string_to_integer_raises
    assert_raises(ArgumentError) do
      Zvec::DataTypes.coerce_value("abc", Zvec::Ext::DataType::INT64)
    end
  end

  def test_coerce_integer_to_float
    assert_in_delta 42.0, Zvec::DataTypes.coerce_value(42, Zvec::Ext::DataType::DOUBLE), 0.001
  end

  def test_coerce_string_to_float
    assert_in_delta 3.14, Zvec::DataTypes.coerce_value("3.14", Zvec::Ext::DataType::DOUBLE), 0.001
  end

  def test_coerce_bad_string_to_float_raises
    assert_raises(ArgumentError) do
      Zvec::DataTypes.coerce_value("xyz", Zvec::Ext::DataType::DOUBLE)
    end
  end

  # --- Vector coercion ---

  def test_coerce_integer_array_to_vector
    result = Zvec::DataTypes.coerce_value([1, 2, 3], Zvec::Ext::DataType::VECTOR_FP32)
    assert_equal [1.0, 2.0, 3.0], result
  end

  def test_coerce_nil_in_vector_becomes_zero
    result = Zvec::DataTypes.coerce_value([1.0, nil, 3.0], Zvec::Ext::DataType::VECTOR_FP32)
    assert_equal [1.0, 0.0, 3.0], result
  end

  def test_coerce_non_numeric_in_vector_raises
    assert_raises(ArgumentError) do
      Zvec::DataTypes.coerce_value([1.0, "bad", 3.0], Zvec::Ext::DataType::VECTOR_FP32)
    end
  end

  def test_coerce_non_array_to_vector_raises
    assert_raises(ArgumentError) do
      Zvec::DataTypes.coerce_value("not array", Zvec::Ext::DataType::VECTOR_FP32)
    end
  end

  # --- String array coercion ---

  def test_coerce_string_array
    result = Zvec::DataTypes.coerce_value(["a", "b"], Zvec::Ext::DataType::ARRAY_STRING)
    assert_equal ["a", "b"], result
  end

  def test_coerce_nil_in_string_array_becomes_empty
    result = Zvec::DataTypes.coerce_value(["a", nil, "c"], Zvec::Ext::DataType::ARRAY_STRING)
    assert_equal ["a", "", "c"], result
  end

  def test_coerce_non_array_to_string_array_raises
    assert_raises(ArgumentError) do
      Zvec::DataTypes.coerce_value("not array", Zvec::Ext::DataType::ARRAY_STRING)
    end
  end

  # --- Coerce error messages include field name ---

  def test_coerce_error_message_includes_field_name
    err = assert_raises(ArgumentError) do
      Zvec::DataTypes.coerce_value("abc", Zvec::Ext::DataType::INT64, field_name: "count")
    end
    assert_includes err.message, "count"
  end

  # --- Doc auto-detection edge cases ---

  def test_doc_auto_detect_integer_vs_float
    doc = Zvec::Doc.new
    doc["int_val"] = 42
    doc["float_val"] = 42.0
    # int_val stored via set_int64, float_val via set_double
    assert_equal 42, doc["int_val"]
    assert_in_delta 42.0, doc["float_val"], 0.001
  end

  def test_doc_auto_detect_true_boolean
    doc = Zvec::Doc.new
    doc["flag"] = true
    assert_equal true, doc["flag"]
  end

  def test_doc_auto_detect_false_boolean
    doc = Zvec::Doc.new
    doc["flag"] = false
    assert_equal false, doc["flag"]
  end

  def test_doc_string_true_stays_string
    # Without schema, "true" is a String, not a Boolean
    doc = Zvec::Doc.new
    doc["val"] = "true"
    assert_equal "true", doc["val"]
  end

  def test_doc_string_false_stays_string
    doc = Zvec::Doc.new
    doc["val"] = "false"
    assert_equal "false", doc["val"]
  end

  def test_doc_nil_value_in_array_auto_detect
    doc = Zvec::Doc.new
    doc["vec"] = [1.0, nil, 3.0]
    result = doc["vec"]
    assert_kind_of Array, result
    assert_equal 3, result.size
    assert_in_delta 0.0, result[1], 0.001
  end

  def test_doc_empty_array_auto_detect
    doc = Zvec::Doc.new
    doc["vec"] = []
    # Should not crash
    result = doc["vec"]
    assert(result.nil? || result == [])
  end

  def test_doc_schema_coerces_string_bool
    schema = Zvec::Schema.new("test") { bool "active" }
    doc = Zvec::Doc.new(schema: schema)
    doc["active"] = "true"
    assert_equal true, doc["active"]
  end

  def test_doc_schema_coerces_int_to_float
    schema = Zvec::Schema.new("test") { double "score" }
    doc = Zvec::Doc.new(schema: schema)
    doc["score"] = 42
    assert_in_delta 42.0, doc["score"], 0.001
  end
end
