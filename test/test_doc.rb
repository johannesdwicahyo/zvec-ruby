require_relative "test_helper"

class TestDoc < Minitest::Test
  def setup
    @schema = Zvec::Schema.new("test") do
      string "title"
      int32 "count"
      float "score"
      double "precise"
      bool "active"
      vector "embedding", dimension: 4
    end
  end

  # --- Initialization ---

  def test_initialize_default
    doc = Zvec::Doc.new
    assert_equal "", doc.pk
    assert_equal 0.0, doc.score
    assert doc.empty?
  end

  def test_initialize_with_pk
    doc = Zvec::Doc.new(pk: "abc")
    assert_equal "abc", doc.pk
  end

  def test_initialize_with_integer_pk
    doc = Zvec::Doc.new(pk: 42)
    assert_equal "42", doc.pk
  end

  def test_initialize_with_fields_and_schema
    doc = Zvec::Doc.new(pk: "d1", fields: { "title" => "Hello" }, schema: @schema)
    assert_equal "Hello", doc["title"]
  end

  # --- pk ---

  def test_pk_setter
    doc = Zvec::Doc.new
    doc.pk = "new_pk"
    assert_equal "new_pk", doc.pk
  end

  def test_pk_setter_converts_to_string
    doc = Zvec::Doc.new
    doc.pk = 123
    assert_equal "123", doc.pk
  end

  # --- String fields ---

  def test_set_and_get_string
    doc = Zvec::Doc.new(schema: @schema)
    doc["title"] = "Hello World"
    assert_equal "Hello World", doc["title"]
  end

  def test_set_string_without_schema_auto_detects
    doc = Zvec::Doc.new
    doc["name"] = "auto"
    assert_equal "auto", doc["name"]
  end

  # --- Integer fields ---

  def test_set_and_get_int32
    doc = Zvec::Doc.new(schema: @schema)
    doc["count"] = 42
    assert_equal 42, doc["count"]
  end

  def test_set_integer_without_schema_uses_int64
    doc = Zvec::Doc.new
    doc["num"] = 99
    assert_equal 99, doc["num"]
  end

  # --- Float fields ---

  def test_set_and_get_float
    doc = Zvec::Doc.new(schema: @schema)
    doc["score"] = 3.14
    val = doc["score"]
    assert_in_delta 3.14, val, 0.01
  end

  def test_set_and_get_double
    doc = Zvec::Doc.new(schema: @schema)
    doc["precise"] = 2.718281828
    val = doc["precise"]
    assert_in_delta 2.718281828, val, 0.0001
  end

  def test_set_float_without_schema_auto_detects
    doc = Zvec::Doc.new
    doc["val"] = 1.5
    assert_in_delta 1.5, doc["val"], 0.01
  end

  # --- Bool fields ---

  def test_set_and_get_bool_true
    doc = Zvec::Doc.new(schema: @schema)
    doc["active"] = true
    assert_equal true, doc["active"]
  end

  def test_set_and_get_bool_false
    doc = Zvec::Doc.new(schema: @schema)
    doc["active"] = false
    assert_equal false, doc["active"]
  end

  def test_set_bool_without_schema_auto_detects
    doc = Zvec::Doc.new
    doc["flag"] = true
    assert_equal true, doc["flag"]
  end

  # --- Vector fields ---

  def test_set_and_get_float_vector
    doc = Zvec::Doc.new(schema: @schema)
    vec = [1.0, 2.0, 3.0, 4.0]
    doc["embedding"] = vec
    result = doc["embedding"]
    assert_kind_of Array, result
    assert_equal 4, result.size
    assert_in_delta 1.0, result[0], 0.001
    assert_in_delta 4.0, result[3], 0.001
  end

  def test_set_array_of_integers_as_vector
    doc = Zvec::Doc.new
    doc["vec"] = [1, 2, 3]
    result = doc["vec"]
    assert_kind_of Array, result
    assert_in_delta 1.0, result[0], 0.01
  end

  # --- String array fields ---

  def test_set_and_get_string_array
    doc = Zvec::Doc.new
    doc["tags"] = ["ruby", "vector", "db"]
    result = doc["tags"]
    assert_kind_of Array, result
    assert_equal ["ruby", "vector", "db"], result
  end

  # --- Null handling ---

  def test_set_nil_value
    doc = Zvec::Doc.new
    doc["title"] = "Hello"
    doc["title"] = nil
    assert_nil doc["title"]
  end

  # --- Missing fields ---

  def test_get_missing_field_returns_nil
    doc = Zvec::Doc.new
    assert_nil doc["nonexistent"]
  end

  # --- field_names ---

  def test_field_names
    doc = Zvec::Doc.new(schema: @schema)
    doc["title"] = "Hello"
    doc["count"] = 1
    names = doc.field_names
    assert_includes names, "title"
    assert_includes names, "count"
  end

  # --- empty? ---

  def test_empty_initially
    doc = Zvec::Doc.new
    assert doc.empty?
  end

  def test_not_empty_after_set
    doc = Zvec::Doc.new
    doc["x"] = "y"
    refute doc.empty?
  end

  # --- to_h ---

  def test_to_h
    doc = Zvec::Doc.new(pk: "pk1")
    doc["title"] = "Hi"
    h = doc.to_h
    assert_kind_of Hash, h
    assert_equal "pk1", h["pk"]
    assert_equal 0.0, h["score"]
    assert_equal "Hi", h["title"]
  end

  def test_to_h_includes_all_fields
    doc = Zvec::Doc.new(pk: "x")
    doc["a"] = "one"
    doc["b"] = "two"
    h = doc.to_h
    assert_equal "one", h["a"]
    assert_equal "two", h["b"]
  end

  # --- to_s ---

  def test_to_s_returns_string
    doc = Zvec::Doc.new(pk: "test")
    assert_kind_of String, doc.to_s
  end

  # --- bracket accessor ---

  def test_bracket_set_and_get
    doc = Zvec::Doc.new
    doc["key"] = "value"
    assert_equal "value", doc["key"]
  end

  # --- from_ext ---

  def test_from_ext
    ext_doc = Zvec::Ext::Doc.new
    ext_doc.pk = "wrapped"
    doc = Zvec::Doc.from_ext(ext_doc, schema: @schema)
    assert_equal "wrapped", doc.pk
    assert_same ext_doc, doc.ext_doc
  end

  def test_from_ext_without_schema
    ext_doc = Zvec::Ext::Doc.new
    doc = Zvec::Doc.from_ext(ext_doc)
    assert_equal ext_doc, doc.ext_doc
  end

  # --- symbol keys ---

  def test_symbol_field_name_set
    doc = Zvec::Doc.new
    doc.set(:sym_field, "value")
    assert_equal "value", doc["sym_field"]
  end

  def test_symbol_field_name_get
    doc = Zvec::Doc.new
    doc["sym_field"] = "value"
    assert_equal "value", doc.get(:sym_field)
  end

  # --- empty array ---

  def test_set_empty_array_as_vector
    doc = Zvec::Doc.new
    doc["empty"] = []
    # Empty arrays treated as float vectors (empty)
    result = doc["empty"]
    # Depending on implementation, may be nil or empty array
    # Just verify it doesn't crash
    assert(result.nil? || result == [])
  end
end
