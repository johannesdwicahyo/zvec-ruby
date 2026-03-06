require_relative "test_helper"

class TestSchema < Minitest::Test
  def test_initialize_with_name
    schema = Zvec::Schema.new("test_schema")
    assert_equal "test_schema", schema.name
  end

  def test_initialize_with_block
    schema = Zvec::Schema.new("test") do
      string "title"
      int32 "count"
    end

    assert schema.has_field?("title")
    assert schema.has_field?("count")
  end

  def test_string_field
    schema = Zvec::Schema.new("test") { string "name" }
    assert schema.has_field?("name")
    assert_equal Zvec::DataTypes::STRING, schema.field_type("name")
  end

  def test_int32_field
    schema = Zvec::Schema.new("test") { int32 "count" }
    assert schema.has_field?("count")
    assert_equal Zvec::DataTypes::INT32, schema.field_type("count")
  end

  def test_int64_field
    schema = Zvec::Schema.new("test") { int64 "big_count" }
    assert schema.has_field?("big_count")
    assert_equal Zvec::DataTypes::INT64, schema.field_type("big_count")
  end

  def test_float_field
    schema = Zvec::Schema.new("test") { float "score" }
    assert schema.has_field?("score")
    assert_equal Zvec::DataTypes::FLOAT, schema.field_type("score")
  end

  def test_double_field
    schema = Zvec::Schema.new("test") { double "precise" }
    assert schema.has_field?("precise")
    assert_equal Zvec::DataTypes::DOUBLE, schema.field_type("precise")
  end

  def test_bool_field
    schema = Zvec::Schema.new("test") { bool "active" }
    assert schema.has_field?("active")
    assert_equal Zvec::DataTypes::BOOL, schema.field_type("active")
  end

  def test_vector_field
    schema = Zvec::Schema.new("test") do
      vector "embedding", dimension: 128
    end
    assert schema.has_field?("embedding")
    assert_equal Zvec::DataTypes::VECTOR_FP32, schema.field_type("embedding")
  end

  def test_vector_field_custom_type
    schema = Zvec::Schema.new("test") do
      vector "embedding", dimension: 128, type: Zvec::DataTypes::VECTOR_FP64
    end
    assert_equal Zvec::DataTypes::VECTOR_FP64, schema.field_type("embedding")
  end

  def test_field_with_explicit_type
    schema = Zvec::Schema.new("test")
    schema.field("tags", Zvec::DataTypes::ARRAY_STRING)
    assert schema.has_field?("tags")
    assert_equal Zvec::DataTypes::ARRAY_STRING, schema.field_type("tags")
  end

  def test_field_names
    schema = Zvec::Schema.new("test") do
      string "a"
      int32 "b"
      vector "c", dimension: 4
    end
    names = schema.field_names
    assert_includes names, "a"
    assert_includes names, "b"
    assert_includes names, "c"
    assert_equal 3, names.size
  end

  def test_has_field_returns_false_for_missing
    schema = Zvec::Schema.new("test")
    refute schema.has_field?("nonexistent")
  end

  def test_field_type_returns_nil_for_missing
    schema = Zvec::Schema.new("test")
    assert_nil schema.field_type("nonexistent")
  end

  def test_symbol_field_name
    schema = Zvec::Schema.new("test") { string "name" }
    # field_type converts to string internally
    assert_equal Zvec::DataTypes::STRING, schema.field_type(:name)
  end

  def test_field_returns_self_for_chaining
    schema = Zvec::Schema.new("test")
    result = schema.field("a", Zvec::DataTypes::STRING)
    assert_same schema, result
  end

  def test_to_s_returns_string
    schema = Zvec::Schema.new("test") { string "x" }
    assert_kind_of String, schema.to_s
  end

  def test_ext_schema_accessible
    schema = Zvec::Schema.new("test")
    assert_kind_of Zvec::Ext::CollectionSchema, schema.ext_schema
  end

  def test_multiple_fields_in_block
    schema = Zvec::Schema.new("docs") do
      string "title"
      string "body", nullable: true
      int32 "year"
      float "rating"
      bool "published"
      vector "embedding", dimension: 384
    end
    assert_equal 6, schema.field_names.size
  end
end
